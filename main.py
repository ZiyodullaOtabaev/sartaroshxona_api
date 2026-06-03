from fastapi import FastAPI, HTTPException, UploadFile, File, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
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

from typing import Optional, List
from contextlib import asynccontextmanager

from passlib.context import CryptContext
import ssl

# =====================================================
# CONFIG
# =====================================================

SECRET_KEY = os.getenv("SECRET_KEY", "sartaroshxona-super-secret-key-2025!@#")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

SERVER_BASE_URL = os.getenv("SERVER_BASE_URL", "http://192.168.10.4:8000")

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "0000"),
    "db": os.getenv("DB_NAME", "sartaroshxona_db"),
    "autocommit": False,
    "minsize": 5,
    "maxsize": 20,
}

if os.getenv("DB_HOST") and "aiven" in os.getenv("DB_HOST", ""):
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE
    DB_CONFIG["ssl"] = ssl_ctx


# =====================================================
# APP LIFESPAN (Connection Pool)
# =====================================================

pool: aiomysql.Pool = None # type: ignore

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
    yield
    pool.close()
    await pool.wait_closed()


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
    """JWT token yaratish"""
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + datetime.timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str) -> dict:
    """JWT tokenni tekshirish"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token muddati tugagan")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Yaroqsiz token")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Hozirgi foydalanuvchini olish (optional auth)"""
    if credentials is None:
        return None
    return verify_token(credentials.credentials)

async def require_auth(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Majburiy autentifikatsiya"""
    if credentials is None:
        raise HTTPException(status_code=401, detail="Token talab qilinadi")
    return verify_token(credentials.credentials)

# =====================================================
# DATABASE HELPER (Pool-based)
# =====================================================

async def get_conn():
    """Pool'dan connection olish"""
    return await pool.acquire()

async def release_conn(conn):
    """Connection'ni pool'ga qaytarish"""
    pool.release(conn)

# =====================================================
# HELPERS
# =====================================================

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str):
    return pwd_context.verify(plain, hashed)

def haversine(lat1, lon1, lat2, lon2):
    """Ikki nuqta orasidagi masofani km da hisoblash"""
    if None in (lat1, lon1, lat2, lon2):
        return 0.0

    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )

    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def timedelta_to_str(td):
    """timedelta ni string formatga o'girish"""
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

class UserLogin(BaseModel):
    email: EmailStr
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

            await cur.execute(
                """INSERT INTO users (full_name, email, password_hash, role, phone)
                   VALUES (%s,%s,%s,%s,%s)""",
                (user.full_name, user.email, hashed_password, user.role, user.phone)
            )
            user_id = cur.lastrowid

            if user.role == "barber":
                await cur.execute(
                    """INSERT INTO barbers
                       (user_id, name, experience, phone, specialization, bio, lat, lng, rating, total_reviews, district)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,5.0,0,'Toshkent')""",
                    (user_id, user.full_name, user.experience or "", user.phone,
                     user.specialization or "", user.bio or "", user.lat, user.lng)
                )
                barber_id = cur.lastrowid

                for day in range(1, 7):
                    await cur.execute(
                        "INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,1)",
                        (barber_id, day)
                    )

            await conn.commit()

            token = create_access_token({"user_id": user_id, "role": user.role, "email": user.email})

            return {
                "status": "success",
                "user_id": user_id,
                "token": token,
            }

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
            await cur.execute("""
                SELECT 
                    u.id, u.full_name, u.email, u.password_hash, u.role, u.phone, u.loyalty_points,
                    b.id as barber_id, b.is_online, b.rating, b.specialization, b.bio,
                    b.avatar_url, b.working_hours_start, b.working_hours_end
                FROM users u
                LEFT JOIN barbers b ON u.id = b.user_id
                WHERE u.email=%s
            """, (user.email,))

            db_user = await cur.fetchone()

            if not db_user:
                raise HTTPException(status_code=401, detail="Email yoki parol noto'g'ri")

            if not pwd_context.verify(user.password, db_user["password_hash"]):
                raise HTTPException(status_code=401, detail="Email yoki parol noto'g'ri")

            db_user.pop("password_hash", None)

            token = create_access_token({
                "user_id": db_user["id"],
                "role": db_user["role"],
                "email": db_user["email"],
            })

            if db_user.get("working_hours_start"):
                db_user["working_hours_start"] = timedelta_to_str(db_user["working_hours_start"])
            if db_user.get("working_hours_end"):
                db_user["working_hours_end"] = timedelta_to_str(db_user["working_hours_end"])

            return {
                "status": "success",
                "token": token,
                "user": db_user,
            }
    finally:
        await release_conn(conn)

# =====================================================
# AVATAR UPLOAD
# =====================================================

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

# =====================================================
# BARBERS
# =====================================================

@app.get("/nearby_barbers")
async def get_nearby_barbers(user_lat: float, user_lng: float, radius_km: float = 2.0):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                """SELECT id, name, district, rating, total_reviews, lat, lng,
                          experience, specialization, phone, is_online, avatar_url, bio,
                          working_hours_start, working_hours_end
                   FROM barbers WHERE lat IS NOT NULL AND lng IS NOT NULL"""
            )
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
            await cur.execute(
                """SELECT id, name, district, rating, total_reviews, lat, lng,
                          experience, specialization, phone, is_online, avatar_url, bio
                   FROM barbers WHERE lat IS NOT NULL AND lng IS NOT NULL"""
            )
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
            await cur.execute(
                """SELECT id, name, district, rating, total_reviews, lat, lng,
                          experience, specialization, phone, is_online, avatar_url, bio
                   FROM barbers WHERE name LIKE %s OR district LIKE %s OR specialization LIKE %s""",
                (like, like, like)
            )
            result = await cur.fetchall()
            return [dict(b) for b in result]
    finally:
        await release_conn(conn)

@app.get("/barber/{barber_id}")
async def get_barber_detail(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT b.*, u.email FROM barbers b JOIN users u ON b.user_id = u.id WHERE b.id=%s",
                (barber_id,)
            )
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Topilmadi")

            await cur.execute(
                "SELECT day_of_week, is_working FROM barber_working_days WHERE barber_id=%s ORDER BY day_of_week",
                (barber_id,)
            )
            working_days = await cur.fetchall()

            await cur.execute(
                "SELECT * FROM barber_services WHERE barber_id=%s AND is_active=1",
                (barber_id,)
            )
            services = await cur.fetchall()

            await cur.execute(
                """SELECT r.*, u.full_name as customer_name
                   FROM reviews r JOIN users u ON r.customer_id=u.id
                   WHERE r.barber_id=%s ORDER BY r.created_at DESC LIMIT 10""",
                (barber_id,)
            )
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
            if data.full_name:
                fields.append("name=%s"); values.append(data.full_name)
            if data.phone:
                fields.append("phone=%s"); values.append(data.phone)
            if data.bio is not None:
                fields.append("bio=%s"); values.append(data.bio)
            if data.specialization:
                fields.append("specialization=%s"); values.append(data.specialization)
            if data.experience:
                fields.append("experience=%s"); values.append(data.experience)
            if data.working_hours_start:
                fields.append("working_hours_start=%s"); values.append(data.working_hours_start)
            if data.working_hours_end:
                fields.append("working_hours_end=%s"); values.append(data.working_hours_end)
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
                await cur.execute(
                    "INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,%s)",
                    (barber_id, day, day in days)
                )
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

# =====================================================
# AVAILABLE SLOTS
# =====================================================

@app.get("/available_slots/{barber_id}")
async def get_available_slots(barber_id: int, date: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT working_hours_start, working_hours_end, slot_duration_minutes FROM barbers WHERE id=%s",
                (barber_id,)
            )
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Barber topilmadi")

            target_date = datetime.date.fromisoformat(date)
            day_of_week = target_date.isoweekday() % 7

            await cur.execute(
                "SELECT is_working FROM barber_working_days WHERE barber_id=%s AND day_of_week=%s",
                (barber_id, day_of_week)
            )
            wd = await cur.fetchone()
            if wd and not wd['is_working']:
                return {"date": date, "slots": [], "message": "Dam olish kuni"}

            await cur.execute(
                """SELECT appointment_time, end_time FROM appointments
                   WHERE barber_id=%s AND DATE(appointment_time)=%s AND status NOT IN ('cancelled')""",
                (barber_id, date)
            )
            booked = await cur.fetchall()

            await cur.execute(
                "SELECT start_time, end_time FROM barber_blocked_slots WHERE barber_id=%s AND blocked_date=%s",
                (barber_id, date)
            )
            blocked = await cur.fetchall()

            def td_to_minutes(td):
                if isinstance(td, datetime.timedelta):
                    return int(td.total_seconds()) // 60
                if isinstance(td, (datetime.datetime, datetime.time)):
                    return td.hour * 60 + td.minute
                if isinstance(td, str) and ':' in td:
                    h, m = map(int, td.split(':')[:2])
                    return h * 60 + m
                return 0

            start_min = td_to_minutes(barber['working_hours_start'])
            end_min = td_to_minutes(barber['working_hours_end'])
            slot_dur = barber['slot_duration_minutes'] or 30

            booked_ranges = []
            for b in booked:
                s_td = b['appointment_time']
                e_td = b['end_time']
                if hasattr(s_td, 'hour'):
                    s = s_td.hour * 60 + s_td.minute
                elif hasattr(s_td, 'strftime'):
                    t = s_td.strftime('%H:%M')
                    h, m = map(int, t.split(':'))
                    s = h * 60 + m
                else:
                    s = td_to_minutes(s_td)

                if e_td and hasattr(e_td, 'hour'):
                    e = e_td.hour * 60 + e_td.minute
                elif e_td and hasattr(e_td, 'strftime'):
                    t = e_td.strftime('%H:%M')
                    h, m = map(int, t.split(':'))
                    e = h * 60 + m
                else:
                    e = s + slot_dur

                booked_ranges.append((s, e))

            for bl in blocked:
                s = td_to_minutes(bl['start_time'])
                e = td_to_minutes(bl['end_time'])
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

# =====================================================
# SERVICES
# =====================================================

@app.get("/get_services/{barber_id}")
async def get_services(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM barber_services WHERE barber_id=%s AND is_active=1 ORDER BY id",
                (barber_id,)
            )
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)

@app.post("/add_service")
async def add_service(barber_id: int, name: str, price: float, duration: int = 30, description: str = ""):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO barber_services (barber_id, service_name, price, duration_minutes, description) VALUES (%s,%s,%s,%s,%s)",
                (barber_id, name, price, duration, description)
            )
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

# =====================================================
# APPOINTMENTS
# =====================================================

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
                await cur.execute(
                    "SELECT duration_minutes, price FROM barber_services WHERE id=%s", (appt.service_id,)
                )
                svc = await cur.fetchone()
                if svc:
                    duration = svc['duration_minutes']
                    if not appt.price:
                        appt.price = svc['price']

            apt_dt = datetime.datetime.fromisoformat(appt.appointment_time)
            end_dt = apt_dt + datetime.timedelta(minutes=duration)

            # Vaqt to'qnashuvini tekshirish
            await cur.execute(
                """SELECT id FROM appointments 
                   WHERE barber_id=%s AND status NOT IN ('cancelled')
                   AND appointment_time < %s AND end_time > %s""",
                (appt.barber_id, end_dt.strftime('%Y-%m-%d %H:%M:%S'),
                 apt_dt.strftime('%Y-%m-%d %H:%M:%S'))
            )
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Bu vaqt band! Boshqa vaqt tanlang.")

            await cur.execute(
                """INSERT INTO appointments (customer_id, barber_id, service_id, appointment_time, end_time,
                   service_name, price, status, notes)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,'pending',%s)""",
                (appt.customer_id, appt.barber_id, appt.service_id, appt.appointment_time,
                 end_dt.strftime('%Y-%m-%d %H:%M:%S'), appt.service_name, appt.price, appt.notes)
            )
            appt_id = cur.lastrowid

            await cur.execute("SELECT full_name FROM users WHERE id=%s", (appt.customer_id,))
            customer = await cur.fetchone()

            await cur.execute(
                "SELECT u.id FROM users u JOIN barbers b ON u.id=b.user_id WHERE b.id=%s",
                (appt.barber_id,)
            )
            barber_user = await cur.fetchone()

            if barber_user:
                cust_name = customer['full_name'] if customer else 'Mijoz'
                await cur.execute(
                    "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'appointment')",
                    (barber_user['id'], "Yangi navbat!",
                     f"{cust_name} navbat oldi: {appt.service_name} — {apt_dt.strftime('%d.%m %H:%M')}")
                )

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
            await cur.execute(
                """SELECT a.*, b.name as barber_name, b.district, b.phone as barber_phone,
                          b.avatar_url as barber_avatar, b.lat as barber_lat, b.lng as barber_lng,
                          r.rating as my_rating
                   FROM appointments a
                   JOIN barbers b ON a.barber_id = b.id
                   LEFT JOIN reviews r ON r.appointment_id = a.id AND r.customer_id = a.customer_id
                   WHERE a.customer_id=%s ORDER BY a.appointment_time DESC""",
                (customer_id,)
            )
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                for k in ['appointment_time', 'end_time', 'created_at']:
                    if d.get(k) and hasattr(d[k], 'isoformat'):
                        d[k] = d[k].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

@app.get("/barber_appointments/{barber_id}")
async def get_barber_appointments(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                """SELECT a.*, u.full_name as customer_name, u.phone as customer_phone
                   FROM appointments a
                   JOIN users u ON a.customer_id = u.id
                   WHERE a.barber_id=%s ORDER BY a.appointment_time DESC""",
                (barber_id,)
            )
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                for k in ['appointment_time', 'end_time', 'created_at']:
                    if d.get(k) and hasattr(d[k], 'isoformat'):
                        d[k] = d[k].isoformat()
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

            await cur.execute(
                """SELECT a.customer_id, a.service_name, b.name as barber_name
                   FROM appointments a JOIN barbers b ON a.barber_id=b.id WHERE a.id=%s""",
                (app_id,)
            )
            appt = await cur.fetchone()
            if appt:
                msgs = {
                    'confirmed': ("Navbat tasdiqlandi", f"{appt['barber_name']} navbatingizni tasdiqladi"),
                    'completed': ("Xizmat yakunlandi", f"{appt['service_name']} xizmati muvaffaqiyatli yakunlandi"),
                    'cancelled': ("Navbat bekor qilindi", f"{appt['barber_name']} navbatingizni bekor qildi"),
                }
                if status in msgs:
                    title, body = msgs[status]
                    await cur.execute(
                        "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'appointment')",
                        (appt['customer_id'], title, body)
                    )
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

@app.put("/cancel_appointment/{app_id}")
async def cancel_appointment(app_id: int, customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "UPDATE appointments SET status='cancelled' WHERE id=%s AND customer_id=%s AND status='pending'",
                (app_id, customer_id)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=400, detail="Bekor qilib bo'lmadi")
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)

# =====================================================
# REVIEWS
# =====================================================

@app.post("/add_review")
async def add_review(review: ReviewCreate):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id FROM reviews WHERE appointment_id=%s AND customer_id=%s",
                (review.appointment_id, review.customer_id)
            )
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Allaqachon baholangansiz")

            await cur.execute(
                """INSERT INTO reviews (appointment_id, customer_id, barber_id, rating, comment)
                   VALUES (%s,%s,%s,%s,%s)""",
                (review.appointment_id, review.customer_id, review.barber_id, review.rating, review.comment)
            )

            await cur.execute(
                "SELECT AVG(rating) as avg_r, COUNT(*) as cnt FROM reviews WHERE barber_id=%s",
                (review.barber_id,)
            )
            stats = await cur.fetchone()
            if stats and stats[0]:
                await cur.execute(
                    "UPDATE barbers SET rating=%s, total_reviews=%s WHERE id=%s",
                    (round(float(stats[0]), 1), stats[1], review.barber_id)
                )
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
            await cur.execute(
                """SELECT r.*, u.full_name as customer_name
                   FROM reviews r JOIN users u ON r.customer_id=u.id
                   WHERE r.barber_id=%s ORDER BY r.created_at DESC LIMIT %s""",
                (barber_id, limit)
            )
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'):
                    d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

# =====================================================
# PAYMENTS
# =====================================================

@app.post("/create_payment")
async def create_payment(payment: PaymentCreate):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, price, customer_id, payment_status FROM appointments WHERE id=%s",
                (payment.appointment_id,)
            )
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")

            await cur.execute(
                "INSERT INTO payments (appointment_id, amount, method, status) VALUES (%s,%s,%s,'pending')",
                (payment.appointment_id, payment.amount, payment.method)
            )
            payment_id = cur.lastrowid

            if payment.method in ['click', 'payme']:
                transaction_id = f"{payment.method.upper()}-{payment_id}-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
                await cur.execute(
                    "UPDATE payments SET status='completed', transaction_id=%s WHERE id=%s",
                    (transaction_id, payment_id)
                )
            else:
                await cur.execute(
                    "UPDATE payments SET status='completed' WHERE id=%s", (payment_id,)
                )

            await cur.execute(
                "UPDATE appointments SET payment_status='paid', payment_method=%s WHERE id=%s",
                (payment.method, payment.appointment_id)
            )

            points = int(payment.amount // 50000)
            if points > 0:
                await cur.execute(
                    "UPDATE users SET loyalty_points = loyalty_points + %s WHERE id=%s",
                    (points, appt['customer_id'])
                )

            await cur.execute(
                """SELECT u.id FROM users u JOIN barbers b ON u.id=b.user_id
                   JOIN appointments a ON b.id=a.barber_id WHERE a.id=%s""",
                (payment.appointment_id,)
            )
            barber_user = await cur.fetchone()
            if barber_user:
                amount_str = f"{int(payment.amount):,} so'm".replace(',', ' ')
                await cur.execute(
                    "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'payment')",
                    (barber_user['id'], "To'lov qabul qilindi!",
                     f"{amount_str} miqdorida {payment.method.upper()} orqali to'lov amalga oshirildi")
                )

            await conn.commit()

            await cur.execute("SELECT loyalty_points FROM users WHERE id=%s", (appt['customer_id'],))
            user_data = await cur.fetchone()

            return {
                "status": "success",
                "payment_id": payment_id,
                "loyalty_points_earned": points,
                "total_loyalty_points": user_data['loyalty_points'] if user_data else 0
            }

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
            await cur.execute(
                """SELECT p.*, a.service_name, b.name as barber_name
                   FROM payments p
                   JOIN appointments a ON p.appointment_id = a.id
                   JOIN barbers b ON a.barber_id = b.id
                   WHERE a.customer_id=%s AND p.status='completed'
                   ORDER BY p.created_at DESC""",
                (customer_id,)
            )
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'):
                    d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)

# =====================================================
# STATISTICS
# =====================================================

@app.get("/barber_stats/{barber_id}")
async def get_barber_stats(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            today = datetime.date.today()
            month_start = today.replace(day=1)

            await cur.execute(
                "SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND DATE(appointment_time)=%s AND status!='cancelled'",
                (barber_id, today)
            )
            today_count = (await cur.fetchone())['cnt']

            await cur.execute(
                "SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND status='completed'",
                (barber_id,)
            )
            total_completed = (await cur.fetchone())['cnt']

            await cur.execute(
                "SELECT COALESCE(SUM(p.amount),0) as rev FROM payments p JOIN appointments a ON p.appointment_id=a.id WHERE a.barber_id=%s AND p.status='completed'",
                (barber_id,)
            )
            revenue = float((await cur.fetchone())['rev'])

            await cur.execute(
                """SELECT COALESCE(SUM(p.amount),0) as rev FROM payments p
                   JOIN appointments a ON p.appointment_id=a.id
                   WHERE a.barber_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s""",
                (barber_id, month_start)
            )
            monthly_revenue = float((await cur.fetchone())['rev'])

            await cur.execute(
                "SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND status='pending'",
                (barber_id,)
            )
            pending_count = (await cur.fetchone())['cnt']

            await cur.execute(
                "SELECT COALESCE(AVG(rating),5.0) as avg_r, COUNT(*) as cnt FROM reviews WHERE barber_id=%s",
                (barber_id,)
            )
            review_stats = await cur.fetchone()

            return {
                "today_count": today_count,
                "total_completed": total_completed,
                "revenue": revenue,
                "monthly_revenue": monthly_revenue,
                "pending_count": pending_count,
                "avg_rating": round(float(review_stats['avg_r']), 1),
                "total_reviews": review_stats['cnt']
            }
    except Exception:
        return {
            "today_count": 0, "total_completed": 0, "revenue": 0,
            "monthly_revenue": 0, "pending_count": 0, "avg_rating": 5.0, "total_reviews": 0
        }
    finally:
        await release_conn(conn)

# =====================================================
# NOTIFICATIONS
# =====================================================

@app.get("/notifications/{user_id}")
async def get_notifications(user_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM notifications WHERE user_id=%s ORDER BY created_at DESC LIMIT 50",
                (user_id,)
            )
            result = await cur.fetchall()

            await cur.execute(
                "SELECT COUNT(*) as cnt FROM notifications WHERE user_id=%s AND is_read=0",
                (user_id,)
            )
            unread = (await cur.fetchone())['cnt']

            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'):
                    d['created_at'] = d['created_at'].isoformat()
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

# =====================================================
# FAVORITES
# =====================================================

@app.post("/toggle_favorite")
async def toggle_favorite(customer_id: int, barber_id: int):
    """Sevimliga qo'shish/o'chirish"""
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id FROM favorites WHERE customer_id=%s AND barber_id=%s",
                (customer_id, barber_id)
            )
            existing = await cur.fetchone()
            if existing:
                await cur.execute(
                    "DELETE FROM favorites WHERE customer_id=%s AND barber_id=%s",
                    (customer_id, barber_id)
                )
                await conn.commit()
                return {"status": "success", "is_favorite": False}
            else:
                try:
                    await cur.execute(
                        "INSERT INTO favorites (customer_id, barber_id) VALUES (%s,%s)",
                        (customer_id, barber_id)
                    )
                    await conn.commit()
                    return {"status": "success", "is_favorite": True}
                except Exception:
                    # Duplicate bo'lsa — o'chiramiz (toggle logic)
                    await conn.rollback()
                    await cur.execute(
                        "DELETE FROM favorites WHERE customer_id=%s AND barber_id=%s",
                        (customer_id, barber_id)
                    )
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
            await cur.execute(
                """SELECT b.id, b.name, b.district, b.rating, b.specialization,
                          b.is_online, b.avatar_url, b.lat, b.lng, b.total_reviews
                   FROM favorites f JOIN barbers b ON f.barber_id=b.id
                   WHERE f.customer_id=%s ORDER BY f.created_at DESC""",
                (customer_id,)
            )
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)

# =====================================================
# BLOCKED SLOTS
# =====================================================

@app.post("/block_slot")
async def block_slot(slot: BlockedSlot):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO barber_blocked_slots (barber_id, blocked_date, start_time, end_time, reason) VALUES (%s,%s,%s,%s,%s)",
                (slot.barber_id, slot.blocked_date, slot.start_time, slot.end_time, slot.reason)
            )
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)

@app.get("/blocked_slots/{barber_id}")
async def get_blocked_slots(barber_id: int, date: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM barber_blocked_slots WHERE barber_id=%s AND blocked_date=%s",
                (barber_id, date)
            )
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)

# =====================================================
# HEALTH CHECK & ROOT
# =====================================================

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

# =====================================================
# RUN
# =====================================================

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
