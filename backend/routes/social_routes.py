# =====================================================
# SOCIAL ROUTES — reviews, favorites, notifications, chat
# =====================================================

import aiomysql
from fastapi import APIRouter, HTTPException

from database import get_conn, release_conn
from models import ReviewCreate, MessageCreate

router = APIRouter()


# ─── REVIEWS ─────────────────────────────────────────────────────────────────

@router.post("/add_review")
async def add_review(review: ReviewCreate):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id FROM reviews WHERE appointment_id=%s AND customer_id=%s",
                (review.appointment_id, review.customer_id),
            )
            if await cur.fetchone():
                raise HTTPException(status_code=409, detail="Allaqachon baholangansiz")
            await cur.execute(
                "INSERT INTO reviews (appointment_id, customer_id, barber_id, rating, comment) VALUES (%s,%s,%s,%s,%s)",
                (review.appointment_id, review.customer_id, review.barber_id, review.rating, review.comment),
            )
            await cur.execute(
                "SELECT AVG(rating) as avg_r, COUNT(*) as cnt FROM reviews WHERE barber_id=%s",
                (review.barber_id,),
            )
            stats = await cur.fetchone()
            if stats and stats[0]:
                await cur.execute(
                    "UPDATE barbers SET rating=%s, total_reviews=%s WHERE id=%s",
                    (round(float(stats[0]), 1), stats[1], review.barber_id),
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


@router.get("/barber_reviews/{barber_id}")
async def get_barber_reviews(barber_id: int, limit: int = 20):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT r.*, u.full_name as customer_name FROM reviews r "
                "JOIN users u ON r.customer_id=u.id WHERE r.barber_id=%s ORDER BY r.created_at DESC LIMIT %s",
                (barber_id, limit),
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


# ─── NOTIFICATIONS ───────────────────────────────────────────────────────────

@router.get("/notifications/{user_id}")
async def get_notifications(user_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT * FROM notifications WHERE user_id=%s ORDER BY created_at DESC LIMIT 50",
                (user_id,),
            )
            result = await cur.fetchall()
            await cur.execute(
                "SELECT COUNT(*) as cnt FROM notifications WHERE user_id=%s AND is_read=0",
                (user_id,),
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


@router.put("/mark_notifications_read/{user_id}")
async def mark_all_read(user_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE notifications SET is_read=1 WHERE user_id=%s", (user_id,))
            await conn.commit()
        return {"status": "success"}
    finally:
        await release_conn(conn)


# ─── FAVORITES ───────────────────────────────────────────────────────────────

@router.post("/toggle_favorite")
async def toggle_favorite(customer_id: int, barber_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id FROM favorites WHERE customer_id=%s AND barber_id=%s",
                (customer_id, barber_id),
            )
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


@router.get("/favorites/{customer_id}")
async def get_favorites(customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT b.id, b.name, b.district, b.rating, b.specialization, b.is_online, "
                "b.avatar_url, b.lat, b.lng, b.total_reviews "
                "FROM favorites f JOIN barbers b ON f.barber_id=b.id "
                "WHERE f.customer_id=%s ORDER BY f.created_at DESC",
                (customer_id,),
            )
            result = await cur.fetchall()
            return [dict(r) for r in result]
    finally:
        await release_conn(conn)


# ─── CHAT / XABARLAR ────────────────────────────────────────────────────────

@router.post("/send_message")
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
            await cur.execute(
                "SELECT id, sender_id, receiver_id, body, is_read, created_at FROM messages WHERE id=%s",
                (msg_id,),
            )
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


@router.get("/messages/{user_id}/{other_id}")
async def get_messages(user_id: int, other_id: int):
    """Ikki foydalanuvchi o'rtasidagi yozishmalar."""
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
            await cur.execute(
                "UPDATE messages SET is_read=1 WHERE sender_id=%s AND receiver_id=%s AND is_read=0",
                (other_id, user_id),
            )
            await conn.commit()
            return {"messages": rows}
    finally:
        await release_conn(conn)


@router.get("/conversations/{user_id}")
async def get_conversations(user_id: int):
    """Foydalanuvchining suhbatlari ro'yxati."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT m.id, m.sender_id, m.receiver_id, m.body, m.is_read, m.created_at, "
                "CASE WHEN m.sender_id=%s THEN m.receiver_id ELSE m.sender_id END AS partner_id "
                "FROM messages m WHERE m.sender_id=%s OR m.receiver_id=%s "
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
