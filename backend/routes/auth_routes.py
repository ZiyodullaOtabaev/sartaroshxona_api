# =====================================================
# AUTH ROUTES — register, login, verify, forgot/reset password, token refresh
# =====================================================

import os
import re
import uuid
import shutil
import datetime

import aiomysql
from fastapi import APIRouter, HTTPException, UploadFile, File, Request

from config import (
    SERVER_BASE_URL, OTP_EXPIRY_MINUTES, OTP_MAX_ATTEMPTS,
    PASSWORD_MIN_LENGTH, LOGIN_MAX_ATTEMPTS, LOGIN_BLOCK_MINUTES,
)
from database import get_conn, release_conn, timedelta_to_str
from auth import hash_password, create_access_token, verify_token, pwd_context
from models import (
    UserRegister, UserLogin, ChangePassword,
    VerifyEmail, ForgotPassword, ResetPassword, TokenRefresh,
)
from services.email_service import generate_otp, send_verification_email, send_password_reset_email

router = APIRouter()


# ─── HELPERS ─────────────────────────────────────────────────────────────────

def _validate_password(password: str) -> str | None:
    """Parol kuchliligini tekshirish. Xatolik bo'lsa xabar qaytaradi, bo'lmasa None."""
    if len(password) < PASSWORD_MIN_LENGTH:
        return f"Parol kamida {PASSWORD_MIN_LENGTH} belgidan iborat bo'lishi kerak"
    if not re.search(r'[a-zA-Z]', password):
        return "Parolda kamida 1 ta harf bo'lishi kerak"
    if not re.search(r'\d', password):
        return "Parolda kamida 1 ta raqam bo'lishi kerak"
    return None


def _get_client_ip(request: Request) -> str:
    """Klient IP manzilini olish."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTER + EMAIL VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/register")
async def register(user: UserRegister):
    # Parol kuchliligini tekshirish
    pwd_error = _validate_password(user.password)
    if pwd_error:
        raise HTTPException(status_code=400, detail=pwd_error)

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id FROM users WHERE email=%s", (user.email,))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Email already exists")

            hashed_password = hash_password(user.password)
            await cur.execute(
                "INSERT INTO users (full_name, email, email_verified, password_hash, role, phone) "
                "VALUES (%s,%s,FALSE,%s,%s,%s)",
                (user.full_name, user.email, hashed_password, user.role, user.phone),
            )
            user_id = cur.lastrowid
            barber_id = None
            salon_id = None

            if user.role == "barber":
                await cur.execute(
                    "INSERT INTO barbers (user_id, name, experience, phone, specialization, bio, lat, lng, "
                    "rating, total_reviews, district) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,5.0,0,'Toshkent')",
                    (user_id, user.full_name, user.experience or "", user.phone,
                     user.specialization or "", user.bio or "", user.lat, user.lng),
                )
                barber_id = cur.lastrowid
                for day in range(1, 7):
                    await cur.execute(
                        "INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,1)",
                        (barber_id, day),
                    )
            elif user.role == "owner":
                salon_name = user.salon_name or f"{user.full_name} sartaroshxonasi"
                await cur.execute(
                    "INSERT INTO salons (owner_id, name, address, phone, lat, lng, description) "
                    "VALUES (%s,%s,%s,%s,%s,%s,%s)",
                    (user_id, salon_name, user.salon_address or "", user.phone,
                     user.lat, user.lng, user.bio or ""),
                )
                salon_id = cur.lastrowid
                if user.also_barber:
                    await cur.execute(
                        "INSERT INTO barbers (user_id, salon_id, name, experience, phone, specialization, bio, "
                        "lat, lng, rating, total_reviews, district, verification_status) "
                        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,5.0,0,'Toshkent','approved')",
                        (user_id, salon_id, user.full_name, user.experience or "", user.phone,
                         user.specialization or "", user.bio or "", user.lat, user.lng),
                    )
                    barber_id = cur.lastrowid
                    for day in range(1, 7):
                        await cur.execute(
                            "INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,1)",
                            (barber_id, day),
                        )

            # Email OTP yaratish va yuborish
            otp_code = generate_otp()
            expires_at = datetime.datetime.now() + datetime.timedelta(minutes=OTP_EXPIRY_MINUTES)
            await cur.execute(
                "INSERT INTO email_verifications (user_id, email, code, expires_at) VALUES (%s,%s,%s,%s)",
                (user_id, user.email, otp_code, expires_at),
            )

            await conn.commit()

            # Email yuborish (async, xatolik bo'lsa skip)
            await send_verification_email(user.email, otp_code, user.full_name)

            token = create_access_token({"user_id": user_id, "role": user.role, "email": user.email})
            verification = None
            if user.role == "barber":
                verification = "pending"
            elif user.role == "owner" and user.also_barber:
                verification = "approved"

            return {
                "status": "success",
                "user_id": user_id,
                "barber_id": barber_id,
                "salon_id": salon_id,
                "verification_status": verification,
                "email_verified": False,
                "token": token,
                "message": "Tasdiqlash kodi emailingizga yuborildi",
            }
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


@router.post("/verify_email")
async def verify_email(data: VerifyEmail):
    """Email tasdiqlash kodi tekshirish."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, user_id, attempts, expires_at FROM email_verifications "
                "WHERE email=%s AND code=%s AND is_verified=FALSE ORDER BY created_at DESC LIMIT 1",
                (data.email, data.code),
            )
            record = await cur.fetchone()

            if not record:
                # Urinishlar sonini oshirish
                await cur.execute(
                    "UPDATE email_verifications SET attempts=attempts+1 "
                    "WHERE email=%s AND is_verified=FALSE ORDER BY created_at DESC LIMIT 1",
                    (data.email,),
                )
                await conn.commit()
                raise HTTPException(status_code=400, detail="Kod noto'g'ri")

            if record['expires_at'] < datetime.datetime.now():
                raise HTTPException(status_code=410, detail="Kod muddati tugagan. Yangi kod so'rang.")

            if record['attempts'] >= OTP_MAX_ATTEMPTS:
                raise HTTPException(status_code=429, detail="Urinishlar soni tugadi. Yangi kod so'rang.")

            # Tasdiqlash
            await cur.execute("UPDATE email_verifications SET is_verified=TRUE WHERE id=%s", (record['id'],))
            await cur.execute("UPDATE users SET email_verified=TRUE WHERE id=%s", (record['user_id'],))
            await conn.commit()

            return {"status": "success", "message": "Email muvaffaqiyatli tasdiqlandi"}
    finally:
        await release_conn(conn)


@router.post("/resend_verification")
async def resend_verification(email: str):
    """Yangi tasdiqlash kodi yuborish."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, full_name, email_verified FROM users WHERE email=%s", (email,))
            user = await cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")
            if user['email_verified']:
                raise HTTPException(status_code=409, detail="Email allaqachon tasdiqlangan")

            # Eski kodlarni bekor qilish
            await cur.execute(
                "UPDATE email_verifications SET is_verified=TRUE WHERE user_id=%s AND is_verified=FALSE",
                (user['id'],),
            )

            # Yangi kod
            otp_code = generate_otp()
            expires_at = datetime.datetime.now() + datetime.timedelta(minutes=OTP_EXPIRY_MINUTES)
            await cur.execute(
                "INSERT INTO email_verifications (user_id, email, code, expires_at) VALUES (%s,%s,%s,%s)",
                (user['id'], email, otp_code, expires_at),
            )
            await conn.commit()

            await send_verification_email(email, otp_code, user['full_name'])
            return {"status": "success", "message": "Yangi kod emailingizga yuborildi"}
    finally:
        await release_conn(conn)


# ═══════════════════════════════════════════════════════════════════════════════
# LOGIN (rate limiting bilan)
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/login")
async def login(user: UserLogin, request: Request):
    client_ip = _get_client_ip(request)
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # Rate limiting tekshirish
            block_since = datetime.datetime.now() - datetime.timedelta(minutes=LOGIN_BLOCK_MINUTES)
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM login_attempts "
                "WHERE email=%s AND is_success=FALSE AND created_at > %s",
                (user.email, block_since),
            )
            failed_count = (await cur.fetchone())['cnt']
            if failed_count >= LOGIN_MAX_ATTEMPTS:
                raise HTTPException(
                    status_code=429,
                    detail=f"Juda ko'p urinish. {LOGIN_BLOCK_MINUTES} daqiqadan keyin qayta urinib ko'ring.",
                )

            # Login
            await cur.execute(
                "SELECT u.id, u.full_name, u.email, u.password_hash, u.role, u.phone, "
                "u.loyalty_points, u.email_verified, "
                "b.id as barber_id, b.salon_id as barber_salon_id, b.is_online, b.rating, "
                "b.specialization, b.bio, b.avatar_url, b.working_hours_start, "
                "b.working_hours_end, b.verification_status, "
                "s.id as owned_salon_id, s.name as salon_name "
                "FROM users u LEFT JOIN barbers b ON u.id = b.user_id "
                "LEFT JOIN salons s ON u.id = s.owner_id WHERE u.email=%s OR u.phone=%s",
                (user.email, user.email),
            )
            db_user = await cur.fetchone()

            if not db_user or not pwd_context.verify(user.password, db_user["password_hash"]):
                # Muvaffaqiyatsiz urinishni yozish
                await cur.execute(
                    "INSERT INTO login_attempts (email, ip_address, is_success) VALUES (%s,%s,FALSE)",
                    (user.email, client_ip),
                )
                await conn.commit()
                remaining = LOGIN_MAX_ATTEMPTS - failed_count - 1
                detail = "Email yoki parol noto'g'ri"
                if 0 < remaining <= 2:
                    detail += f" ({remaining} ta urinish qoldi)"
                raise HTTPException(status_code=401, detail=detail)

            # Muvaffaqiyatli login yozish
            await cur.execute(
                "INSERT INTO login_attempts (email, ip_address, is_success) VALUES (%s,%s,TRUE)",
                (user.email, client_ip),
            )
            await conn.commit()

            db_user.pop("password_hash", None)
            token = create_access_token({
                "user_id": db_user["id"], "role": db_user["role"], "email": db_user["email"],
            })
            if db_user.get("working_hours_start"):
                db_user["working_hours_start"] = timedelta_to_str(db_user["working_hours_start"])
            if db_user.get("working_hours_end"):
                db_user["working_hours_end"] = timedelta_to_str(db_user["working_hours_end"])

            return {"status": "success", "token": token, "user": db_user}
    finally:
        await release_conn(conn)


# ═══════════════════════════════════════════════════════════════════════════════
# FORGOT / RESET PASSWORD
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/forgot_password")
async def forgot_password(data: ForgotPassword):
    """Parolni tiklash uchun emailga kod yuborish."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, full_name FROM users WHERE email=%s", (data.email,))
            user = await cur.fetchone()
            if not user:
                # Xavfsizlik: email mavjud emasligini bildirmaslik
                return {"status": "success", "message": "Agar email ro'yxatdan o'tgan bo'lsa, kod yuborildi"}

            # Eski kodlarni bekor qilish
            await cur.execute(
                "UPDATE password_resets SET is_used=TRUE WHERE user_id=%s AND is_used=FALSE",
                (user['id'],),
            )

            # Yangi kod
            otp_code = generate_otp()
            expires_at = datetime.datetime.now() + datetime.timedelta(minutes=OTP_EXPIRY_MINUTES)
            await cur.execute(
                "INSERT INTO password_resets (user_id, email, code, expires_at) VALUES (%s,%s,%s,%s)",
                (user['id'], data.email, otp_code, expires_at),
            )
            await conn.commit()

            await send_password_reset_email(data.email, otp_code, user['full_name'])
            return {"status": "success", "message": "Agar email ro'yxatdan o'tgan bo'lsa, kod yuborildi"}
    finally:
        await release_conn(conn)


@router.post("/reset_password")
async def reset_password(data: ResetPassword):
    """Kod bilan parolni tiklash."""
    # Yangi parol kuchliligini tekshirish
    pwd_error = _validate_password(data.new_password)
    if pwd_error:
        raise HTTPException(status_code=400, detail=pwd_error)

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, user_id, attempts, expires_at FROM password_resets "
                "WHERE email=%s AND code=%s AND is_used=FALSE ORDER BY created_at DESC LIMIT 1",
                (data.email, data.code),
            )
            record = await cur.fetchone()

            if not record:
                await cur.execute(
                    "UPDATE password_resets SET attempts=attempts+1 "
                    "WHERE email=%s AND is_used=FALSE ORDER BY created_at DESC LIMIT 1",
                    (data.email,),
                )
                await conn.commit()
                raise HTTPException(status_code=400, detail="Kod noto'g'ri")

            if record['expires_at'] < datetime.datetime.now():
                raise HTTPException(status_code=410, detail="Kod muddati tugagan")

            if record['attempts'] >= OTP_MAX_ATTEMPTS:
                raise HTTPException(status_code=429, detail="Urinishlar soni tugadi")

            # Parolni yangilash
            new_hash = hash_password(data.new_password)
            await cur.execute("UPDATE users SET password_hash=%s WHERE id=%s", (new_hash, record['user_id']))
            await cur.execute("UPDATE password_resets SET is_used=TRUE WHERE id=%s", (record['id'],))
            await conn.commit()

            return {"status": "success", "message": "Parol muvaffaqiyatli yangilandi"}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN REFRESH
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/refresh_token")
async def refresh_token(data: TokenRefresh):
    """Token muddati yaqinlashganda yangilash."""
    try:
        payload = verify_token(data.token)
        # Yangi token yaratish (eski ma'lumotlar bilan)
        new_token = create_access_token({
            "user_id": payload["user_id"],
            "role": payload["role"],
            "email": payload["email"],
        })
        return {"status": "success", "token": new_token}
    except HTTPException:
        raise


# ═══════════════════════════════════════════════════════════════════════════════
# CHANGE PASSWORD (yangilangan — kuchlilik tekshiruvi bilan)
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/change_password")
async def change_password(data: ChangePassword):
    """Foydalanuvchi parolini o'zgartirish (eski parolni tekshirib)."""
    pwd_error = _validate_password(data.new_password)
    if pwd_error:
        raise HTTPException(status_code=400, detail=pwd_error)

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


# ═══════════════════════════════════════════════════════════════════════════════
# UPLOAD AVATAR
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/upload_avatar/{barber_id}")
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
