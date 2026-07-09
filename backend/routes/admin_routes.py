# =====================================================
# ADMIN ROUTES — verification, barber status
# =====================================================

import aiomysql
from fastapi import APIRouter, HTTPException, Header

from config import ADMIN_KEY
from database import get_conn, release_conn

router = APIRouter()


def _check_admin(x_admin_key: str | None):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="Admin huquqi talab qilinadi")


@router.get("/barber_status/{barber_id}")
async def get_barber_status(barber_id: int):
    """Sartaroshning tasdiqlash holatini qaytaradi."""
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


@router.get("/admin/pending_barbers")
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


@router.put("/admin/verify_barber/{barber_id}")
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
                await cur.execute(
                    "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')",
                    (b["user_id"], title, body),
                )
            await conn.commit()
            return {"status": "success", "verification_status": new_status}
    finally:
        await release_conn(conn)
