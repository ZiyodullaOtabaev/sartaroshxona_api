# =====================================================
# SARTAROSHXONA API — Asosiy fayl
# Barcha endpoint'lar routes/ papkasida modullarga ajratilgan.
# =====================================================

import os
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()  # .env fayldan environment variable'larni yuklash

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse

from database import create_pool, close_pool, init_tables, get_conn, release_conn

# ─── Route modullarini import qilish ─────────────────────────────────────────
from routes.auth_routes import router as auth_router
from routes.barber_routes import router as barber_router
from routes.appointment_routes import router as appointment_router
from routes.payment_routes import router as payment_router
from routes.salon_routes import router as salon_router
from routes.social_routes import router as social_router
from routes.admin_routes import router as admin_router
from routes.loyalty_routes import router as loyalty_router
from routes.referral_routes import router as referral_router
from routes.notification_routes import router as notification_router


# =====================================================
# APP LIFESPAN
# =====================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    await create_pool()
    await init_tables()

    # Keep-alive: Render free tier uxlab qolmasligi uchun
    # Server o'ziga har 13 daqiqada ping yuboradi
    import asyncio
    async def _keep_alive():
        import httpx as _httpx
        while True:
            await asyncio.sleep(13 * 60)  # 13 daqiqa
            try:
                async with _httpx.AsyncClient(timeout=10) as client:
                    await client.get(f"{os.getenv('RENDER_EXTERNAL_URL', 'http://localhost:8000')}/health")
            except Exception:
                pass

    keep_alive_task = asyncio.create_task(_keep_alive())

    yield

    keep_alive_task.cancel()
    await close_pool()


# =====================================================
# APP
# =====================================================

app = FastAPI(
    title="Sartaroshxona API",
    version="3.0.0",
    lifespan=lifespan,
)

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
# ROUTERS
# =====================================================

app.include_router(auth_router)
app.include_router(barber_router)
app.include_router(appointment_router)
app.include_router(payment_router)
app.include_router(salon_router)
app.include_router(social_router)
app.include_router(admin_router)
app.include_router(loyalty_router)
app.include_router(referral_router)
app.include_router(notification_router)


# =====================================================
# ROOT / HEALTH
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
        from fastapi import HTTPException
        raise HTTPException(status_code=503, detail=f"DB xatolik: {str(e)}")


@app.delete("/admin/clear_all_users")
async def clear_all_users(admin_key: str = ""):
    """Barcha userlarni o'chirish (faqat test uchun)."""
    if admin_key != "sartaroshxona-admin-2025":
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Noto'g'ri kalit")
    conn = await get_conn()
    try:
        async with conn.cursor() as cur:
            await cur.execute("SET FOREIGN_KEY_CHECKS=0")
            await cur.execute("DELETE FROM users")
            await cur.execute("SET FOREIGN_KEY_CHECKS=1")
            await conn.commit()
        return {"status": "success", "message": "Barcha userlar o'chirildi"}
    finally:
        await release_conn(conn)


@app.get("/privacy-policy", response_class=HTMLResponse)
async def privacy_policy():
    """Play Store uchun Privacy Policy sahifasi."""
    from fastapi.responses import HTMLResponse
    return HTMLResponse("""<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Maxfiylik siyosati — Sartaroshxona</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 700px; margin: 0 auto; padding: 32px 20px; color: #333; line-height: 1.7; }
        h1 { color: #1a1a2e; font-size: 24px; }
        h2 { color: #2ecc71; font-size: 18px; margin-top: 28px; }
        p { margin: 10px 0; }
        .date { color: #888; font-size: 13px; }
    </style>
</head>
<body>
    <h1>Maxfiylik siyosati</h1>
    <p class="date">Oxirgi yangilanish: 2025-yil, iyul</p>

    <h2>1. Umumiy ma'lumot</h2>
    <p>Sartaroshxona ilovasi ("Ilova") foydalanuvchilarning shaxsiy ma'lumotlarini qonuniy asosda yig'adi va qayta ishlaydi. Biz foydalanuvchilar maxfiyligini hurmat qilamiz.</p>

    <h2>2. Yig'iladigan ma'lumotlar</h2>
    <p>Ilova quyidagi ma'lumotlarni yig'adi:</p>
    <p>• Ism, email manzil, telefon raqami (ro'yxatdan o'tishda)</p>
    <p>• Joylashuv ma'lumotlari (yaqin sartaroshlarni topish uchun)</p>
    <p>• Navbat tarixi va to'lov ma'lumotlari</p>
    <p>• Qurilma identifikatori (push notification uchun)</p>

    <h2>3. Ma'lumotlardan foydalanish</h2>
    <p>Yig'ilgan ma'lumotlar quyidagi maqsadlarda ishlatiladi:</p>
    <p>• Xizmatlarni taqdim etish (navbat, to'lov)</p>
    <p>• Bildirishnomalar yuborish</p>
    <p>• Xizmat sifatini yaxshilash</p>
    <p>• Foydalanuvchi xavfsizligini ta'minlash</p>

    <h2>4. Ma'lumotlarni uchinchi tomonlarga berish</h2>
    <p>Biz foydalanuvchi ma'lumotlarini uchinchi tomonlarga bermay amiz, bundan mustasno:</p>
    <p>• To'lov tizimlari (Payme, Click) — to'lovni amalga oshirish uchun</p>
    <p>• Qonun talabiga binoan</p>

    <h2>5. Ma'lumotlarni saqlash</h2>
    <p>Ma'lumotlar xavfsiz serverlarda saqlanadi. Parollar shifrlangan holda (bcrypt) saqlanadi.</p>

    <h2>6. Foydalanuvchi huquqlari</h2>
    <p>Foydalanuvchi istalgan vaqtda:</p>
    <p>• O'z ma'lumotlarini ko'rishi mumkin</p>
    <p>• Ma'lumotlarini o'zgartirishi mumkin</p>
    <p>• Hisobini o'chirish so'rovini yuborishi mumkin</p>

    <h2>7. Bog'lanish</h2>
    <p>Savollar uchun: <a href="mailto:ziyodullamee@gmail.com">ziyodullamee@gmail.com</a></p>
</body>
</html>""")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
