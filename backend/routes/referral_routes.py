# =====================================================
# REFERRAL ROUTES — do'stni taklif qil, ikkalaga chegirma
# =====================================================

import secrets
import string

import aiomysql
from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

from config import REFERRAL_REWARD_AMOUNT, REFERRAL_MAX_COUNT, SERVER_BASE_URL
from database import get_conn, release_conn

router = APIRouter()


def _generate_referral_code(name: str) -> str:
    """Foydalanuvchi ismidan unique referral kodi yaratish."""
    # Ismning birinchi 3 harfi + 4 ta random raqam
    prefix = "".join(c for c in name.upper() if c.isalpha())[:3]
    if len(prefix) < 3:
        prefix = prefix.ljust(3, "X")
    suffix = "".join(secrets.choice(string.digits) for _ in range(4))
    return f"{prefix}{suffix}"


# ─── REFERRAL KOD OLISH ──────────────────────────────────────────────────────

@router.get("/referral/my_code/{user_id}")
async def get_my_referral_code(user_id: int):
    """Foydalanuvchining referral kodini olish (yo'q bo'lsa yaratish)."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT referral_code, full_name, referral_balance, referral_count FROM users WHERE id=%s", (user_id,))
            user = await cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")

            code = user["referral_code"]
            if not code:
                # Birinchi marta — kod yaratish
                code = _generate_referral_code(user["full_name"])
                # Unique bo'lishini tekshirish
                for _ in range(10):
                    await cur.execute("SELECT id FROM users WHERE referral_code=%s", (code,))
                    if not await cur.fetchone():
                        break
                    code = _generate_referral_code(user["full_name"])
                await cur.execute("UPDATE users SET referral_code=%s WHERE id=%s", (code, user_id))
                await conn.commit()

            referral_link = f"{SERVER_BASE_URL}/ref/{code}"
            return {
                "referral_code": code,
                "referral_link": referral_link,
                "referral_balance": float(user["referral_balance"] or 0),
                "referral_count": user["referral_count"] or 0,
                "max_referrals": REFERRAL_MAX_COUNT,
                "reward_per_referral": REFERRAL_REWARD_AMOUNT,
                "share_message": f"✂️ Sartaroshxona ilovasida navbat oling va chegirmaga ega bo'ling!\n\n"
                                 f"Mening taklif kodim: {code}\n"
                                 f"Taklif havolasi: {referral_link}\n\n"
                                 f"Ushbu havola orqali ilovani yuklab oling va ikkalamizga {int(REFERRAL_REWARD_AMOUNT)} so'm mukofot oling!",
            }
    finally:
        await release_conn(conn)


@router.get("/ref/{code}", response_class=HTMLResponse)
async def referral_landing_page(code: str):
    """Referral havola brauzerda ochilganda ilovaga yo'naltirish landing sahifasi."""
    html_content = f"""
    <!DOCTYPE html>
    <html lang="uz">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Sartaroshxona — Taklif Kodi: {code}</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0D1117; color: white; text-align: center; padding: 40px 20px; margin: 0; }}
            .card {{ background: #161B22; border-radius: 24px; padding: 32px 24px; max-width: 420px; margin: 20px auto; border: 1px solid #30363D; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }}
            h2 {{ color: #A29BFE; margin-bottom: 8px; font-size: 26px; }}
            p {{ color: #8B949E; font-size: 15px; line-height: 1.5; }}
            .code-box {{ font-size: 26px; letter-spacing: 4px; font-weight: bold; color: #FFFFFF; background: linear-gradient(135deg, #6C5CE7, #A29BFE); padding: 14px 20px; border-radius: 14px; margin: 20px 0; text-shadow: 0 2px 4px rgba(0,0,0,0.2); }}
            .btn {{ display: block; background: #6C5CE7; color: white; padding: 16px; border-radius: 14px; text-decoration: none; font-weight: bold; font-size: 16px; margin-top: 24px; box-shadow: 0 4px 15px rgba(108,92,231,0.4); }}
            .btn:hover {{ background: #5B4BC4; }}
        </style>
    </head>
    <body>
        <div class="card">
            <h2>✂️ Sartaroshxona</h2>
            <p>Do'stingiz sizni <b>Sartaroshxona</b> ilovasiga taklif qildi!</p>
            <div class="code-box">{code}</div>
            <p>Ro'yxatdan o'tishda ushbu taklif kodini kiriting va <b>10,000 so'm mukofot</b> balansiga ega bo'ling!</p>
            <a href="sartaroshxona://ref/{code}" class="btn">📱 Ilovada Ochish</a>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


@router.get("/referral/stats/{user_id}")
async def get_referral_stats(user_id: int):
    """Taklif qilgan odamlar ro'yxati va holati."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT r.status, r.reward_amount, r.created_at, r.completed_at, u.full_name "
                "FROM referrals r JOIN users u ON r.referred_id = u.id "
                "WHERE r.referrer_id=%s ORDER BY r.created_at DESC",
                (user_id,),
            )
            referrals = []
            for r in await cur.fetchall():
                d = dict(r)
                for k in ["created_at", "completed_at"]:
                    if d.get(k) and hasattr(d[k], "isoformat"):
                        d[k] = d[k].isoformat()
                referrals.append(d)

            await cur.execute("SELECT referral_balance, referral_count FROM users WHERE id=%s", (user_id,))
            user = await cur.fetchone()

            return {
                "referral_count": user["referral_count"] if user else 0,
                "referral_balance": float(user["referral_balance"] or 0) if user else 0,
                "max_referrals": REFERRAL_MAX_COUNT,
                "referrals": referrals,
            }
    finally:
        await release_conn(conn)


# ─── REFERRAL KODNI ISHLATISH (ro'yxatdan o'tishda) ──────────────────────────

async def apply_referral_on_register(referred_user_id: int, referral_code: str):
    """Ro'yxatdan o'tishda referral kodni qo'llash. Internal funksiya."""
    if not referral_code:
        return
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # Referrer'ni topish
            await cur.execute(
                "SELECT id, referral_count FROM users WHERE referral_code=%s",
                (referral_code,),
            )
            referrer = await cur.fetchone()
            if not referrer:
                return  # Noto'g'ri kod — skip
            if referrer["id"] == referred_user_id:
                return  # O'zini o'zi taklif qilishi mumkin emas
            if (referrer["referral_count"] or 0) >= REFERRAL_MAX_COUNT:
                return  # Maksimal taklif soniga yetgan

            # Dublikat tekshirish
            await cur.execute(
                "SELECT id FROM referrals WHERE referred_id=%s",
                (referred_user_id,),
            )
            if await cur.fetchone():
                return  # Bu user allaqachon kimningdir referrali

            # Referral yozuvi
            await cur.execute(
                "INSERT INTO referrals (referrer_id, referred_id, referral_code, status) "
                "VALUES (%s,%s,%s,'pending')",
                (referrer["id"], referred_user_id, referral_code),
            )

            # Referred user'ga bog'lash
            await cur.execute(
                "UPDATE users SET referred_by=%s WHERE id=%s",
                (referrer["id"], referred_user_id),
            )

            await conn.commit()
    except Exception as e:
        try:
            await conn.rollback()
        except Exception:
            pass
        print(f"[Referral] Apply xatolik: {e}")
    finally:
        await release_conn(conn)


async def complete_referral_on_payment(customer_id: int):
    """Birinchi to'lov qilinganda referral'ni complete qilish va ikkalaga mukofot berish."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            # Bu user'ning pending referral'i bormi?
            await cur.execute(
                "SELECT r.id, r.referrer_id, r.reward_amount FROM referrals r "
                "WHERE r.referred_id=%s AND r.status='pending'",
                (customer_id,),
            )
            ref = await cur.fetchone()
            if not ref:
                return  # Referral yo'q yoki allaqachon completed

            reward = float(ref["reward_amount"] or REFERRAL_REWARD_AMOUNT)

            # Referral'ni complete qilish
            await cur.execute(
                "UPDATE referrals SET status='completed', completed_at=NOW() WHERE id=%s",
                (ref["id"],),
            )

            # Referrer'ga mukofot
            await cur.execute(
                "UPDATE users SET referral_balance = referral_balance + %s, referral_count = referral_count + 1 "
                "WHERE id=%s",
                (reward, ref["referrer_id"]),
            )

            # Referred (yangi user) ga ham mukofot
            await cur.execute(
                "UPDATE users SET referral_balance = referral_balance + %s WHERE id=%s",
                (reward, customer_id),
            )

            # Bildirishnomalar
            await cur.execute(
                "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'promotion')",
                (ref["referrer_id"], "Referral mukofot!",
                 f"Taklif qilgan do'stingiz birinchi navbatini to'ladi. +{int(reward)} so'm balansga qo'shildi!"),
            )
            await cur.execute(
                "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'promotion')",
                (customer_id, "Xush kelibsiz mukofoti!",
                 f"Birinchi to'lovingiz uchun +{int(reward)} so'm balansga qo'shildi!"),
            )

            await conn.commit()
    except Exception as e:
        try:
            await conn.rollback()
        except Exception:
            pass
        print(f"[Referral] Complete xatolik: {e}")
    finally:
        await release_conn(conn)


@router.get("/referral/balance/{user_id}")
async def get_referral_balance(user_id: int):
    """Referral balansini ko'rish."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT referral_balance FROM users WHERE id=%s", (user_id,))
            user = await cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")
            return {
                "referral_balance": float(user["referral_balance"] or 0),
                "message": "Bu balans keyingi navbatda chegirma sifatida ishlatiladi.",
            }
    finally:
        await release_conn(conn)
