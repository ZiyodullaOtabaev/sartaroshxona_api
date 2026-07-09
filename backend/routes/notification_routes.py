# =====================================================
# NOTIFICATION ROUTES — FCM token register, push yuborish
# =====================================================

import aiomysql
from fastapi import APIRouter, HTTPException

from config import FIREBASE_ENABLED, FIREBASE_CREDENTIALS_PATH
from database import get_conn, release_conn
from models import DeviceRegister

router = APIRouter()

# ─── FIREBASE INIT ───────────────────────────────────────────────────────────

_firebase_app = None

def _init_firebase():
    """Firebase Admin SDK'ni lazy init qilish."""
    global _firebase_app
    if _firebase_app is not None:
        return True
    if not FIREBASE_ENABLED:
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
        print("[Firebase] Muvaffaqiyatli ulandi")
        return True
    except Exception as e:
        print(f"[Firebase] Init xatolik: {e}")
        return False


# ─── PUSH YUBORISH HELPER ────────────────────────────────────────────────────

async def send_push_to_user(user_id: int, title: str, body: str, data: dict = None):
    """Foydalanuvchining barcha qurilmalariga push notification yuborish."""
    if not _init_firebase():
        return  # Firebase sozlanmagan — skip

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT fcm_token FROM user_devices WHERE user_id=%s AND is_active=1",
                (user_id,),
            )
            devices = await cur.fetchall()
            if not devices:
                return

            from firebase_admin import messaging

            tokens = [d["fcm_token"] for d in devices]
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data=data or {},
                tokens=tokens,
            )

            try:
                response = messaging.send_each_for_multicast(message)
                # Invalid token'larni deactivate qilish
                for i, send_response in enumerate(response.responses):
                    if not send_response.success:
                        error = send_response.exception
                        if error and hasattr(error, 'code'):
                            error_code = error.code
                            if error_code in ('NOT_FOUND', 'UNREGISTERED', 'INVALID_ARGUMENT'):
                                await cur.execute(
                                    "UPDATE user_devices SET is_active=0 WHERE fcm_token=%s",
                                    (tokens[i],),
                                )
                if response.failure_count > 0:
                    await conn.commit()
            except Exception as e:
                print(f"[Push] Yuborish xatolik: {e}")
    except Exception as e:
        print(f"[Push] DB xatolik: {e}")
    finally:
        await release_conn(conn)


async def send_push_to_users(user_ids: list, title: str, body: str, data: dict = None):
    """Bir nechta foydalanuvchiga push yuborish."""
    for uid in user_ids:
        await send_push_to_user(uid, title, body, data)


# ─── FCM TOKEN ENDPOINTS ─────────────────────────────────────────────────────

@router.post("/device/register")
async def register_device(data: DeviceRegister):
    """FCM tokenni saqlash (ilova ochilganda chaqiriladi)."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # UPSERT — token mavjud bo'lsa yangilash, yo'q bo'lsa qo'shish
            await cur.execute(
                "INSERT INTO user_devices (user_id, fcm_token, device_type) VALUES (%s,%s,%s) "
                "ON DUPLICATE KEY UPDATE user_id=%s, device_type=%s, is_active=1, updated_at=NOW()",
                (data.user_id, data.fcm_token, data.device_type, data.user_id, data.device_type),
            )
            await conn.commit()
            return {"status": "success"}
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


@router.post("/device/unregister")
async def unregister_device(user_id: int, fcm_token: str):
    """FCM tokenni deactivate qilish (logout yoki ilova o'chirilganda)."""
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "UPDATE user_devices SET is_active=0 WHERE user_id=%s AND fcm_token=%s",
                (user_id, fcm_token),
            )
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)


@router.post("/push/send")
async def send_push(user_id: int, title: str, body: str):
    """Test uchun — admin push yuborish."""
    await send_push_to_user(user_id, title, body)
    return {"status": "sent"}


# ─── REMINDER ENDPOINTS ──────────────────────────────────────────────────────

@router.get("/reminders/check")
async def check_reminders():
    """Cron job tomonidan chaqiriladi — ertangi navbatlar, 30 kun o'tganlar uchun push."""
    import datetime
    conn = await get_conn()
    sent_count = 0
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            now = datetime.datetime.now()
            tomorrow = (now + datetime.timedelta(days=1)).date()

            # 1. Ertangi navbatlar uchun reminder
            await cur.execute(
                "SELECT a.customer_id, a.appointment_time, a.service_name, b.name as barber_name "
                "FROM appointments a JOIN barbers b ON a.barber_id=b.id "
                "WHERE DATE(a.appointment_time)=%s AND a.status IN ('pending','confirmed')",
                (tomorrow,),
            )
            for appt in await cur.fetchall():
                apt_time = appt["appointment_time"]
                time_str = apt_time.strftime("%H:%M") if hasattr(apt_time, "strftime") else str(apt_time)
                await send_push_to_user(
                    appt["customer_id"],
                    "Ertaga navbatingiz bor!",
                    f"Soat {time_str} — {appt['barber_name']} ({appt['service_name']})",
                    {"type": "appointment_reminder"},
                )
                sent_count += 1

            # 2. 30 kun oldin oxirgi navbat bo'lganlar (nudge)
            thirty_days_ago = (now - datetime.timedelta(days=30)).date()
            await cur.execute(
                "SELECT a.customer_id, MAX(a.appointment_time) as last_appt "
                "FROM appointments a WHERE a.status='completed' "
                "GROUP BY a.customer_id "
                "HAVING DATE(MAX(a.appointment_time)) = %s",
                (thirty_days_ago,),
            )
            for row in await cur.fetchall():
                await send_push_to_user(
                    row["customer_id"],
                    "Soch qirqtirganingizga 30 kun bo'ldi!",
                    "Uslubingizni yangilash vaqti keldi. Yangi navbat olasizmi?",
                    {"type": "nudge_30_days"},
                )
                sent_count += 1

        return {"status": "success", "reminders_sent": sent_count}
    finally:
        await release_conn(conn)
