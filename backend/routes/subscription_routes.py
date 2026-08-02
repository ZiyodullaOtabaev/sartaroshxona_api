# =====================================================
# SUBSCRIPTION ROUTES — Obuna va Tariflar API
# =====================================================

import datetime
from fastapi import APIRouter, HTTPException, Depends
import aiomysql
from database import get_conn, release_conn
from auth import get_current_user

router = APIRouter()

PLANS = [
    {
        "key": "trial",
        "name": "Free Trial (30 kun)",
        "price": 0,
        "period": "1 oy",
        "features": [
            "1 oy bepul sinov muddati",
            "50 tagacha navbatlarni qabul qilish",
            "Asosiy ish grafigi va xizmatlar",
        ],
        "is_best": False,
        "is_vip": False,
    },
    {
        "key": "standard_month",
        "name": "Standard Tarif",
        "price": 50000,
        "period": "1 oy",
        "features": [
            "Oyiga 200 tagacha navbatlar",
            "SMS & Push bildirishnomalar",
            "Mijozlar bilan chat va qo'ng'iroq",
            "Ish grafigi va tushlik bloklash",
        ],
        "is_best": False,
        "is_vip": False,
    },
    {
        "key": "vip_month",
        "name": "PRO VIP Tarif",
        "price": 100000,
        "period": "1 oy",
        "features": [
            "Cheksiz (Unlimited) navbatlar",
            "Qidiruv va Xaritada VIP yashil nishon (TOP)",
            "Shaxsiy Soch Stillari Portfolio albomi",
            "Moliyaviy va mijozlar analitikasi",
            "24/7 Premium qo'llab-quvvatlash",
        ],
        "is_best": True,
        "is_vip": True,
    },
    {
        "key": "salon_month",
        "name": "Salon Egasi CRM",
        "price": 200000,
        "period": "1 oy",
        "features": [
            "Salondagi barcha sartaroshlarni boshqarish",
            "Kunlik/Oylik kassa va tushum CRM paneli",
            "Sartaroshlarni taklif qilish va o'chirish",
            "Cheksiz salon statistikasi va hisobotlar",
        ],
        "is_best": False,
        "is_vip": True,
    },
]


@router.get("/subscription/plans")
async def get_subscription_plans():
    """Barcha tariflar va planlar ro'yxati."""
    return PLANS


@router.get("/subscription/status/{user_id}")
async def get_subscription_status(user_id: int):
    """Foydalanuvchining obuna holati."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, role FROM users WHERE id=%s", (user_id,))
            user = await cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")

            tier = "trial"
            expires_at = None
            is_vip = False
            barber_id = None
            salon_id = None

            if user["role"] == "barber":
                await cur.execute(
                    "SELECT id, subscription_tier, subscription_expires_at, is_vip FROM barbers WHERE user_id=%s",
                    (user_id,),
                )
                b = await cur.fetchone()
                if b:
                    barber_id = b["id"]
                    tier = b.get("subscription_tier") or "trial"
                    expires_at = b.get("subscription_expires_at")
                    is_vip = bool(b.get("is_vip", False))
            elif user["role"] == "owner":
                await cur.execute(
                    "SELECT id, subscription_tier, subscription_expires_at FROM salons WHERE owner_id=%s",
                    (user_id,),
                )
                s = await cur.fetchone()
                if s:
                    salon_id = s["id"]
                    tier = s.get("subscription_tier") or "trial"
                    expires_at = s.get("subscription_expires_at")
                    is_vip = True

            days_left = 30
            if expires_at:
                if isinstance(expires_at, datetime.datetime):
                    diff = expires_at - datetime.datetime.now()
                    days_left = max(0, diff.days)

            return {
                "user_id": user_id,
                "barber_id": barber_id,
                "salon_id": salon_id,
                "tier": tier,
                "is_vip": is_vip,
                "expires_at": expires_at.isoformat() if hasattr(expires_at, "isoformat") else str(expires_at),
                "days_left": days_left,
                "is_active": days_left > 0,
            }
    finally:
        await release_conn(conn)


@router.post("/subscription/activate")
async def activate_subscription(
    user_id: int,
    plan_key: str,
    months: int = 1,
    payment_method: str = "payme",
):
    """Obunani faollashtirish yoki uzaytirish."""
    plan = next((p for p in PLANS if p["key"] == plan_key), None)
    if not plan:
        raise HTTPException(status_code=400, detail="Noto'g'ri plan_key")

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, role FROM users WHERE id=%s", (user_id,))
            user = await cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")

            amount = plan["price"] * months
            now = datetime.datetime.now()
            new_expires = now + datetime.timedelta(days=30 * months)

            barber_id = None
            salon_id = None

            if user["role"] == "barber":
                await cur.execute("SELECT id FROM barbers WHERE user_id=%s", (user_id,))
                b = await cur.fetchone()
                if b:
                    barber_id = b["id"]
                    await cur.execute(
                        "UPDATE barbers SET subscription_tier=%s, subscription_expires_at=%s, is_vip=%s WHERE id=%s",
                        (plan_key, new_expires, plan["is_vip"], barber_id),
                    )
            elif user["role"] == "owner":
                await cur.execute("SELECT id FROM salons WHERE owner_id=%s", (user_id,))
                s = await cur.fetchone()
                if s:
                    salon_id = s["id"]
                    await cur.execute(
                        "UPDATE salons SET subscription_tier=%s, subscription_expires_at=%s WHERE id=%s",
                        (plan_key, new_expires, salon_id),
                    )

            await cur.execute(
                "INSERT INTO subscriptions (user_id, barber_id, salon_id, plan_key, amount, months, status, payment_method, expires_at) "
                "VALUES (%s,%s,%s,%s,%s,%s,'active',%s,%s)",
                (user_id, barber_id, salon_id, plan_key, amount, months, payment_method, new_expires),
            )
            await conn.commit()

            return {
                "status": "success",
                "message": f"{plan['name']} muvaffaqiyatli faollashtirildi ({months} oy)",
                "expires_at": new_expires.isoformat(),
            }
    finally:
        await release_conn(conn)
