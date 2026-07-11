# =====================================================
# SALON ROUTES — CRM, salon CRUD, staff, invitations, owner dashboard
# =====================================================

import datetime

import aiomysql
from fastapi import APIRouter, HTTPException, Depends

from database import get_conn, release_conn, timedelta_to_str
from auth import require_owner, require_auth
from models import SalonCreate, SalonUpdate, StaffInvite, JoinRequest, InvitationResponse

router = APIRouter()


# ─── HELPER ──────────────────────────────────────────────────────────────────

async def _get_owner_salon(cur, user_id):
    await cur.execute("SELECT * FROM salons WHERE owner_id=%s", (user_id,))
    salon = await cur.fetchone()
    if not salon:
        raise HTTPException(status_code=404, detail="Sizda sartaroshxona topilmadi")
    return salon


# ─── PUBLIC: Salon ko'rish ───────────────────────────────────────────────────

@router.get("/salons")
async def list_salons(page: int = 1, limit: int = 20):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            offset = (page - 1) * limit
            await cur.execute(
                "SELECT s.id, s.name, s.description, s.address, s.district, s.lat, s.lng, s.phone, "
                "s.avatar_url, s.cover_url, s.rating, s.total_reviews, "
                "(SELECT COUNT(*) FROM barbers WHERE salon_id=s.id) as barbers_count "
                "FROM salons s WHERE s.is_active=1 ORDER BY s.rating DESC LIMIT %s OFFSET %s",
                (limit, offset),
            )
            return [dict(s) for s in await cur.fetchall()]
    finally:
        await release_conn(conn)


@router.get("/salon/{salon_id}")
async def get_salon(salon_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM salons WHERE id=%s AND is_active=1", (salon_id,))
            salon = await cur.fetchone()
            if not salon:
                raise HTTPException(status_code=404, detail="Sartaroshxona topilmadi")
            await cur.execute(
                "SELECT id, name, specialization, rating, total_reviews, avatar_url, is_online, "
                "is_accepting_bookings, experience FROM barbers WHERE salon_id=%s",
                (salon_id,),
            )
            barbers = await cur.fetchall()
            result = dict(salon)
            result['working_hours_start'] = timedelta_to_str(result.get('working_hours_start'))
            result['working_hours_end'] = timedelta_to_str(result.get('working_hours_end'))
            for k in ['created_at', 'updated_at']:
                if result.get(k) and hasattr(result[k], 'isoformat'):
                    result[k] = result[k].isoformat()
            result['barbers'] = [dict(b) for b in barbers]
            result['barbers_count'] = len(barbers)
            return result
    finally:
        await release_conn(conn)


# ─── OWNER: Salon boshqaruvi ─────────────────────────────────────────────────

@router.post("/create_salon")
async def create_salon(data: SalonCreate, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id FROM salons WHERE owner_id=%s", (owner["user_id"],))
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Sizda allaqachon sartaroshxona mavjud")
            await cur.execute(
                "INSERT INTO salons (owner_id, name, description, address, district, lat, lng, phone) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
                (owner["user_id"], data.name, data.description, data.address, data.district, data.lat, data.lng, data.phone),
            )
            await conn.commit()
            return {"status": "success", "salon_id": cur.lastrowid}
    finally:
        await release_conn(conn)


@router.get("/my_salon")
async def get_my_salon(owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            result = dict(salon)
            result['working_hours_start'] = timedelta_to_str(result.get('working_hours_start'))
            result['working_hours_end'] = timedelta_to_str(result.get('working_hours_end'))
            for k in ['created_at', 'updated_at']:
                if result.get(k) and hasattr(result[k], 'isoformat'):
                    result[k] = result[k].isoformat()
            return result
    finally:
        await release_conn(conn)


@router.put("/update_salon")
async def update_salon(data: SalonUpdate, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            fields, values = [], []
            for col in ("name", "description", "address", "district", "lat", "lng", "phone", "working_hours_start", "working_hours_end"):
                val = getattr(data, col)
                if val is not None:
                    fields.append(f"{col}=%s")
                    values.append(val)
            if fields:
                values.append(salon["id"])
                await cur.execute(f"UPDATE salons SET {','.join(fields)} WHERE id=%s", values)
                await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)


# ─── OWNER: Xodimlar boshqaruvi ─────────────────────────────────────────────

@router.get("/salon_staff")
async def get_salon_staff(owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            await cur.execute(
                "SELECT b.id, b.name, b.specialization, b.phone, b.rating, b.total_reviews, b.avatar_url, "
                "b.is_online, b.is_accepting_bookings, b.experience, "
                "(SELECT COUNT(*) FROM appointments a WHERE a.barber_id=b.id AND a.status='completed') as completed_count, "
                "(SELECT COALESCE(SUM(p.amount),0) FROM payments p JOIN appointments a ON p.appointment_id=a.id "
                "WHERE a.barber_id=b.id AND p.status='completed') as total_revenue "
                "FROM barbers b WHERE b.salon_id=%s ORDER BY total_revenue DESC",
                (salon["id"],),
            )
            staff = await cur.fetchall()
            return {"salon_id": salon["id"], "staff_count": len(staff), "staff": [dict(s) for s in staff]}
    finally:
        await release_conn(conn)


@router.post("/invite_barber")
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
                await cur.execute(
                    "SELECT b.id, b.salon_id, b.user_id FROM barbers b JOIN users u ON b.user_id=u.id WHERE u.email=%s",
                    (data.barber_email,),
                )
                barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Sartarosh topilmadi")
            if barber["salon_id"]:
                raise HTTPException(status_code=409, detail="Bu sartarosh allaqachon salonda ishlaydi")
            await cur.execute(
                "SELECT id FROM salon_invitations WHERE salon_id=%s AND barber_id=%s AND status='pending'",
                (salon["id"], barber["id"]),
            )
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Bu sartaroshga allaqachon taklif yuborilgan")
            await cur.execute(
                "INSERT INTO salon_invitations (salon_id, barber_id, initiated_by, message) VALUES (%s,%s,'owner',%s)",
                (salon["id"], barber["id"], data.message),
            )
            await cur.execute(
                "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')",
                (barber["user_id"], "Yangi taklif!", f"{salon['name']} sizni jamoasiga taklif qilmoqda"),
            )
            await conn.commit()
            return {"status": "success", "invitation_id": cur.lastrowid}
    finally:
        await release_conn(conn)


@router.delete("/remove_barber/{barber_id}")
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
            await cur.execute(
                "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')",
                (barber["user_id"], "Salondan chiqarildingiz", f"{salon['name']} jamoasidan chiqarildingiz"),
            )
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)


# ─── INVITATIONS: Taklif/so'rovlar ──────────────────────────────────────────

@router.post("/join_request")
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
            await cur.execute(
                "SELECT id FROM salon_invitations WHERE salon_id=%s AND barber_id=%s AND status='pending'",
                (data.salon_id, barber["id"]),
            )
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="So'rovingiz allaqachon yuborilgan")
            await cur.execute(
                "INSERT INTO salon_invitations (salon_id, barber_id, initiated_by, message) VALUES (%s,%s,'barber',%s)",
                (data.salon_id, barber["id"], data.message),
            )
            await cur.execute(
                "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')",
                (salon["owner_id"], "Yangi qo'shilish so'rovi", "Sartarosh saloningizga qo'shilmoqchi"),
            )
            await conn.commit()
            return {"status": "success", "invitation_id": cur.lastrowid}
    finally:
        await release_conn(conn)


@router.get("/my_invitations")
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
                await cur.execute(
                    "SELECT i.*, s.name as salon_name, s.avatar_url as salon_avatar "
                    "FROM salon_invitations i JOIN salons s ON i.salon_id=s.id "
                    "WHERE i.barber_id=%s AND i.status='pending' ORDER BY i.created_at DESC",
                    (barber["id"],),
                )
            elif role == "owner":
                await cur.execute("SELECT id FROM salons WHERE owner_id=%s", (auth["user_id"],))
                salon = await cur.fetchone()
                if not salon:
                    return []
                await cur.execute(
                    "SELECT i.*, b.name as barber_name, b.avatar_url as barber_avatar, b.specialization, b.rating "
                    "FROM salon_invitations i JOIN barbers b ON i.barber_id=b.id "
                    "WHERE i.salon_id=%s AND i.status='pending' ORDER BY i.created_at DESC",
                    (salon["id"],),
                )
            else:
                return []
            rows = []
            for r in await cur.fetchall():
                d = dict(r)
                for k in ['created_at', 'responded_at']:
                    if d.get(k) and hasattr(d[k], 'isoformat'):
                        d[k] = d[k].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)


@router.put("/respond_invitation/{invitation_id}")
async def respond_invitation(invitation_id: int, data: InvitationResponse, auth=Depends(require_auth)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT i.*, s.owner_id, s.name as salon_name, b.user_id as barber_user_id "
                "FROM salon_invitations i JOIN salons s ON i.salon_id=s.id JOIN barbers b ON i.barber_id=b.id "
                "WHERE i.id=%s AND i.status='pending'",
                (invitation_id,),
            )
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
                await cur.execute(
                    "UPDATE salon_invitations SET status='cancelled' WHERE barber_id=%s AND status='pending' AND id!=%s",
                    (inv["barber_id"], invitation_id),
                )
                await cur.execute(
                    "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'system')",
                    (inv["barber_user_id"], "Salonga qo'shildingiz", f"Siz {inv['salon_name']} jamoasiga qo'shildingiz"),
                )
            await conn.commit()
            return {"status": "success", "result": new_status}
    finally:
        await release_conn(conn)


# ─── OWNER DASHBOARD: Daromad analitikasi ────────────────────────────────────

@router.get("/owner_dashboard")
async def owner_dashboard(owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            salon_id = salon["id"]
            today = datetime.date.today()
            month_start = today.replace(day=1)
            await cur.execute(
                "SELECT COALESCE(SUM(p.amount),0) as total FROM payments p JOIN appointments a ON p.appointment_id=a.id "
                "JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed'",
                (salon_id,),
            )
            total_revenue = float((await cur.fetchone())["total"])
            await cur.execute(
                "SELECT COALESCE(SUM(p.amount),0) as total FROM payments p JOIN appointments a ON p.appointment_id=a.id "
                "JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed' AND DATE(p.created_at)=%s",
                (salon_id, today),
            )
            today_revenue = float((await cur.fetchone())["total"])
            await cur.execute(
                "SELECT COALESCE(SUM(p.amount),0) as total FROM payments p JOIN appointments a ON p.appointment_id=a.id "
                "JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s",
                (salon_id, month_start),
            )
            month_revenue = float((await cur.fetchone())["total"])
            await cur.execute(
                "SELECT COUNT(CASE WHEN DATE(a.appointment_time)=%s AND a.status!='cancelled' THEN 1 END) as today_count, "
                "COUNT(CASE WHEN a.status='pending' THEN 1 END) as pending_count, "
                "COUNT(CASE WHEN a.status='completed' THEN 1 END) as completed_count "
                "FROM appointments a JOIN barbers b ON a.barber_id=b.id WHERE b.salon_id=%s",
                (today, salon_id),
            )
            appt_stats = await cur.fetchone()
            await cur.execute("SELECT COUNT(*) as cnt FROM barbers WHERE salon_id=%s", (salon_id,))
            barbers_count = (await cur.fetchone())["cnt"]
            await cur.execute(
                "SELECT b.id, b.name, b.avatar_url, b.rating, b.is_online, "
                "COALESCE(SUM(CASE WHEN p.status='completed' THEN p.amount END),0) as revenue, "
                "COUNT(CASE WHEN a.status='completed' THEN 1 END) as completed, "
                "COUNT(CASE WHEN DATE(a.appointment_time)=%s AND a.status!='cancelled' THEN 1 END) as today_appts "
                "FROM barbers b LEFT JOIN appointments a ON a.barber_id=b.id "
                "LEFT JOIN payments p ON p.appointment_id=a.id "
                "WHERE b.salon_id=%s GROUP BY b.id ORDER BY revenue DESC",
                (today, salon_id),
            )
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


@router.get("/owner_revenue_report")
async def owner_revenue_report(days: int = 7, owner=Depends(require_owner)):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            start_date = datetime.date.today() - datetime.timedelta(days=days - 1)
            await cur.execute(
                "SELECT DATE(p.created_at) as day, COALESCE(SUM(p.amount),0) as revenue, COUNT(*) as transactions "
                "FROM payments p JOIN appointments a ON p.appointment_id=a.id JOIN barbers b ON a.barber_id=b.id "
                "WHERE b.salon_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s GROUP BY DATE(p.created_at) ORDER BY day",
                (salon["id"], start_date),
            )
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


@router.get("/owner_today_appointments")
async def owner_today_appointments(owner=Depends(require_owner)):
    """Bugungi navbatlar ro'yxati (live) — vaqt, mijoz, barber, status."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            salon = await _get_owner_salon(cur, owner["user_id"])
            today = datetime.date.today()
            await cur.execute(
                "SELECT a.id, a.appointment_time, a.end_time, a.service_name, a.price, a.status, "
                "a.payment_status, u.full_name as customer_name, u.phone as customer_phone, "
                "b.name as barber_name, b.avatar_url as barber_avatar "
                "FROM appointments a "
                "JOIN users u ON a.customer_id=u.id "
                "JOIN barbers b ON a.barber_id=b.id "
                "WHERE b.salon_id=%s AND DATE(a.appointment_time)=%s AND a.status!='cancelled' "
                "ORDER BY a.appointment_time ASC",
                (salon["id"], today),
            )
            rows = []
            for r in await cur.fetchall():
                d = dict(r)
                for k in ['appointment_time', 'end_time']:
                    if d.get(k) and hasattr(d[k], 'isoformat'):
                        d[k] = d[k].isoformat()
                    elif d.get(k) and hasattr(d[k], 'strftime'):
                        d[k] = d[k].strftime('%H:%M')
                rows.append(d)
            return {"date": today.isoformat(), "appointments": rows, "count": len(rows)}
    finally:
        await release_conn(conn)


@router.get("/owner_search_barbers")
async def owner_search_barbers(query: str, owner=Depends(require_owner)):
    """Salonga taklif qilish uchun sartarosh qidirish (salonsiz barberlar)."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            like = f"%{query}%"
            await cur.execute(
                "SELECT b.id, b.name, b.specialization, b.rating, b.total_reviews, b.avatar_url, "
                "b.phone, b.experience, u.email "
                "FROM barbers b JOIN users u ON b.user_id=u.id "
                "WHERE b.salon_id IS NULL AND (b.name LIKE %s OR u.email LIKE %s OR b.phone LIKE %s) "
                "LIMIT 20",
                (like, like, like),
            )
            return [dict(r) for r in await cur.fetchall()]
    finally:
        await release_conn(conn)
