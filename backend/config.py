# =====================================================
# CONFIG — Barcha konfiguratsiya va environment o'zgaruvchilari
# =====================================================

import os
import ssl

SECRET_KEY = os.getenv("SECRET_KEY", "sartaroshxona-super-secret-key-2025!@#")
ADMIN_KEY = os.getenv("ADMIN_KEY", "sartaroshxona-admin-2025")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

SERVER_BASE_URL = os.getenv("SERVER_BASE_URL", "http://192.168.10.4:8000")

# ─── TO'LOV TIZIMLARI (Payme / Click) ─────────────────────────────────────────────
PAYME_MERCHANT_ID = os.getenv("PAYME_MERCHANT_ID", "TEST_PAYME_MERCHANT_ID")
PAYME_KEY = os.getenv("PAYME_KEY", "TEST_PAYME_KEY")
PAYME_CHECKOUT_URL = os.getenv("PAYME_CHECKOUT_URL", "https://checkout.paycom.uz")
PAYME_SUBSCRIBE_URL = os.getenv("PAYME_SUBSCRIBE_URL", "https://checkout.paycom.uz/api")
PAYME_ACCOUNT_FIELD = os.getenv("PAYME_ACCOUNT_FIELD", "order_id")
CLICK_SERVICE_ID = os.getenv("CLICK_SERVICE_ID", "TEST_CLICK_SERVICE_ID")
CLICK_MERCHANT_ID = os.getenv("CLICK_MERCHANT_ID", "TEST_CLICK_MERCHANT_ID")
CLICK_MERCHANT_USER_ID = os.getenv("CLICK_MERCHANT_USER_ID", "TEST_CLICK_MERCHANT_USER_ID")
CLICK_SECRET_KEY = os.getenv("CLICK_SECRET_KEY", "TEST_CLICK_SECRET_KEY")
CLICK_CHECKOUT_URL = os.getenv("CLICK_CHECKOUT_URL", "https://my.click.uz/services/pay")
PAYMENT_RETURN_URL = os.getenv("PAYMENT_RETURN_URL", f"{SERVER_BASE_URL}/payment/return")

# ─── PLATFORMA KOMISSIYASI ────────────────────────────────────────────
PLATFORM_COMMISSION_RATE = float(os.getenv("PLATFORM_COMMISSION_RATE", "0.02"))  # 2%

# ─── LOYALTY TIZIMI ──────────────────────────────────────────────────
LOYALTY_STAMPS_FOR_REWARD = 10
LOYALTY_STAMP_EXPIRY_DAYS = 180
LOYALTY_REWARD_EXPIRY_DAYS = 30
LOYALTY_REWARD_MAX_VALUE = 100000

# ─── REFERRAL TIZIMI ─────────────────────────────────────────────────
REFERRAL_REWARD_AMOUNT = float(os.getenv("REFERRAL_REWARD_AMOUNT", "10000"))
REFERRAL_MAX_COUNT = 20

# ─── FIREBASE (Push Notification) ──────────────────────────────────────────
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
FIREBASE_ENABLED = os.path.exists(FIREBASE_CREDENTIALS_PATH)

# ─── EMAIL (Gmail SMTP SSL port 465) ───────────────────────────────────────
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_SENDER_NAME = os.getenv("SMTP_SENDER_NAME", "Sartaroshxona")

# ─── SMS (Eskiz.uz API) ───────────────────────────────────────────────────
ESKIZ_EMAIL = os.getenv("ESKIZ_EMAIL", "")
ESKIZ_PASSWORD = os.getenv("ESKIZ_PASSWORD", "")
ESKIZ_SENDER_HEADER = os.getenv("ESKIZ_SENDER_HEADER", "4546")

# ─── AUTH SOZLAMALARI ─────────────────────────────────────────────────────
OTP_EXPIRY_MINUTES = 10
OTP_MAX_ATTEMPTS = 5
PASSWORD_MIN_LENGTH = 8
LOGIN_MAX_ATTEMPTS = 5
LOGIN_BLOCK_MINUTES = 15

# ─── DATABASE ───────────────────────────────────────────────────────────────────────
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "0000"),
    "db": os.getenv("DB_NAME", "sartaroshxona_db"),
    "autocommit": False,
    "minsize": 2,
    "maxsize": 10,
}

# ─── AIVEN SSL (SSL majburiy bo'lganda) ────────────────────────────────────────
# ssl.create_default_context() Python 3.14 + aiomysql da ishlamaydi.
# ssl.SSLContext(PROTOCOL_TLS_CLIENT) ishlatiladi — bu Aiven bilan mos keladi.
if os.getenv("DB_HOST") and "aiven" in os.getenv("DB_HOST", ""):
    try:
        ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE
    except AttributeError:
        # Eski Python versiyalari uchun fallback
        ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS)  # type: ignore
        ssl_ctx.verify_mode = ssl.CERT_NONE
    DB_CONFIG["ssl"] = ssl_ctx
    print(f"[DB] Aiven SSL yoqildi: {os.getenv('DB_HOST')}")
