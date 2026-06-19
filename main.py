from fastapi import FastAPI, HTTPException, UploadFile, File, Depends, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from pydantic import BaseModel, EmailStr

import aiomysql
import uvicorn

import os
import math
import uuid
import shutil
import datetime
import jwt
import ssl
import time
import base64
import hashlib
import binascii

from typing import Optional, List
from contextlib import asynccontextmanager

from passlib.context import CryptContext

# =====================================================
# CONFIG
# =====================================================

SECRET_KEY = os.getenv("SECRET_KEY", "sartaroshxona-super-secret-key-2025!@#")
ADMIN_KEY = os.getenv("ADMIN_KEY", "sartaroshxona-admin-2025")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

SERVER_BASE_URL = os.getenv("SERVER_BASE_URL", "http://192.168.10.4:8000")

# ─── TO'LOV TIZIMLARI (Payme / Click) ────────────────────────────────────────
# DIQQAT: bu qiymatlar test/placeholder. Haqiqiy kalitlarni .env orqali bering.
# Payme
PAYME_MERCHANT_ID = os.getenv("PAYME_MERCHANT_ID", "TEST_PAYME_MERCHANT_ID")
PAYME_KEY = os.getenv("PAYME_KEY", "TEST_PAYME_KEY")
PAYME_CHECKOUT_URL = os.getenv("PAYME_CHECKOUT_URL", "https://checkout.paycom.uz")
# Click
CLICK_SERVICE_ID = os.getenv("CLICK_SERVICE_ID", "TEST_CLICK_SERVICE_ID")
CLICK_MERCHANT_ID = os.getenv("CLICK_MERCHANT_ID", "TEST_CLICK_MERCHANT_ID")
CLICK_MERCHANT_USER_ID = os.getenv("CLICK_MERCHANT_USER_ID", "TEST_CLICK_MERCHANT_USER_ID")
CLICK_SECRET_KEY = os.getenv("CLICK_SECRET_KEY", "TEST_CLICK_SECRET_KEY")
CLICK_CHECKOUT_URL = os.getenv("CLICK_CHECKOUT_URL", "https://my.click.uz/services/pay")
# To'lovdan keyin qaytadigan manzil (web sahifa yoki deep link)
PAYMENT_RETURN_URL = os.getenv("PAYMENT_RETURN_URL", f"{SERVER_BASE_URL}/payment/return")

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "0000"),
    "db": os.getenv("DB_NAME", "sartaroshxona_db"),
    "autocommit": False,
    "minsize": 2,
    "maxsize": 10,
}

if os.getenv("DB_HOST") and "aiven" in os.getenv("DB_HOST", ""):
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE
    DB_CONFIG["ssl"] = ssl_ctx

# =====================================================
# APP LIFESPAN (Connection Pool)
# =====================================================

pool: aiomysql.Pool = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    pool_config = {
        "host": DB_CONFIG["host"],
        "port": DB_CONFIG["port"],
        "user": DB_CONFIG["user"],
        "password": DB_CONFIG["password"],
        "db": DB_CONFIG["db"],
        "autocommit": DB_CONFIG["autocommit"],
        "minsize": DB_CONFIG["minsize"],
        "maxsize": DB_CONFIG["maxsize"],
    }
    if "ssl" in DB_CONFIG:
        pool_config["ssl"] = DB_CONFIG["ssl"]
    pool = await aiomysql.create_pool(**pool_config)
    print("Database connection pool yaratildi")
    # Chat (messages) jadvalini avtomatik yaratish (idempotent)
    try:
        _c = await pool.acquire()
        try:
            async with _c.cursor() as _cur:
                await _cur.execute(
                    "CREATE TABLE IF NOT EXISTS messages ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "sender_id INT NOT NULL, "
                    "receiver_id INT NOT NULL, "
                    "body TEXT NOT NULL, "
                    "is_read BOOLEAN DEFAULT FALSE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "INDEX idx_pair (sender_id, receiver_id), "
                    "FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE"
                    ")"
                )
                # To'lov tizimlari tranzaksiyalari (Payme/Click)
                await _cur.execute(
                    "CREATE TABLE IF NOT EXISTS gateway_transactions ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "gateway VARCHAR(10) NOT NULL, "
                    "order_id INT NOT NULL, "
                    "amount BIGINT NOT NULL, "
                    "state INT NOT NULL DEFAULT 0, "
                    "provider_trans_id VARCHAR(64), "
                    "create_time BIGINT DEFAULT 0, "
                    "perform_time BIGINT DEFAULT 0, "
                    "cancel_time BIGINT DEFAULT 0, "
                    "reason INT DEFAULT NULL, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "INDEX idx_order (order_id), "
                    "INDEX idx_provider (gateway, provider_trans_id)"
                    ")"
                )
                await _c.commit()
            print("messages va gateway_transactions jadvallari tayyor")
        finally:
            pool.release(_c)
    except Exception as e:
        print(f"messages jadvalini yaratishda ogohlantirish: {e}")
    yield
    pool.close()
    await pool.wait_closed()

# =====================================================
# APP
# =====================================================

app = FastAPI(
    title="Sartaroshxona API",
    version="3.0.0",
    lifespan=lifespan,
)

# =====================================================
# CORS
# =====================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================================================
# UPLOADS
# =====================================================

os.makedirs("uploads", exist_ok=True)
os.makedirs("uploads/avatars", exist_ok=True)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# =====================================================
# PASSWORD HASH
# =====================================================

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

# =====================================================
# JWT AUTH
# =====================================================

security = HTTPBearer(auto_error=False)

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + datetime.timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token muddati tugagan")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Yaroqsiz token")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials is None:
        return None
    return verify_token(credentials.credentials)

async def require_auth(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials is None:
        raise HTTPException(status_code=401, detail="Token talab qilinadi")
    return verify_token(credentials.credentials)

async def require_owner(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials is None:
        raise HTTPException(status_code=401, detail="Token talab qilinadi")
    payload = verify_token(credentials.credentials)
    if payload.get("role") != "owner":
        raise HTTPException(status_code=403, detail="Bu amal faqat sartaroshxona egalari uchun")
    return payload

# =====================================================
# DATABASE HELPER
# =====================================================

async def get_conn():
    return await pool.acquire()

async def release_conn(conn):
    pool.release(conn)

# =====================================================
# HELPERS
# =====================================================

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str):
    return pwd_context.verify(plain, hashed)

def haversine(lat1, lon1, lat2, lon2):
    if None in (lat1, lon1, lat2, lon2):
        return 0.0
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def timedelta_to_str(td):
    if td is None:
        return None
    if isinstance(td, datetime.timedelta):
        total = int(td.total_seconds())
        h = total // 3600
        m = (total % 3600) // 60
        return f"{h:02d}:{m:02d}"
    return str(td)

# =====================================================
# MODELS
# =====================================================

class UserRegister(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    role: str
    phone: str
    experience: Optional[str] = None
    specialization: Optional[str] = None
    bio: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    # Owner (sartaroshxona egasi) uchun
    salon_name: Optional[str] = None
    salon_address: Optional[str] = None
    also_barber: bool = False

class UserLogin(BaseModel):
    email: str
    password: str

class UpdateProfile(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    bio: Optional[str] = None
    specialization: Optional[str] = None
    experience: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None

class AppointmentCreate(BaseModel):
    customer_id: int
    barber_id: int
    service_id: Optional[int] = None
    appointment_time: str
    service_name: str
    price: float
    notes: Optional[str] = ""

class ReviewCreate(BaseModel):
    appointment_id: int
    customer_id: int
    barber_id: int
    rating: int
    comment: Optional[str] = ""

class PaymentCreate(BaseModel):
    appointment_id: int
    amount: float
    method: str

class BlockedSlot(BaseModel):
    barber_id: int
    blocked_date: str
    start_time: str
    end_time: str
    reason: Optional[str] = ""

# ─── CRM: SALON MODELLARI ───────────────────────────────

class SalonCreate(BaseModel):
    name: str
    description: Optional[str] = None
    address: Optional[str] = None
    district: str = "Toshkent"
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None

class SalonUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    district: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None

class StaffInvite(BaseModel):
    barber_id: Optional[int] = None
    barber_email: Optional[EmailStr] = None
    message: Optional[str] = ""

class JoinRequest(BaseModel):
    salon_id: int
    message: Optional[str] = ""

class InvitationResponse(BaseModel):
    accept: bool

class ChangePassword(BaseModel):
    user_id: int
    old_password: str
    new_password: str

class MessageCreate(BaseModel):
    sender_id: int
    receiver_id: int
    body: str

class CheckoutRequest(BaseModel):
    appointment_id: int
    gateway: str  # 'payme' yoki 'click'

# =====================================================
# AUTH ENDPOINTS
# =====================================================

@app.post("/register")
async def register(user: UserRegister):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id FROM users WHERE email=%s", (user.email,))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Email already exists")
            hashed_password = hash_password(user.password)
            await cur.execute("INSERT INTO users (full_name, email, password_hash, role, phone) VALUES (%s,%s,%s,%s,%s)", (user.full_name, user.email, hashed_password, user.role, user.phone))
            user_id = cur.lastrowid
            barber_id = None
            salon_id = None
            if user.role == "barber":
                await cur.execute("INSERT INTO barbers (user_id, name, experience, phone, specialization, bio, lat, lng, rating, total_reviews, district) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,5.0,0,'Toshkent')", (user_id, user.full_name, user.experience or "", user.phone, user.specialization or "", user.bio or "", user.lat, user.lng))
                barber_id = cur.lastrowid
                for day in range(1, 7):
                    await cur.execute("INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,1)", (barber_id, day))
            elif user.role == "owner":
                salon_name = user.salon_name or f"{user.full_name} sartaroshxonasi"
                await cur.execute("INSERT INTO salons (owner_id, name, address, phone, lat, lng, description) VALUES (%s,%s,%s,%s,%s,%s,%s)", (user_id, salon_name, user.salon_address or "", user.phone, user.lat, user.lng, user.bio or ""))
                salon_id = cur.lastrowid
                if user.also_barber:
                    await cur.execute("INSERT INTO barbers (user_id, salon_id, name, experience, phone, specialization, bio, lat, lng, rating, total_reviews, district, verification_status) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,5.0,0,'Toshkent','approved')", (user_id, salon_id, user.full_name, user.experience or "", user.phone, user.specialization or "", user.bio or "", user.lat, user.lng))
                    barber_id = cur.lastrowid
                    for day in range(1, 7):
                        await cur.execute("INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,1)", (barber_id, day))
            await conn.commit()
            token = create_access_token({"user_id": user_id, "role": user.role, "email": user.email})
            verification = None
            if user.role == "barber":
                verification = "pending"
            elif user.role == "owner" and user.also_barber:
                verification = "approved"
            return {"status": "success", "user_id": user_id, "barber_id": barber_id, "salon_id": salon_id, "verification_status": verification, "token": token}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)

@app.post("/login")
async def login(user: UserLogin):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT u.id, u.full_name, u.email, u.password_hash, u.role, u.phone, u.loyalty_points, b.id as barber_id, b.salon_id as barber_salon_id, b.is_online, b.rating, b.specialization, b.bio, b.avatar_url, b.working_hours_start, b.working_hours_end, b.verification_status, s.id as owned_salon_id, s.name as salon_name FROM users u LEFT JOIN barbers b ON u.id = b.user_id LEFT JOIN salons s ON u.id = s.owner_id WHERE u.email=%s OR u.phone=%s", (user.email, user.email))
            db_user = await cur.fetchone()
            if not db_user:
                raise HTTPException(status_code=401, detail="Email yoki parol noto'g'ri")
            if not pwd_context.verify(user.password, db_user["password_hash"]):
                raise HTTPException(status_code=401, detail="Email yoki parol noto'g'ri")
            db_user.pop("password_hash", None)
            token = create_access_token({"user_id": db_user["id"], "role": db_user["role"], "email": db_user["email"]})
            if db_user.get("working_hours_start"):
                db_user["working_hours_start"] = timedelta_to_str(db_user["working_hours_start"])
            if db_user.get("working_hours_end"):
                db_user["working_hours_end"] = timedelta_to_str(db_user["working_hours_end"])
            return {"status": "success", "token": token, "user": db_user}
    finally:
        await release_conn(conn)

@app.post("/upload_avatar/{barber_id}")
async def upload_barber_avatar(barber_id: int, file: UploadFile = File(...)):
    try:
        original_ext = os.path.splitext(file.filename)[-1].lower() if file.filename else '.jpg'
        if original_ext not in ['.jpg', '.jpeg', '.png', '.webp']:
            original_ext = '.jpg'
        filename = f"barber_{barber_id}_{uuid.uuid4().hex[:8]}{original_ext}"
        filepath = f"uploads/avatars/{filename}"
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        avatar_url = f"{SERVER_BASE_URL}/uploads/avatars/{filename}"
        conn = await get_conn()
        try:
            async with conn.cursor() as cur:
                await cur.execute("UPDATE barbers SET avatar_url=%s WHERE id=%s", (avatar_url, barber_id))
                await conn.commit()
        finally:
            await release_conn(conn)
        return {"status": "success", "avatar_url": avatar_url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/nearby_barbers")
async def get_nearby_barbers(user_lat: float, user_lng: float, radius_km: float = 2.0):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, name, district, rating, total_reviews, lat, lng, experience, specialization, phone, is_online, avatar_url, bio, working_hours_start, working_hours_end FROM barbers WHERE lat IS NOT NULL AND lng IS NOT NULL AND verification_status='approved'")
            barbers = await cur.fetchall()
            result = []
            for b in barbers:
                dist = haversine(user_lat, user_lng, b['lat'], b['lng'])
                if dist <= radius_km:
                    d = dict(b)
                    d['distance'] = round(dist, 2)
                    d['working_hours_start'] = timedelta_to_str(d.get('working_hours_start'))
                    d['working_hours_end'] = timedelta_to_str(d.get('working_hours_end'))
                    result.append(d)
            result.sort(key=lambda x: (not x['is_online'], x['distance']))
            return result
    finally:
        await release_conn(conn)

@app.get("/all_barbers")
async def get_all_barbers(user_lat: float = 41.3111, user_lng: float = 69.2797):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, name, district, rating, total_reviews, lat, lng, experience, specialization, phone, is_online, avatar_url, bio FROM barbers WHERE lat IS NOT NULL AND lng IS NOT NULL AND verification_status='approved'")
            barbers = await cur.fetchall()
            result = []
            for b in barbers:
                d = dict(b)
                d['distance'] = round(haversine(user_lat, user_lng, b['lat'], b['lng']), 2)
                result.append(d)
            return result
    finally:
        await release_conn(conn)

@app.get("/search_barbers")
async def search_barbers(query: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            like = f"%{query}%"
            await cur.execute("SELECT id, name, district, rating, total_reviews, lat, lng, experience, specialization, phone, is_online, avatar_url, bio FROM barbers WHERE verification_status='approved' AND (name LIKE %s OR district LIKE %s OR specialization LIKE %s)", (like, like, like))
            result = await cur.fetchall()
            return [dict(b) for b in result]
    finally:
        await release_conn(conn)

@app.get("/barber/{barber_id}")
async def get_barber_detail(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT b.*, u.email FROM barbers b JOIN users u ON b.user_id = u.id WHERE b.id=%s", (barber_id,))
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Topilmadi")
            await cur.execute("SELECT day_of_week, is_working FROM barber_working_days WHERE barber_id=%s ORDER BY day_of_week", (barber_id,))
            working_days = await cur.fetchall()
            await cur.execute("SELECT * FROM barber_services WHERE barber_id=%s AND is_active=1", (barber_id,))
            services = await cur.fetchall()
            await cur.execute("SELECT r.*, u.full_name as customer_name FROM reviews r JOIN users u ON r.customer_id=u.id WHERE r.barber_id=%s ORDER BY r.created_at DESC LIMIT 10", (barber_id,))
            reviews = await cur.fetchall()
            result = dict(barber)
            result['working_hours_start'] = timedelta_to_str(result.get('working_hours_start'))
            result['working_hours_end'] = timedelta_to_str(result.get('working_hours_end'))
            result['working_days'] = [dict(d) for d in working_days]
            result['services'] = [dict(s) for s in services]
            revs = []
            for r in reviews:
                rv = dict(r)
                if rv.get('created_at') and hasattr(rv['created_at'], 'isoformat'):
                    rv['created_at'] = rv['created_at'].isoformat()
                revs.append(rv)
            result['reviews'] = revs
            return result
    finally:
        await release_conn(conn)

@app.put("/update_profile/{barber_id}")
async def update_barber_profile(barber_id: int, data: UpdateProfile):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            fields, values = [], []
            if data.full_name: fields.append("name=%s"); values.append(data.full_name)
            if data.phone: fields.append("phone=%s"); values.append(data.phone)
            if data.bio is not None: fields.append("bio=%s"); values.append(data.bio)
            if data.specialization: fields.append("specialization=%s"); values.append(data.specialization)
            if data.experience: fields.append("experience=%s"); values.append(data.experience)
            if data.working_hours_start: fields.append("working_hours_start=%s"); values.append(data.working_hours_start)
            if data.working_hours_end: fields.append("working_hours_end=%s"); values.append(data.working_hours_end)
            if fields:
                values.append(barber_id)
                await cur.execute(f"UPDATE barbers SET {','.join(fields)} WHERE id=%s", values)
                await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

@app.put("/update_online_status/{barber_id}")
async def update_online(barber_id: int, is_online: bool):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE barbers SET is_online=%s WHERE id=%s", (is_online, barber_id))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)

@app.put("/update_working_days/{barber_id}")
async def update_working_days(barber_id: int, days: List[int]):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("DELETE FROM barber_working_days WHERE barber_id=%s", (barber_id,))
            for day in range(7):
                await cur.execute("INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,%s)", (barber_id, day, day in days))
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

@app.get("/available_slots/{barber_id}")
async def get_available_slots(barber_id: int, date: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT working_hours_start, working_hours_end, slot_duration_minutes FROM barbers WHERE id=%s", (barber_id,))
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Barber topilmadi")
            target_date = datetime.date.fromisoformat(date)
            day_of_week = target_date.isoweekday() % 7
            await cur.execute("SELECT is_working FROM barber_working_days WHERE barber_id=%s AND day_of_week=%s", (barber_id, day_of_week))
            wd = await cur.fetchone()
            if wd and not wd['is_working']:
                return {"date": date, "slots": [], "message": "Dam olish kuni"}
            await cur.execute("SELECT appointment_time, end_time FROM appointments WHERE barber_id=%s AND DATE(appointment_time)=%s AND status NOT IN ('cancelled')", (barber_id, date))
            booked = await cur.fetchall()
            await cur.execute("SELECT start_time, end_time FROM barber_blocked_slots WHERE barber_id=%s AND blocked_date=%s", (barber_id, date))
            blocked = await cur.fetchall()
            def td_to_minutes(td):
                if isinstance(td, datetime.timedelta): return int(td.total_seconds()) // 60
                if isinstance(td, (datetime.datetime, datetime.time)): return td.hour * 60 + td.minute
                if isinstance(td, str) and ':' in td: h, m = map(int, td.split(':')[:2]); return h * 60 + m
                return 0
            start_min = td_to_minutes(barber['working_hours_start'])
            end_min = td_to_minutes(barber['working_hours_end'])
            slot_dur = barber['slot_duration_minutes'] or 30
            booked_ranges = []
            for b in booked:
                s_td = b['appointment_time']; e_td = b['end_time']
                if hasattr(s_td, 'hour'): s = s_td.hour * 60 + s_td.minute
                elif hasattr(s_td, 'strftime'): t = s_td.strftime('%H:%M'); h, m = map(int, t.split(':')); s = h * 60 + m
                else: s = td_to_minutes(s_td)
                if e_td and hasattr(e_td, 'hour'): e = e_td.hour * 60 + e_td.minute
                elif e_td and hasattr(e_td, 'strftime'): t = e_td.strftime('%H:%M'); h, m = map(int, t.split(':')); e = h * 60 + m
                else: e = s + slot_dur
                booked_ranges.append((s, e))
            for bl in blocked:
                s = td_to_minutes(bl['start_time']); e = td_to_minutes(bl['end_time'])
                booked_ranges.append((s, e))
            now = datetime.datetime.now()
            current_min = now.hour * 60 + now.minute if target_date == now.date() else 0
            slots = []
            t = start_min
            while t + slot_dur <= end_min:
                if t > current_min:
                    is_free = all(not (t < be and t + slot_dur > bs) for bs, be in booked_ranges)
                    h, m = t // 60, t % 60
                    slots.append({"time": f"{h:02d}:{m:02d}", "is_available": is_free})
                t += slot_dur
            return {"date": date, "slots": slots}
    finally:
        await release_conn(conn)

@app.get("/get_services/{barber_id}")
async def get_services(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM barber_services WHERE barber_id=%s AND is_active=1 ORDER BY id", (barber_id,))
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)

@app.post("/add_service")
async def add_service(barber_id: int, name: str, price: float, duration: int = 30, description: str = ""):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("INSERT INTO barber_services (barber_id, service_name, price, duration_minutes, description) VALUES (%s,%s,%s,%s,%s)", (barber_id, name, price, duration, description))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)

@app.delete("/delete_service/{service_id}")
async def delete_service(service_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE barber_services SET is_active=0 WHERE id=%s", (service_id,))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)

@app.post("/book_appointment")
async def book_appointment(appt: AppointmentCreate):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id FROM barbers WHERE id=%s", (appt.barber_id,))
            if not await cur.fetchone():
                raise HTTPException(status_code=404, detail="Sartarosh topilmadi")
            duration = 30
            if appt.service_id:
                await cur.execute("SELECT duration_minutes, price FROM barber_services WHERE id=%s", (appt.service_id,))
                svc = await cur.fetchone()
                if svc: duration = svc['duration_minutes']
            apt_dt = datetime.datetime.fromisoformat(appt.appointment_time)
            end_dt = apt_dt + datetime.timedelta(minutes=duration)
            await cur.execute("SELECT id FROM appointments WHERE barber_id=%s AND status NOT IN ('cancelled') AND appointment_time < %s AND end_time > %s", (appt.barber_id, end_dt.strftime('%Y-%m-%d %H:%M:%S'), apt_dt.strftime('%Y-%m-%d %H:%M:%S')))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Bu vaqt band! Boshqa vaqt tanlang.")
            await cur.execute("INSERT INTO appointments (customer_id, barber_id, service_id, appointment_time, end_time, service_name, price, status, notes) VALUES (%s,%s,%s,%s,%s,%s,%s,'pending',%s)", (appt.customer_id, appt.barber_id, appt.service_id, appt.appointment_time, end_dt.strftime('%Y-%m-%d %H:%M:%S'), appt.service_name, appt.price, appt.notes))
            appt_id = cur.lastrowid
            await cur.execute("SELECT full_name FROM users WHERE id=%s", (appt.customer_id,))
            customer = await cur.fetchone()
            await cur.execute("SELECT u.id FROM users u JOIN barbers b ON u.id=b.user_id WHERE b.id=%s", (appt.barber_id,))
            barber_user = await cur.fetchone()
            if barber_user:
                cust_name = customer['full_name'] if customer else 'Mijoz'
                await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'appointment')", (barber_user['id'], "Yangi navbat!", f"{cust_name} navbat oldi: {appt.service_name}"))
            await conn.commit()
            return {"status": "success", "appointment_id": appt_id}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)

@app.get("/customer_appointments/{customer_id}")
async def get_customer_appointments(customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT a.*, b.name as barber_name, b.district, b.phone as barber_phone, b.avatar_url as barber_avatar, r.rating as my_rating FROM appointments a JOIN barbers b ON a.barber_id = b.id LEFT JOIN reviews r ON r.appointment_id = a.id AND r.customer_id = a.customer_id WHERE a.customer_id=%s ORDER BY a.appointment_time DESC", (customer_id,))
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                for k in ['appointment_time', 'end_time', 'created_at']:
                    if d.get(k) and hasattr(d[k], 'isoformat'): d[k] = d[k].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

@app.get("/barber_appointments/{barber_id}")
async def get_barber_appointments(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT a.*, u.full_name as customer_name, u.phone as customer_phone FROM appointments a JOIN users u ON a.customer_id = u.id WHERE a.barber_id=%s ORDER BY a.appointment_time DESC", (barber_id,))
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                for k in ['appointment_time', 'end_time', 'created_at']:
                    if d.get(k) and hasattr(d[k], 'isoformat'): d[k] = d[k].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

@app.put("/update_appointment_status/{app_id}")
async def update_appointment_status(app_id: int, status: str):
    if status not in ['pending', 'confirmed', 'completed', 'cancelled']:
        raise HTTPException(status_code=400, detail="Noto'g'ri status")
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("UPDATE appointments SET status=%s WHERE id=%s", (status, app_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Topilmadi")
            await cur.execute("SELECT a.customer_id, a.service_name, b.name as barber_name FROM appointments a JOIN barbers b ON a.barber_id=b.id WHERE a.id=%s", (app_id,))
            appt = await cur.fetchone()
            if appt:
                msgs = {'confirmed': ("Navbat tasdiqlandi", f"{appt['barber_name']} navbatingizni tasdiqladi"), 'completed': ("Xizmat yakunlandi", f"{appt['service_name']} muvaffaqiyatli yakunlandi"), 'cancelled': ("Navbat bekor qilindi", f"{appt['barber_name']} navbatingizni bekor qildi")}
                if status in msgs:
                    title, body = msgs[status]
                    await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'appointment')", (appt['customer_id'], title, body))
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

@app.put("/cancel_appointment/{app_id}")
async def cancel_appointment(app_id: int, customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE appointments SET status='cancelled' WHERE id=%s AND customer_id=%s AND status='pending'", (app_id, customer_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=400, detail="Bekor qilib bo'lmadi")
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

@app.post("/add_review")
async def add_review(review: ReviewCreate):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("SELECT id FROM reviews WHERE appointment_id=%s AND customer_id=%s", (review.appointment_id, review.customer_id))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Allaqachon baholangansiz")
            await cur.execute("INSERT INTO reviews (appointment_id, customer_id, barber_id, rating, comment) VALUES (%s,%s,%s,%s,%s)", (review.appointment_id, review.customer_id, review.barber_id, review.rating, review.comment))
            await cur.execute("SELECT AVG(rating) as avg_r, COUNT(*) as cnt FROM reviews WHERE barber_id=%s", (review.barber_id,))
            stats = await cur.fetchone()
            if stats and stats[0]:
                await cur.execute("UPDATE barbers SET rating=%s, total_reviews=%s WHERE id=%s", (round(float(stats[0]), 1), stats[1], review.barber_id))
            await conn.commit()
            return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)

@app.get("/barber_reviews/{barber_id}")
async def get_barber_reviews(barber_id: int, limit: int = 20):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT r.*, u.full_name as customer_name FROM reviews r JOIN users u ON r.customer_id=u.id WHERE r.barber_id=%s ORDER BY r.created_at DESC LIMIT %s", (barber_id, limit))
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'): d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

@app.post("/create_payment")
async def create_payment(payment: PaymentCreate):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, price, customer_id, payment_status FROM appointments WHERE id=%s", (payment.appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")
            await cur.execute("INSERT INTO payments (appointment_id, amount, method, status) VALUES (%s,%s,%s,'pending')", (payment.appointment_id, payment.amount, payment.method))
            payment_id = cur.lastrowid
            if payment.method in ['click', 'payme']:
                transaction_id = f"{payment.method.upper()}-{payment_id}-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
                await cur.execute("UPDATE payments SET status='completed', transaction_id=%s WHERE id=%s", (transaction_id, payment_id))
            else:
                await cur.execute("UPDATE payments SET status='completed' WHERE id=%s", (payment_id,))
            await cur.execute("UPDATE appointments SET payment_status='paid', payment_method=%s WHERE id=%s", (payment.method, payment.appointment_id))
            points = int(payment.amount // 50000)
            if points > 0:
                await cur.execute("UPDATE users SET loyalty_points = loyalty_points + %s WHERE id=%s", (points, appt['customer_id']))
            await conn.commit()
            return {"status": "success", "payment_id": payment_id, "loyalty_points_earned": points}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)

@app.get("/payment_history/{customer_id}")
async def get_payment_history(customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT p.*, a.service_name, b.name as barber_name FROM payments p JOIN appointments a ON p.appointment_id = a.id JOIN barbers b ON a.barber_id = b.id WHERE a.customer_id=%s AND p.status='completed' ORDER BY p.created_at DESC", (customer_id,))
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'): d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

@app.get("/barber_stats/{barber_id}")
async def get_barber_stats(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            today = datetime.date.today()
            month_start = today.replace(day=1)
            await cur.execute("SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND DATE(appointment_time)=%s AND status!='cancelled'", (barber_id, today))
            today_count = (await cur.fetchone())['cnt']
            await cur.execute("SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND status='completed'", (barber_id,))
            total_completed = (await cur.fetchone())['cnt']
            await cur.execute("SELECT COALESCE(SUM(p.amount),0) as rev FROM payments p JOIN appointments a ON p.appointment_id=a.id WHERE a.barber_id=%s AND p.status='completed'", (barber_id,))
            revenue = float((await cur.fetchone())['rev'])
            await cur.execute("SELECT COALESCE(SUM(p.amount),0) as rev FROM payments p JOIN appointments a ON p.appointment_id=a.id WHERE a.barber_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s", (barber_id, month_start))
            monthly_revenue = float((await cur.fetchone())['rev'])
            await cur.execute("SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND status='pending'", (barber_id,))
            pending_count = (await cur.fetchone())['cnt']
            await cur.execute("SELECT COALESCE(AVG(rating),5.0) as avg_r, COUNT(*) as cnt FROM reviews WHERE barber_id=%s", (barber_id,))
            review_stats = await cur.fetchone()
            return {"today_count": today_count, "total_completed": total_completed, "revenue": revenue, "monthly_revenue": monthly_revenue, "pending_count": pending_count, "avg_rating": round(float(review_stats['avg_r']), 1), "total_reviews": review_stats['cnt']}
    except Exception:
        return {"today_count": 0, "total_completed": 0, "revenue": 0, "monthly_revenue": 0, "pending_count": 0, "avg_rating": 5.0, "total_reviews": 0}
    finally:
        await release_conn(conn)

@app.get("/notifications/{user_id}")
async def get_notifications(user_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM notifications WHERE user_id=%s ORDER BY created_at DESC LIMIT 50", (user_id,))
            result = await cur.fetchall()
            await cur.execute("SELECT COUNT(*) as cnt FROM notifications WHERE user_id=%s AND is_read=0", (user_id,))
            unread = (await cur.fetchone())['cnt']
            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'): d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return {"notifications": rows, "unread_count": unread}
    finally:
        await release_conn(conn)

@app.put("/mark_notifications_read/{user_id}")
async def mark_all_read(user_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE notifications SET is_read=1 WHERE user_id=%s", (user_id,))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)

@app.post("/toggle_favorite")
async def toggle_favorite(customer_id: int, barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("SELECT id FROM favorites WHERE customer_id=%s AND barber_id=%s", (customer_id, barber_id))
            existing = await cur.fetchone()
            if existing:
                await cur.execute("DELETE FROM favorites WHERE customer_id=%s AND barber_id=%s", (customer_id, barber_id))
                await conn.commit()
                return {"status": "success", "is_favorite": False}
            else:
                try:
                    await cur.execute("INSERT INTO favorites (customer_id, barber_id) VALUES (%s,%s)", (customer_id, barber_id))
                    await conn.commit()
                    return {"status": "success", "is_favorite": True}
                except Exception:
                    await conn.rollback()
                    await cur.execute("DELETE FROM favorites WHERE customer_id=%s AND barber_id=%s", (customer_id, barber_id))
                    await conn.commit()
                    return {"status": "success", "is_favorite": False}
    except Exception as e:
        try:
            await conn.rollback()
        except Exception:
            pass
        return {"status": "error", "detail": str(e)}
    finally:
        await release_conn(conn)

@app.get("/favorites/{customer_id}")
async def get_favorites(customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT b.id, b.name, b.district, b.rating, b.specialization, b.is_online, b.avatar_url, b.lat, b.lng, b.total_reviews FROM favorites f JOIN barbers b ON f.barber_id=b.id WHERE f.customer_id=%s ORDER BY f.created_at DESC", (customer_id,))
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)

@app.post("/block_slot")
async def block_slot(slot: BlockedSlot):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("INSERT INTO barber_blocked_slots (barber_id, blocked_date, start_time, end_time, reason) VALUES (%s,%s,%s,%s,%s)", (slot.barber_id, slot.blocked_date, slot.start_time, slot.end_time, slot.reason))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)

@app.get("/blocked_slots/{barber_id}")
async def get_blocked_slots(barber_id: int, date: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM barber_blocked_slots WHERE barber_id=%s AND blocked_date=%s", (barber_id, date))
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)

# =====================================================
# CRM: SALON (SARTAROSHXONA) ENDPOINTLARI
# =====================================================

async def _get_owner_salon(cur, user_id):
    await cur.execute("SELECT * FROM salons WHERE owner_id=%s", (user_id,))
    salon = await cur.fetchone()
    if not salon:
        raise HTTPException(status_code=404, detail="Sizda sartaroshxona topilmadi")
    return salon

# ─── PUBLIC: Salon ko'rish ───

@app.get("/salons")
async def list_salons(page: int = 1, limit: int = 20):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            offset = (page - 1) * limit
            await cur.execute("SELECT s.id, s.name, s.description, s.address, s.district, s.lat, s.lng, s.phone, s.avatar_url, s.cover_url, s.rating, s.total_reviews, (SELECT COUNT(*) FROM barbers WHERE salon_id=s.id) as barbers_count FROM salons s WHERE s.is_active=1 ORDER BY s.rating DESC LIMIT %s OFFSET %s", (limit, offset))
            return [dict(s) for s in await cur.fetchall()]
    finally:
        await release_conn(conn)

@app.get("/salon/{salon_id}")
async def get_salon(salon_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM salons WHERE id=%s AND is_active=1", (salon_id,))
            salon = await cur.fetchone()
            if not salon:
                raise HTTPException(status_code=404, detail="Sartaroshxona topilmadi")
            await cur.execute("SELECT id, name, specialization, rating, total_reviews, avatar_url, is_online, is_accepting_bookings, experience FROM barbers WHERE salon_id=%s", (salon_id,))
            barbers = await cur.fetchall()
            result = dict(salon)
            result['working_hours_start'] = timedelta_to_str(result.get('working_hours_start'))
            result['working_hours_end'] = timedelta_to_str(result.get('working_hours_end'))
            for k in ['created_at', 'updated_at']:
                if result.get(k) and hasattr(result[k], 'isoformat'): result[k] = result[k].isoformat()
            result['barbers'] = [dict(b) for b in barbers]
            result['barbers_count'] = len(barbers)
            return result
    finally:
        await release_conn(conn)

# ─── OWNER: Salon boshqaruvi ───

@app.post("/create_salon")
async def create_salon(data: SalonCreate, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id FROM salons WHERE owner_id=%s", (owner["user_id"],))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Sizda allaqachon sartaroshxona mavjud")
            await cur.execute("INSERT INTO salons (owner_id, name, description, address, district, lat, lng, phone) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)", (owner["user_id"], data.name, data.description, data.address, data.district, data.lat, data.lng, data.phone))
            await conn.commit()
            return {"status": "success", "salon_id": cur.lastrowid}
    finally:
        await release_conn(conn)

@app.get("/my_salon")
async def get_my_salon(owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            result = dict(salon)
            result['working_hours_start'] = timedelta_to_str(result.get('working_hours_start'))
            result['working_hours_end'] = timedelta_to_str(result.get('working_hours_end'))
            for k in ['created_at', 'updated_at']:
                if result.get(k) and hasattr(result[k], 'isoformat'): result[k] = result[k].isoformat()
            return result
    finally:
        await release_conn(conn)

@app.put("/update_salon")
async def update_salon(data: SalonUpdate, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            fields, values = [], []
            for col in ("name", "description", "address", "district", "lat", "lng", "phone", "working_hours_start", "working_hours_end"):
                val = getattr(data, col)
                if val is not None:
                    fields.append(f"{col}=%s"); values.append(val)
            if fields:
                values.append(salon["id"])
                await cur.execute(f"UPDATE salons SET {','.join(fields)} WHERE id=%s", values)
                await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

# ─── OWNER: Xodimlar boshqaruvi ───

@app.get("/salon_staff")
async def get_salon_staff(owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            await cur.execute("SELECT b.id, b.name, b.specialization, b.phone, b.rating, b.total_reviews, b.avatar_url, b.is_online, b.is_accepting_bookings, b.experience, (SELECT COUNT(*) FROM appointments a WHERE a.barber_id=b.id AND a.status='completed') as completed_count, (SELECT COALESCE(SUM(p.amount),0) FROM payments p JOIN appointments a ON p.appointment_id=a.id WHERE a.barber_id=b.id AND p.status='completed') as total_revenue FROM barbers b WHERE b.salon_id=%s ORDER BY total_revenue DESC", (salon["id"],))
            staff = await cur.fetchall()
            return {"salon_id": salon["id"], "staff_count": len(staff), "staff": [dict(s) for s in staff]}
    finally:
        await release_conn(conn)

@app.post("/invite_barber")
async def invite_barber(data: StaffInvite, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            barber = None
            if data.barber_id:
                await cur.execute("SELECT id, salon_id, user_id FROM barbers WHERE id=%s", (data.barber_id,))
                barber = await cur.fetchone()
            elif data.barber_email:
                await cur.execute("SELECT b.id, b.salon_id, b.user_id FROM barbers b JOIN users u ON b.user_id=u.id WHERE u.email=%s", (data.barber_email,))
                barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Sartarosh topilmadi")
            if barber["salon_id"]:
                raise HTTPException(status_code=409, detail="Bu sartarosh allaqachon salonda ishlaydi")
            await cur.execute("SELECT id FROM salon_invitations WHERE salon_id=%s AND barber_id=%s AND status='pending'", (salon["id"], barber["id"]))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Bu sartaroshga allaqachon taklif yuborilgan")
            await cur.execute("INSERT INTO salon_invitations (salon_id, barber_id, initiated_by, message) VALUES (%s,%s,'owner',%s)", (salon["id"], barber["id"], data.message))
            await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')", (barber["user_id"], "Yangi taklif!", f"{salon['name']} sizni jamoasiga taklif qilmoqda"))
            await conn.commit()
            return {"status": "success", "invitation_id": cur.lastrowid}
    finally:
        await release_conn(conn)

@app.delete("/remove_barber/{barber_id}")
async def remove_barber(barber_id: int, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            await cur.execute("SELECT id, user_id FROM barbers WHERE id=%s AND salon_id=%s", (barber_id, salon["id"]))
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Sartarosh bu salonda topilmadi")
            await cur.execute("UPDATE barbers SET salon_id=NULL WHERE id=%s", (barber_id,))
            await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')", (barber["user_id"], "Salondan chiqarildingiz", f"{salon['name']} jamoasidan chiqarildingiz"))
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

# ─── INVITATIONS: Taklif/so'rovlar ───

@app.post("/join_request")
async def join_request(data: JoinRequest, auth=Depends(require_auth)):
    if auth.get("role") != "barber":
        raise HTTPException(status_code=403, detail="Faqat sartaroshlar so'rov yubora oladi")
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, salon_id FROM barbers WHERE user_id=%s", (auth["user_id"],))
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Sartarosh profili topilmadi")
            if barber["salon_id"]:
                raise HTTPException(status_code=409, detail="Siz allaqachon salonda ishlaysiz")
            await cur.execute("SELECT id, owner_id, name FROM salons WHERE id=%s", (data.salon_id,))
            salon = await cur.fetchone()
            if not salon:
                raise HTTPException(status_code=404, detail="Salon topilmadi")
            await cur.execute("SELECT id FROM salon_invitations WHERE salon_id=%s AND barber_id=%s AND status='pending'", (data.salon_id, barber["id"]))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="So'rovingiz allaqachon yuborilgan")
            await cur.execute("INSERT INTO salon_invitations (salon_id, barber_id, initiated_by, message) VALUES (%s,%s,'barber',%s)", (data.salon_id, barber["id"], data.message))
            await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')", (salon["owner_id"], "Yangi qo'shilish so'rovi", "Sartarosh saloningizga qo'shilmoqchi"))
            await conn.commit()
            return {"status": "success", "invitation_id": cur.lastrowid}
    finally:
        await release_conn(conn)

@app.get("/my_invitations")
async def my_invitations(auth=Depends(require_auth)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            role = auth.get("role")
            if role == "barber":
                await cur.execute("SELECT id FROM barbers WHERE user_id=%s", (auth["user_id"],))
                barber = await cur.fetchone()
                if not barber:
                    return []
                await cur.execute("SELECT i.*, s.name as salon_name, s.avatar_url as salon_avatar FROM salon_invitations i JOIN salons s ON i.salon_id=s.id WHERE i.barber_id=%s AND i.status='pending' ORDER BY i.created_at DESC", (barber["id"],))
            elif role == "owner":
                await cur.execute("SELECT id FROM salons WHERE owner_id=%s", (auth["user_id"],))
                salon = await cur.fetchone()
                if not salon:
                    return []
                await cur.execute("SELECT i.*, b.name as barber_name, b.avatar_url as barber_avatar, b.specialization, b.rating FROM salon_invitations i JOIN barbers b ON i.barber_id=b.id WHERE i.salon_id=%s AND i.status='pending' ORDER BY i.created_at DESC", (salon["id"],))
            else:
                return []
            rows = []
            for r in await cur.fetchall():
                d = dict(r)
                for k in ['created_at', 'responded_at']:
                    if d.get(k) and hasattr(d[k], 'isoformat'): d[k] = d[k].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

@app.put("/respond_invitation/{invitation_id}")
async def respond_invitation(invitation_id: int, data: InvitationResponse, auth=Depends(require_auth)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT i.*, s.owner_id, s.name as salon_name, b.user_id as barber_user_id FROM salon_invitations i JOIN salons s ON i.salon_id=s.id JOIN barbers b ON i.barber_id=b.id WHERE i.id=%s AND i.status='pending'", (invitation_id,))
            inv = await cur.fetchone()
            if not inv:
                raise HTTPException(status_code=404, detail="Taklif topilmadi yoki javob berilgan")
            if inv["initiated_by"] == "owner":
                if auth["user_id"] != inv["barber_user_id"]:
                    raise HTTPException(status_code=403, detail="Bu taklifga javob bera olmaysiz")
            else:
                if auth["user_id"] != inv["owner_id"]:
                    raise HTTPException(status_code=403, detail="Bu so'rovga javob bera olmaysiz")
            new_status = "accepted" if data.accept else "rejected"
            await cur.execute("UPDATE salon_invitations SET status=%s, responded_at=NOW() WHERE id=%s", (new_status, invitation_id))
            if data.accept:
                await cur.execute("UPDATE barbers SET salon_id=%s, verification_status='approved' WHERE id=%s", (inv["salon_id"], inv["barber_id"]))
                await cur.execute("UPDATE salon_invitations SET status='cancelled' WHERE barber_id=%s AND status='pending' AND id!=%s", (inv["barber_id"], invitation_id))
                await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')", (inv["barber_user_id"], "Salonga qo'shildingiz", f"Siz {inv['salon_name']} jamoasiga qo'shildingiz"))
            await conn.commit()
            return {"status": "success", "result": new_status}
    finally:
        await release_conn(conn)

# ─── OWNER DASHBOARD: Daromad analitikasi ───

@app.get("/owner_dashboard")
async def owner_dashboard(owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            salon_id = salon["id"]
            today = datetime.date.today()
            month_start = today.replace(day=1)
            await cur.execute("SELECT COALESCE(SUM(p.amount),0) as total FROM payments p JOIN appointments a ON p.appointment_id=a.id JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed'", (salon_id,))
            total_revenue = float((await cur.fetchone())["total"])
            await cur.execute("SELECT COALESCE(SUM(p.amount),0) as total FROM payments p JOIN appointments a ON p.appointment_id=a.id JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed' AND DATE(p.created_at)=%s", (salon_id, today))
            today_revenue = float((await cur.fetchone())["total"])
            await cur.execute("SELECT COALESCE(SUM(p.amount),0) as total FROM payments p JOIN appointments a ON p.appointment_id=a.id JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s", (salon_id, month_start))
            month_revenue = float((await cur.fetchone())["total"])
            await cur.execute("SELECT COUNT(CASE WHEN DATE(a.appointment_time)=%s AND a.status!='cancelled' THEN 1 END) as today_count, COUNT(CASE WHEN a.status='pending' THEN 1 END) as pending_count, COUNT(CASE WHEN a.status='completed' THEN 1 END) as completed_count FROM appointments a JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s", (today, salon_id))
            appt_stats = await cur.fetchone()
            await cur.execute("SELECT COUNT(*) as cnt FROM barbers WHERE salon_id=%s", (salon_id,))
            barbers_count = (await cur.fetchone())["cnt"]
            await cur.execute("SELECT b.id, b.name, b.avatar_url, b.rating, b.is_online, COALESCE(SUM(CASE WHEN p.status='completed' THEN p.amount END),0) as revenue, COUNT(CASE WHEN a.status='completed' THEN 1 END) as completed, COUNT(CASE WHEN DATE(a.appointment_time)=%s AND a.status!='cancelled' THEN 1 END) as today_appts FROM barbers b LEFT JOIN appointments a ON a.barber_id=b.id LEFT JOIN payments p ON p.appointment_id=a.id WHERE b.salon_id=%s GROUP BY b.id ORDER BY revenue DESC", (today, salon_id))
            per_barber = [dict(r) for r in await cur.fetchall()]
            for b in per_barber:
                b["revenue"] = float(b["revenue"])
            return {
                "salon_id": salon_id,
                "salon_name": salon["name"],
                "revenue": {"total": total_revenue, "today": today_revenue, "month": month_revenue},
                "appointments": {"today": appt_stats["today_count"], "pending": appt_stats["pending_count"], "completed": appt_stats["completed_count"]},
                "barbers_count": barbers_count,
                "barbers_revenue": per_barber,
            }
    finally:
        await release_conn(conn)

@app.get("/owner_revenue_report")
async def owner_revenue_report(days: int = 7, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            start_date = datetime.date.today() - datetime.timedelta(days=days - 1)
            await cur.execute("SELECT DATE(p.created_at) as day, COALESCE(SUM(p.amount),0) as revenue, COUNT(*) as transactions FROM payments p JOIN appointments a ON p.appointment_id=a.id JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s GROUP BY DATE(p.created_at) ORDER BY day", (salon["id"], start_date))
            rows = await cur.fetchall()
            report = {}
            for r in rows:
                day_str = r["day"].isoformat() if hasattr(r["day"], "isoformat") else str(r["day"])
                report[day_str] = {"revenue": float(r["revenue"]), "transactions": r["transactions"]}
            result = []
            for i in range(days):
                d = (start_date + datetime.timedelta(days=i)).isoformat()
                entry = report.get(d, {"revenue": 0.0, "transactions": 0})
                result.append({"date": d, **entry})
            return {"salon_id": salon["id"], "days": days, "report": result}
    finally:
        await release_conn(conn)

# =====================================================
# VERIFICATION: Sartarosh tasdiqlash
# =====================================================

@app.get("/barber_status/{barber_id}")
async def get_barber_status(barber_id: int):
    """Sartaroshning tasdiqlash holatini qaytaradi (pending/approved/rejected)"""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT verification_status, salon_id FROM barbers WHERE id=%s", (barber_id,))
            row = await cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Sartarosh topilmadi")
            return {"verification_status": row["verification_status"], "salon_id": row["salon_id"]}
    finally:
        await release_conn(conn)


def _check_admin(x_admin_key: str | None):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="Admin huquqi talab qilinadi")


@app.get("/admin/pending_barbers")
async def admin_pending_barbers(x_admin_key: str = Header(None)):
    """Tasdiqlanmagan (pending) sartaroshlar ro'yxati — admin uchun"""
    _check_admin(x_admin_key)
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT b.id, b.name, b.phone, b.specialization, b.experience, b.bio, b.district, "
                "b.avatar_url, b.created_at, u.email "
                "FROM barbers b JOIN users u ON b.user_id=u.id "
                "WHERE b.verification_status='pending' ORDER BY b.created_at DESC"
            )
            rows = []
            for r in await cur.fetchall():
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'):
                    d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)


@app.put("/admin/verify_barber/{barber_id}")
async def admin_verify_barber(barber_id: int, approve: bool = True, x_admin_key: str = Header(None)):
    """Sartaroshni tasdiqlash yoki rad etish — admin uchun"""
    _check_admin(x_admin_key)
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            new_status = "approved" if approve else "rejected"
            await cur.execute("UPDATE barbers SET verification_status=%s WHERE id=%s", (new_status, barber_id))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Sartarosh topilmadi")
            await cur.execute("SELECT user_id, name FROM barbers WHERE id=%s", (barber_id,))
            b = await cur.fetchone()
            if b:
                title = "Profilingiz tasdiqlandi!" if approve else "Profilingiz rad etildi"
                body = "Endi mijozlar sizni ko'radi va navbat oladi" if approve else "Iltimos, ma'lumotlaringizni qayta tekshiring"
                await cur.execute("INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')", (b["user_id"], title, body))
            await conn.commit()
            return {"status": "success", "verification_status": new_status}
    finally:
        await release_conn(conn)


@app.post("/change_password")
async def change_password(data: ChangePassword):
    """Foydalanuvchi parolini o'zgartirish (eski parolni tekshirib)"""
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="Yangi parol kamida 6 belgidan iborat bo'lishi kerak")
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT password_hash FROM users WHERE id=%s", (data.user_id,))
            row = await cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")
            if not pwd_context.verify(data.old_password, row["password_hash"]):
                raise HTTPException(status_code=401, detail="Joriy parol noto'g'ri")
            new_hash = hash_password(data.new_password)
            await cur.execute("UPDATE users SET password_hash=%s WHERE id=%s", (new_hash, data.user_id))
            await conn.commit()
            return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


# =====================================================
# CHAT / XABARLAR
# =====================================================

@app.post("/send_message")
async def send_message(data: MessageCreate):
    """Bir foydalanuvchidan boshqasiga xabar yuborish"""
    if not data.body or not data.body.strip():
        raise HTTPException(status_code=400, detail="Xabar bo'sh bo'lishi mumkin emas")
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "INSERT INTO messages (sender_id, receiver_id, body) VALUES (%s,%s,%s)",
                (data.sender_id, data.receiver_id, data.body.strip()),
            )
            msg_id = cur.lastrowid
            await cur.execute("SELECT id, sender_id, receiver_id, body, is_read, created_at FROM messages WHERE id=%s", (msg_id,))
            row = await cur.fetchone()
            await conn.commit()
            d = dict(row)
            if d.get("created_at") and hasattr(d["created_at"], "isoformat"):
                d["created_at"] = d["created_at"].isoformat()
            return {"status": "success", "message": d}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


@app.get("/messages/{user_id}/{other_id}")
async def get_messages(user_id: int, other_id: int):
    """Ikki foydalanuvchi o'rtasidagi yozishmalar. Kelgan xabarlar o'qilgan deb belgilanadi."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, sender_id, receiver_id, body, is_read, created_at FROM messages "
                "WHERE (sender_id=%s AND receiver_id=%s) OR (sender_id=%s AND receiver_id=%s) "
                "ORDER BY created_at ASC, id ASC",
                (user_id, other_id, other_id, user_id),
            )
            rows = []
            for r in await cur.fetchall():
                d = dict(r)
                if d.get("created_at") and hasattr(d["created_at"], "isoformat"):
                    d["created_at"] = d["created_at"].isoformat()
                rows.append(d)
            # other_id -> user_id yo'nalishidagi xabarlarni o'qilgan deb belgilash
            await cur.execute(
                "UPDATE messages SET is_read=1 WHERE sender_id=%s AND receiver_id=%s AND is_read=0",
                (other_id, user_id),
            )
            await conn.commit()
            return {"messages": rows}
    finally:
        await release_conn(conn)


@app.get("/conversations/{user_id}")
async def get_conversations(user_id: int):
    """Foydalanuvchining suhbatlari ro'yxati (har bir hamsuhbat + oxirgi xabar + o'qilmaganlar soni)"""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT m.id, m.sender_id, m.receiver_id, m.body, m.is_read, m.created_at, "
                "CASE WHEN m.sender_id=%s THEN m.receiver_id ELSE m.sender_id END AS partner_id "
                "FROM messages m "
                "WHERE m.sender_id=%s OR m.receiver_id=%s "
                "ORDER BY m.created_at DESC, m.id DESC",
                (user_id, user_id, user_id),
            )
            all_msgs = await cur.fetchall()
            convos = {}
            for r in all_msgs:
                pid = r["partner_id"]
                if pid not in convos:
                    last = dict(r)
                    if last.get("created_at") and hasattr(last["created_at"], "isoformat"):
                        last["created_at"] = last["created_at"].isoformat()
                    convos[pid] = {"partner_id": pid, "last_message": last["body"], "last_time": last["created_at"], "unread": 0}
                # o'qilmagan: menga kelgan va o'qilmagan
                if r["receiver_id"] == user_id and not r["is_read"]:
                    convos[pid]["unread"] += 1
            partner_ids = list(convos.keys())
            if partner_ids:
                fmt = ",".join(["%s"] * len(partner_ids))
                await cur.execute(f"SELECT id, full_name FROM users WHERE id IN ({fmt})", partner_ids)
                names = {u["id"]: u["full_name"] for u in await cur.fetchall()}
                for pid in convos:
                    convos[pid]["partner_name"] = names.get(pid, "Foydalanuvchi")
            return {"conversations": list(convos.values())}
    finally:
        await release_conn(conn)


# =====================================================
# ONLAYN TO'LOV (Payme / Click)
# =====================================================
# DIQQAT: bu kod test/placeholder kalitlar bilan ishlaydi. Haqiqiy to'lov uchun
# .env da PAYME_* va CLICK_* qiymatlarini bering va merchant kabinetida quyidagi
# webhook URL larni ro'yxatdan o'tkazing:
#   Payme:  {SERVER_BASE_URL}/payme/callback
#   Click:  Prepare -> {SERVER_BASE_URL}/click/prepare
#           Complete -> {SERVER_BASE_URL}/click/complete

_ORDER_NOT_FOUND = {"uz": "Buyurtma topilmadi", "ru": "Заказ не найден", "en": "Order not found"}
_INVALID_AMOUNT = {"uz": "Noto'g'ri summa", "ru": "Неверная сумма", "en": "Invalid amount"}
_CANT_PERFORM = {"uz": "Operatsiyani bajarib bo'lmaydi", "ru": "Невозможно выполнить операцию", "en": "Unable to perform operation"}
_TX_NOT_FOUND = {"uz": "Tranzaksiya topilmadi", "ru": "Транзакция не найдена", "en": "Transaction not found"}


def _payme_error(req_id, code, message, data=None):
    err = {"code": code, "message": message}
    if data is not None:
        err["data"] = data
    return {"error": err, "id": req_id}


def _click_sign(*parts):
    return hashlib.md5("".join("" if p is None else str(p) for p in parts).encode()).hexdigest()


async def _gw_mark_paid(cur, order_id: int, method: str):
    """Buyurtmani 'paid' qilish + payments yozuvi + loyalty + bildirishnoma."""
    await cur.execute("SELECT price, customer_id, payment_status FROM appointments WHERE id=%s", (order_id,))
    appt = await cur.fetchone()
    if not appt or appt['payment_status'] == 'paid':
        return
    amount = float(appt['price'] or 0)
    await cur.execute(
        "INSERT INTO payments (appointment_id, amount, method, status, transaction_id) VALUES (%s,%s,%s,'completed',%s)",
        (order_id, amount, method, f"{method.upper()}-{order_id}-{int(time.time())}"),
    )
    await cur.execute("UPDATE appointments SET payment_status='paid', payment_method=%s WHERE id=%s", (method, order_id))
    points = int(amount // 50000)
    if points > 0:
        await cur.execute("UPDATE users SET loyalty_points = loyalty_points + %s WHERE id=%s", (points, appt['customer_id']))
    try:
        await cur.execute(
            "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'payment')",
            (appt['customer_id'], "To'lov qabul qilindi", f"{int(amount)} so'm to'lovingiz qabul qilindi"),
        )
    except Exception:
        pass


@app.post("/payment/checkout")
async def payment_checkout(data: CheckoutRequest):
    """Tanlangan tizim uchun checkout URL qaytaradi (ilova uni ochadi)."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, price, payment_status FROM appointments WHERE id=%s", (data.appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")
            amount_sum = float(appt['price'] or 0)
            if amount_sum <= 0:
                raise HTTPException(status_code=400, detail="To'lov summasi noto'g'ri")
            gw = data.gateway.lower()
            if gw == 'payme':
                amount_tiyin = int(round(amount_sum * 100))
                raw = f"m={PAYME_MERCHANT_ID};ac.order_id={data.appointment_id};a={amount_tiyin};c={PAYMENT_RETURN_URL}"
                encoded = base64.b64encode(raw.encode()).decode()
                url = f"{PAYME_CHECKOUT_URL}/{encoded}"
            elif gw == 'click':
                amount_int = int(round(amount_sum))
                url = (
                    f"{CLICK_CHECKOUT_URL}?service_id={CLICK_SERVICE_ID}"
                    f"&merchant_id={CLICK_MERCHANT_ID}&amount={amount_int}"
                    f"&transaction_param={data.appointment_id}&return_url={PAYMENT_RETURN_URL}"
                )
            else:
                raise HTTPException(status_code=400, detail="Noto'g'ri to'lov tizimi")
            return {"checkout_url": url, "order_id": data.appointment_id, "amount": amount_sum, "gateway": gw}
    finally:
        await release_conn(conn)


@app.get("/payment/status/{appointment_id}")
async def payment_status(appointment_id: int):
    """Ilova to'lov holatini polling qilish uchun."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT payment_status FROM appointments WHERE id=%s", (appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            await cur.execute(
                "SELECT gateway, state FROM gateway_transactions WHERE order_id=%s ORDER BY id DESC LIMIT 1",
                (appointment_id,),
            )
            tx = await cur.fetchone()
            return {
                "payment_status": appt['payment_status'],
                "paid": appt['payment_status'] == 'paid',
                "gateway": tx['gateway'] if tx else None,
                "state": tx['state'] if tx else 0,
            }
    finally:
        await release_conn(conn)


@app.get("/payment/return", response_class=HTMLResponse)
async def payment_return():
    return HTMLResponse(
        "<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>To'lov</title></head>"
        "<body style='font-family:sans-serif;text-align:center;padding:48px;color:#222'>"
        "<h2>To'lov jarayoni yakunlandi</h2>"
        "<p>Ilovaga qaytishingiz mumkin.</p></body></html>"
    )


# ─── PAYME JSON-RPC ──────────────────────────────────────────────────────────

@app.post("/payme/callback")
async def payme_callback(request: Request):
    try:
        body = await request.json()
    except Exception:
        return _payme_error(None, -32700, "JSON parse xatosi")
    req_id = body.get("id")
    method = body.get("method")
    params = body.get("params", {}) or {}

    # Basic Auth tekshiruvi
    auth = request.headers.get("Authorization", "")
    expected = "Basic " + base64.b64encode(f"Paycom:{PAYME_KEY}".encode()).decode()
    if auth != expected:
        return _payme_error(req_id, -32504, "Avtorizatsiya xatosi")

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            if method == "CheckPerformTransaction":
                amount = params.get("amount")
                order_id = (params.get("account") or {}).get("order_id")
                if not order_id:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (order_id,))
                appt = await cur.fetchone()
                if not appt:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                if amount != int(round(float(appt['price']) * 100)):
                    return _payme_error(req_id, -31001, _INVALID_AMOUNT)
                return {"result": {"allow": True}, "id": req_id}

            elif method == "CreateTransaction":
                trans_id = params.get("id")
                amount = params.get("amount")
                ptime = params.get("time")
                order_id = (params.get("account") or {}).get("order_id")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if tx:
                    if tx['state'] != 1:
                        return _payme_error(req_id, -31008, _CANT_PERFORM)
                    return {"result": {"create_time": tx['create_time'], "transaction": str(tx['id']), "state": 1}, "id": req_id}
                if not order_id:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (order_id,))
                appt = await cur.fetchone()
                if not appt:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                if amount != int(round(float(appt['price']) * 100)):
                    return _payme_error(req_id, -31001, _INVALID_AMOUNT)
                # Buyurtmada faol tranzaksiya bormi?
                await cur.execute("SELECT id FROM gateway_transactions WHERE gateway='payme' AND order_id=%s AND state IN (1,2)", (order_id,))
                if await cur.fetchone():
                    return _payme_error(req_id, -31008, _CANT_PERFORM)
                await cur.execute(
                    "INSERT INTO gateway_transactions (gateway, order_id, amount, state, provider_trans_id, create_time) VALUES ('payme',%s,%s,1,%s,%s)",
                    (order_id, amount, trans_id, ptime),
                )
                new_id = cur.lastrowid
                await conn.commit()
                return {"result": {"create_time": ptime, "transaction": str(new_id), "state": 1}, "id": req_id}

            elif method == "PerformTransaction":
                trans_id = params.get("id")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if not tx:
                    return _payme_error(req_id, -31003, _TX_NOT_FOUND)
                if tx['state'] == 2:
                    return {"result": {"transaction": str(tx['id']), "perform_time": tx['perform_time'], "state": 2}, "id": req_id}
                if tx['state'] != 1:
                    return _payme_error(req_id, -31008, _CANT_PERFORM)
                perform_time = int(time.time() * 1000)
                await cur.execute("UPDATE gateway_transactions SET state=2, perform_time=%s WHERE id=%s", (perform_time, tx['id']))
                await _gw_mark_paid(cur, tx['order_id'], 'payme')
                await conn.commit()
                return {"result": {"transaction": str(tx['id']), "perform_time": perform_time, "state": 2}, "id": req_id}

            elif method == "CancelTransaction":
                trans_id = params.get("id")
                reason = params.get("reason")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if not tx:
                    return _payme_error(req_id, -31003, _TX_NOT_FOUND)
                if tx['state'] in (-1, -2):
                    return {"result": {"transaction": str(tx['id']), "cancel_time": tx['cancel_time'], "state": tx['state']}, "id": req_id}
                cancel_time = int(time.time() * 1000)
                if tx['state'] == 1:
                    new_state = -1
                else:  # state == 2
                    new_state = -2
                    await cur.execute("UPDATE appointments SET payment_status='unpaid' WHERE id=%s", (tx['order_id'],))
                await cur.execute("UPDATE gateway_transactions SET state=%s, cancel_time=%s, reason=%s WHERE id=%s", (new_state, cancel_time, reason, tx['id']))
                await conn.commit()
                return {"result": {"transaction": str(tx['id']), "cancel_time": cancel_time, "state": new_state}, "id": req_id}

            elif method == "CheckTransaction":
                trans_id = params.get("id")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if not tx:
                    return _payme_error(req_id, -31003, _TX_NOT_FOUND)
                return {"result": {
                    "create_time": tx['create_time'],
                    "perform_time": tx['perform_time'],
                    "cancel_time": tx['cancel_time'],
                    "transaction": str(tx['id']),
                    "state": tx['state'],
                    "reason": tx['reason'],
                }, "id": req_id}

            elif method == "GetStatement":
                frm = params.get("from")
                to = params.get("to")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND create_time BETWEEN %s AND %s", (frm, to))
                rows = await cur.fetchall()
                transactions = [{
                    "id": r['provider_trans_id'],
                    "time": r['create_time'],
                    "amount": r['amount'],
                    "account": {"order_id": r['order_id']},
                    "create_time": r['create_time'],
                    "perform_time": r['perform_time'],
                    "cancel_time": r['cancel_time'],
                    "transaction": str(r['id']),
                    "state": r['state'],
                    "reason": r['reason'],
                } for r in rows]
                return {"result": {"transactions": transactions}, "id": req_id}

            else:
                return _payme_error(req_id, -32601, "Metod topilmadi")
    except Exception as e:
        await conn.rollback()
        return _payme_error(req_id, -31008, {"uz": str(e), "ru": str(e), "en": str(e)})
    finally:
        await release_conn(conn)


# ─── CLICK SHOP API ──────────────────────────────────────────────────────────

@app.post("/click/prepare")
async def click_prepare(request: Request):
    form = await request.form()
    click_trans_id = form.get("click_trans_id")
    service_id = form.get("service_id")
    merchant_trans_id = form.get("merchant_trans_id")  # order_id (appointment_id)
    amount = form.get("amount")
    action = form.get("action")
    sign_time = form.get("sign_time")
    sign_string = form.get("sign_string")

    expected_sign = _click_sign(click_trans_id, service_id, CLICK_SECRET_KEY, merchant_trans_id, amount, action, sign_time)
    if sign_string != expected_sign:
        return {"error": -1, "error_note": "SIGN CHECK FAILED"}
    if str(action) != "0":
        return {"error": -3, "error_note": "Action not found"}

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (merchant_trans_id,))
            appt = await cur.fetchone()
            if not appt:
                return {"error": -5, "error_note": "Buyurtma topilmadi"}
            if appt['payment_status'] == 'paid':
                return {"error": -4, "error_note": "Allaqachon to'langan"}
            if abs(float(amount) - float(appt['price'])) > 0.01:
                return {"error": -2, "error_note": "Noto'g'ri summa"}
            await cur.execute(
                "INSERT INTO gateway_transactions (gateway, order_id, amount, state, provider_trans_id, create_time) VALUES ('click',%s,%s,1,%s,%s)",
                (merchant_trans_id, int(round(float(amount))), click_trans_id, int(time.time())),
            )
            prepare_id = cur.lastrowid
            await conn.commit()
            return {
                "click_trans_id": click_trans_id,
                "merchant_trans_id": merchant_trans_id,
                "merchant_prepare_id": prepare_id,
                "error": 0,
                "error_note": "Success",
            }
    finally:
        await release_conn(conn)


@app.post("/click/complete")
async def click_complete(request: Request):
    form = await request.form()
    click_trans_id = form.get("click_trans_id")
    service_id = form.get("service_id")
    merchant_trans_id = form.get("merchant_trans_id")
    merchant_prepare_id = form.get("merchant_prepare_id")
    amount = form.get("amount")
    action = form.get("action")
    sign_time = form.get("sign_time")
    sign_string = form.get("sign_string")
    try:
        click_error = int(form.get("error", "0") or 0)
    except (TypeError, ValueError):
        click_error = 0

    expected_sign = _click_sign(click_trans_id, service_id, CLICK_SECRET_KEY, merchant_trans_id, merchant_prepare_id, amount, action, sign_time)
    if sign_string != expected_sign:
        return {"error": -1, "error_note": "SIGN CHECK FAILED"}
    if str(action) != "1":
        return {"error": -3, "error_note": "Action not found"}

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM gateway_transactions WHERE id=%s AND gateway='click'", (merchant_prepare_id,))
            tx = await cur.fetchone()
            if not tx:
                return {"error": -6, "error_note": "Tranzaksiya topilmadi"}
            if tx['state'] == -1:
                return {"error": -9, "error_note": "Tranzaksiya bekor qilingan"}
            # Foydalanuvchi Click tomonida bekor qilgan bo'lsa
            if click_error < 0:
                await cur.execute("UPDATE gateway_transactions SET state=-1, cancel_time=%s WHERE id=%s", (int(time.time()), tx['id']))
                await conn.commit()
                return {"error": click_error, "error_note": "Bekor qilindi"}
            await cur.execute("SELECT payment_status FROM appointments WHERE id=%s", (merchant_trans_id,))
            appt = await cur.fetchone()
            if not appt:
                return {"error": -5, "error_note": "Buyurtma topilmadi"}
            if appt['payment_status'] != 'paid':
                await cur.execute("UPDATE gateway_transactions SET state=2, perform_time=%s WHERE id=%s", (int(time.time()), tx['id']))
                await _gw_mark_paid(cur, int(merchant_trans_id), 'click')
                await conn.commit()
            return {
                "click_trans_id": click_trans_id,
                "merchant_trans_id": merchant_trans_id,
                "merchant_confirm_id": tx['id'],
                "error": 0,
                "error_note": "Success",
            }
    finally:
        await release_conn(conn)


@app.get("/")
async def root():
    return {"message": "Sartaroshxona API ishlayapti", "version": "3.0.0"}

@app.get("/health")
async def health_check():
    try:
        conn = await get_conn()
        try:
            async with conn.cursor() as cur:
                await cur.execute("SELECT 1")
        finally:
            await release_conn(conn)
        return {"status": "ok", "db": "connected", "version": "3.0.0"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"DB xatolik: {str(e)}")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
