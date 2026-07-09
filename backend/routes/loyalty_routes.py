# =====================================================
# LOYALTY ROUTES — 10 navbat = 1 bepul tizimi
# =====================================================

import datetime
import secrets
import string

import aiomysql
from fastapi import APIRouter, HTTPException

from config import (
    LOYALTY_STAMPS_FOR_REWARD,
    LOYALTY_STAMP_EXPIRY_DAYS,
    LOYALTY_REWARD_EXPIRY_DAYS,
    LOYALTY_REWARD_MAX_VALUE,
)
from database import get_conn, release_conn
from models import RedeemReward

router = APIRouter()


def _generate_reward_code() -> str:
    """Unique 8-belgili reward kodi yaratish."""
    chars = string.ascii_uppercase + string.digits
    return "FREE-" + "".join(secrets.choice(chars) for _ in range(6))


# ─── STAMP BERISH (navbat yakunlanganda chaqiriladi) ─────────────────────────

async def award_loyalty_stamp(customer_id: int, appointment_id: int):
    """Navbat yakunlanganda avtomatik stamp berish. Internal funksiya."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # Dublikat tekshirish
            await cur.execute(
                "SELECT id FROM loyalty_stamps WHERE appointment_id=%s AND customer_id=%s",
                (appointment_id, customer_id),
            )
            if await cur.fetchone():
                return  # Allaqachon berilgan

            expires_at = datetime.datetime.now() + datetime.timedelta(days=LOYALTY_STAMP_EXPIRY_DAYS)
            await cur.execute(
                "INSERT INTO loyalty_stamps (customer_id, appointment_id, expires_at) VALUES (%s,%s,%s)",
                (customer_id, appointment_id, expires_at),
            )

            # Aktiv (muddati o'tmagan, ishlatilmagan) stamplar sonini tekshirish
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM loyalty_stamps "
                "WHERE customer_id=%s AND is_used=0 AND expires_at > NOW()",
                (customer_id,),
            )
            count = (await cur.fetchone())["cnt"]

            # 10 ta yig'ildimi?
            if count >= LOYALTY_STAMPS_FOR_REWARD:
                # Eng eski 10 ta stampni ishlatilgan deb belgilash
                await cur.execute(
                    "SELECT id FROM loyalty_stamps "
                    "WHERE customer_id=%s AND is_used=0 AND expires_at > NOW() "
                    "ORDER BY earned_at ASC LIMIT %s",
                    (customer_id, LOYALTY_STAMPS_FOR_REWARD),
                )
                stamp_ids = [r["id"] for r in await cur.fetchall()]
                if len(stamp_ids) >= LOYALTY_STAMPS_FOR_REWARD:
                    fmt = ",".join(["%s"] * len(stamp_ids))
                    await cur.execute(
                        f"UPDATE loyalty_stamps SET is_used=1 WHERE id IN ({fmt})",
                        stamp_ids,
                    )
                    # Reward yaratish
                    reward_code = _generate_reward_code()
                    reward_expires = datetime.datetime.now() + datetime.timedelta(days=LOYALTY_REWARD_EXPIRY_DAYS)
                    await cur.execute(
                        "INSERT INTO loyalty_rewards (customer_id, reward_code, max_value, expires_at) "
                        "VALUES (%s,%s,%s,%s)",
                        (customer_id, reward_code, LOYALTY_REWARD_MAX_VALUE, reward_expires),
                    )
                    # Bildirishnoma
                    await cur.execute(
                        "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'promotion')",
                        (customer_id, "Tabriklaymiz! Bepul navbat!",
                         f"10 ta navbat yig'dingiz! Kodingiz: {reward_code}. 30 kun ichida ishlating."),
                    )

            await conn.commit()
    except Exception as e:
        try:
            await conn.rollback()
        except Exception:
            pass
        print(f"[Loyalty] Stamp berish xatolik: {e}")
    finally:
        await release_conn(conn)


# ─── MIJOZ UCHUN ENDPOINTLAR ─────────────────────────────────────────────────

@router.get("/loyalty/status/{customer_id}")
async def get_loyalty_status(customer_id: int):
    """Mijozning loyalty holati — stamplar, rewardlar."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # Aktiv stamplar soni
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM loyalty_stamps "
                "WHERE customer_id=%s AND is_used=0 AND expires_at > NOW()",
                (customer_id,),
            )
            active_stamps = (await cur.fetchone())["cnt"]

            # Jami yig'ilgan stamplar
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM loyalty_stamps WHERE customer_id=%s",
                (customer_id,),
            )
            total_stamps = (await cur.fetchone())["cnt"]

            # Aktiv (ishlatilmagan) rewardlar
            await cur.execute(
                "SELECT reward_code, max_value, expires_at FROM loyalty_rewards "
                "WHERE customer_id=%s AND is_redeemed=0 AND expires_at > NOW() "
                "ORDER BY created_at DESC",
                (customer_id,),
            )
            rewards = []
            for r in await cur.fetchall():
                d = dict(r)
                if d.get("expires_at") and hasattr(d["expires_at"], "isoformat"):
                    d["expires_at"] = d["expires_at"].isoformat()
                rewards.append(d)

            # Eng yaqin stamp muddati
            await cur.execute(
                "SELECT MIN(expires_at) as nearest FROM loyalty_stamps "
                "WHERE customer_id=%s AND is_used=0 AND expires_at > NOW()",
                (customer_id,),
            )
            nearest = await cur.fetchone()
            nearest_expiry = None
            if nearest and nearest["nearest"]:
                nearest_expiry = nearest["nearest"].isoformat() if hasattr(nearest["nearest"], "isoformat") else str(nearest["nearest"])

            return {
                "active_stamps": active_stamps,
                "stamps_needed": LOYALTY_STAMPS_FOR_REWARD,
                "remaining": max(0, LOYALTY_STAMPS_FOR_REWARD - active_stamps),
                "total_stamps_earned": total_stamps,
                "available_rewards": rewards,
                "nearest_stamp_expiry": nearest_expiry,
                "message": f"{active_stamps}/{LOYALTY_STAMPS_FOR_REWARD} — "
                           + (f"Yana {LOYALTY_STAMPS_FOR_REWARD - active_stamps} ta navbat!" if active_stamps < LOYALTY_STAMPS_FOR_REWARD
                              else "Bepul navbat tayyor!"),
            }
    finally:
        await release_conn(conn)


@router.post("/loyalty/redeem")
async def redeem_reward(data: RedeemReward):
    """Bepul navbat kodini ishlatish — navbat narxidan chegirma."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # Reward tekshirish
            await cur.execute(
                "SELECT id, max_value, is_redeemed, expires_at FROM loyalty_rewards "
                "WHERE reward_code=%s AND customer_id=%s",
                (data.reward_code, data.customer_id),
            )
            reward = await cur.fetchone()
            if not reward:
                raise HTTPException(status_code=404, detail="Kod topilmadi")
            if reward["is_redeemed"]:
                raise HTTPException(status_code=409, detail="Bu kod allaqachon ishlatilgan")
            if reward["expires_at"] < datetime.datetime.now():
                raise HTTPException(status_code=410, detail="Kod muddati tugagan")

            # Navbat tekshirish
            await cur.execute(
                "SELECT id, price, payment_status FROM appointments WHERE id=%s AND customer_id=%s",
                (data.appointment_id, data.customer_id),
            )
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt["payment_status"] == "paid":
                raise HTTPException(status_code=409, detail="Bu navbat allaqachon to'langan")

            # Chegirma hisoblash
            price = float(appt["price"] or 0)
            discount = min(price, float(reward["max_value"]))
            new_price = round(price - discount, 2)

            # Reward'ni ishlatilgan deb belgilash
            await cur.execute(
                "UPDATE loyalty_rewards SET is_redeemed=1, redeemed_at=NOW(), redeemed_appointment_id=%s WHERE id=%s",
                (data.appointment_id, reward["id"]),
            )

            # Navbat narxini yangilash
            await cur.execute(
                "UPDATE appointments SET price=%s WHERE id=%s",
                (new_price, data.appointment_id),
            )

            # Agar narx 0 bo'lsa — avtomatik to'langan
            if new_price <= 0:
                await cur.execute(
                    "UPDATE appointments SET payment_status='paid', payment_method='loyalty' WHERE id=%s",
                    (data.appointment_id,),
                )

            await conn.commit()
            return {
                "status": "success",
                "original_price": price,
                "discount": discount,
                "new_price": new_price,
                "fully_covered": new_price <= 0,
                "message": "Bepul navbat muvaffaqiyatli ishlatildi!" if new_price <= 0
                           else f"{int(discount)} so'm chegirma qo'llandi. Qoldiq: {int(new_price)} so'm",
            }
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


@router.get("/loyalty/history/{customer_id}")
async def get_loyalty_history(customer_id: int):
    """Mijozning stamp tarixi."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT ls.id, ls.earned_at, ls.expires_at, ls.is_used, a.service_name, b.name as barber_name "
                "FROM loyalty_stamps ls "
                "JOIN appointments a ON ls.appointment_id = a.id "
                "JOIN barbers b ON a.barber_id = b.id "
                "WHERE ls.customer_id=%s ORDER BY ls.earned_at DESC LIMIT 30",
                (customer_id,),
            )
            stamps = []
            for r in await cur.fetchall():
                d = dict(r)
                for k in ["earned_at", "expires_at"]:
                    if d.get(k) and hasattr(d[k], "isoformat"):
                        d[k] = d[k].isoformat()
                stamps.append(d)
            return {"stamps": stamps}
    finally:
        await release_conn(conn)
