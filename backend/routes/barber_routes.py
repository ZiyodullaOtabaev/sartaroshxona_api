# =====================================================
# BARBER ROUTES — CRUD, search, status, services, working days
# =====================================================

from typing import List

import aiomysql
from fastapi import APIRouter, HTTPException

from database import get_conn, release_conn, haversine, timedelta_to_str
from models import UpdateProfile, BlockedSlot

router = APIRouter()


@router.get("/nearby_barbers")
async def get_nearby_barbers(user_lat: float, user_lng: float, radius_km: float = 2.0):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, name, district, rating, total_reviews, lat, lng, experience, specialization, "
                "phone, is_online, avatar_url, bio, working_hours_start, working_hours_end "
                "FROM barbers WHERE lat IS NOT NULL AND lng IS NOT NULL AND verification_status='approved'"
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


@router.get("/all_barbers")
async def get_all_barbers(user_lat: float = 41.3111, user_lng: float = 69.2797):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT id, name, district, rating, total_reviews, lat, lng, experience, specialization, "
                "phone, is_online, avatar_url, bio FROM barbers "
                "WHERE lat IS NOT NULL AND lng IS NOT NULL AND verification_status='approved'"
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


@router.get("/search_barbers")
async def search_barbers(query: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            like = f"%{query}%"
            await cur.execute(
                "SELECT id, name, district, rating, total_reviews, lat, lng, experience, specialization, "
                "phone, is_online, avatar_url, bio FROM barbers "
                "WHERE verification_status='approved' AND (name LIKE %s OR district LIKE %s OR specialization LIKE %s)",
                (like, like, like),
            )
            result = await cur.fetchall()
            return [dict(b) for b in result]
    finally:
        await release_conn(conn)


@router.get("/barber/{barber_id}")
async def get_barber_detail(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT b.*, u.email FROM barbers b JOIN users u ON b.user_id = u.id WHERE b.id=%s",
                (barber_id,),
            )
            barber = await cur.fetchone()
            if not barber:
                raise HTTPException(status_code=404, detail="Topilmadi")
            await cur.execute(
                "SELECT day_of_week, is_working FROM barber_working_days WHERE barber_id=%s ORDER BY day_of_week",
                (barber_id,),
            )
            working_days = await cur.fetchall()
            await cur.execute("SELECT * FROM barber_services WHERE barber_id=%s AND is_active=1", (barber_id,))
            services = await cur.fetchall()
            await cur.execute(
                "SELECT r.*, u.full_name as customer_name FROM reviews r "
                "JOIN users u ON r.customer_id=u.id WHERE r.barber_id=%s ORDER BY r.created_at DESC LIMIT 10",
                (barber_id,),
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


@router.put("/update_profile/{barber_id}")
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


@router.put("/update_online_status/{barber_id}")
async def update_online(barber_id: int, is_online: bool):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE barbers SET is_online=%s WHERE id=%s", (is_online, barber_id))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)


@router.put("/update_working_days/{barber_id}")
async def update_working_days(barber_id: int, days: List[int]):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("DELETE FROM barber_working_days WHERE barber_id=%s", (barber_id,))
            for day in range(7):
                await cur.execute(
                    "INSERT INTO barber_working_days (barber_id, day_of_week, is_working) VALUES (%s,%s,%s)",
                    (barber_id, day, day in days),
                )
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)


@router.get("/get_services/{barber_id}")
async def get_services(barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM barber_services WHERE barber_id=%s AND is_active=1 ORDER BY id",
                (barber_id,),
            )
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)


@router.post("/add_service")
async def add_service(barber_id: int, name: str, price: float, duration: int = 30, description: str = ""):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO barber_services (barber_id, service_name, price, duration_minutes, description) "
                "VALUES (%s,%s,%s,%s,%s)",
                (barber_id, name, price, duration, description),
            )
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)


@router.delete("/delete_service/{service_id}")
async def delete_service(service_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE barber_services SET is_active=0 WHERE id=%s", (service_id,))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)


@router.post("/block_slot")
async def block_slot(slot: BlockedSlot):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO barber_blocked_slots (barber_id, blocked_date, start_time, end_time, reason) "
                "VALUES (%s,%s,%s,%s,%s)",
                (slot.barber_id, slot.blocked_date, slot.start_time, slot.end_time, slot.reason),
            )
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)


@router.get("/blocked_slots/{barber_id}")
async def get_blocked_slots(barber_id: int, date: str):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM barber_blocked_slots WHERE barber_id=%s AND blocked_date=%s",
                (barber_id, date),
            )
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)


@router.get("/barber_stats/{barber_id}")
async def get_barber_stats(barber_id: int):
    import datetime
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            today = datetime.date.today()
            month_start = today.replace(day=1)
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND DATE(appointment_time)=%s AND status!='cancelled'",
                (barber_id, today),
            )
            today_count = (await cur.fetchone())['cnt']
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND status='completed'",
                (barber_id,),
            )
            total_completed = (await cur.fetchone())['cnt']
            await cur.execute(
                "SELECT COALESCE(SUM(p.amount),0) as rev FROM payments p JOIN appointments a ON p.appointment_id=a.id "
                "WHERE a.barber_id=%s AND p.status='completed'",
                (barber_id,),
            )
            revenue = float((await cur.fetchone())['rev'])
            await cur.execute(
                "SELECT COALESCE(SUM(p.amount),0) as rev FROM payments p JOIN appointments a ON p.appointment_id=a.id "
                "WHERE a.barber_id=%s AND p.status='completed' AND DATE(p.created_at)>=%s",
                (barber_id, month_start),
            )
            monthly_revenue = float((await cur.fetchone())['rev'])
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM appointments WHERE barber_id=%s AND status='pending'",
                (barber_id,),
            )
            pending_count = (await cur.fetchone())['cnt']
            await cur.execute(
                "SELECT COALESCE(AVG(rating),5.0) as avg_r, COUNT(*) as cnt FROM reviews WHERE barber_id=%s",
                (barber_id,),
            )
            review_stats = await cur.fetchone()
            return {
                "today_count": today_count,
                "total_completed": total_completed,
                "revenue": revenue,
                "monthly_revenue": monthly_revenue,
                "pending_count": pending_count,
                "avg_rating": round(float(review_stats['avg_r']), 1),
                "total_reviews": review_stats['cnt'],
            }
    except Exception:
        return {
            "today_count": 0, "total_completed": 0, "revenue": 0,
            "monthly_revenue": 0, "pending_count": 0, "avg_rating": 5.0, "total_reviews": 0,
        }
    finally:
        await release_conn(conn)


# ─── SOCH DIZAYNLARI (HAIRSTYLE TEMPLATES) ──────────────────────────────────

@router.get("/hairstyles/{barber_id}")
async def get_hairstyles(barber_id: int):
    """Sartaroshning soch dizaynlari ro'yxati."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM hairstyles WHERE barber_id=%s AND is_active=1 ORDER BY created_at DESC",
                (barber_id,),
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


@router.post("/hairstyles")
async def add_hairstyle(barber_id: int, name: str, description: str = "", image_url: str = ""):
    """Yangi soch dizayni qo'shish."""
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO hairstyles (barber_id, name, description, image_url) VALUES (%s,%s,%s,%s)",
                (barber_id, name, description, image_url),
            )
            await conn.commit()
            return {"status": "success", "id": cur.lastrowid}
    finally:
        await release_conn(conn)


@router.delete("/hairstyles/{style_id}")
async def delete_hairstyle(style_id: int):
    """Soch dizaynini o'chirish."""
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE hairstyles SET is_active=0 WHERE id=%s", (style_id,))
            await conn.commit()
            return {"status": "success"}
    finally:
        await release_conn(conn)
