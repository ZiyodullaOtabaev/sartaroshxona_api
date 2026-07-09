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

# ─── TO'LOV TIZIMLARI (Payme / Click) ────────────────────────────────────────
# DIQQAT: bu qiymatlar test/placeholder. Haqiqiy kalitlarni .env orqali bering.
# Payme
PAYME_MERCHANT_ID = os.getenv("PAYME_MERCHANT_ID", "TEST_PAYME_MERCHANT_ID")
PAYME_KEY = os.getenv("PAYME_KEY", "TEST_PAYME_KEY")
PAYME_CHECKOUT_URL = os.getenv("PAYME_CHECKOUT_URL", "https://checkout.paycom.uz")
# Payme Subscribe (Cards) API — ilova ichida karta bilan to'lash uchun
PAYME_SUBSCRIBE_URL = os.getenv("PAYME_SUBSCRIBE_URL", "https://checkout.paycom.uz/api")
# Payme receipts.create da ishlatiladigan hisob maydoni nomi (kabinetdagi bilan bir xil)
PAYME_ACCOUNT_FIELD = os.getenv("PAYME_ACCOUNT_FIELD", "order_id")
# Click
CLICK_SERVICE_ID = os.getenv("CLICK_SERVICE_ID", "TEST_CLICK_SERVICE_ID")
CLICK_MERCHANT_ID = os.getenv("CLICK_MERCHANT_ID", "TEST_CLICK_MERCHANT_ID")
CLICK_MERCHANT_USER_ID = os.getenv("CLICK_MERCHANT_USER_ID", "TEST_CLICK_MERCHANT_USER_ID")
CLICK_SECRET_KEY = os.getenv("CLICK_SECRET_KEY", "TEST_CLICK_SECRET_KEY")
CLICK_CHECKOUT_URL = os.getenv("CLICK_CHECKOUT_URL", "https://my.click.uz/services/pay")
# To'lovdan keyin qaytadigan manzil (web sahifa yoki deep link)
PAYMENT_RETURN_URL = os.getenv("PAYMENT_RETURN_URL", f"{SERVER_BASE_URL}/payment/return")

# ─── PLATFORMA KOMISSIYASI ────────────────────────────────────────────────────
PLATFORM_COMMISSION_RATE = float(os.getenv("PLATFORM_COMMISSION_RATE", "0.02"))  # 2%

# ─── LOYALTY TIZIMI ──────────────────────────────────────────────────────────
LOYALTY_STAMPS_FOR_REWARD = 10          # 10 stamp = 1 bepul navbat
LOYALTY_STAMP_EXPIRY_DAYS = 180         # Stamp 6 oy ichida yig'ilishi kerak
LOYALTY_REWARD_EXPIRY_DAYS = 30         # Bepul navbat kodi 30 kun amal qiladi
LOYALTY_REWARD_MAX_VALUE = 100000       # Bepul navbat maks qiymati (so'm)

# ─── REFERRAL TIZIMI ─────────────────────────────────────────────────────────
REFERRAL_REWARD_AMOUNT = float(os.getenv("REFERRAL_REWARD_AMOUNT", "10000"))  # 10,000 so'm
REFERRAL_MAX_COUNT = 20                 # Maksimal taklif soni

# ─── FIREBASE (Push Notification) ────────────────────────────────────────────
# Firebase Admin SDK — service account JSON fayli yo'li
# Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
FIREBASE_ENABLED = os.path.exists(FIREBASE_CREDENTIALS_PATH)

# ─── EMAIL SMTP ───────────────────────────────────────────────────────────────
# Gmail SMTP — bepul, 500 xabar/kun
# App Password olish: https://myaccount.google.com/apppasswords
# (2FA yoqilgan bo'lishi kerak)
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")  # Gmail manzilingiz
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")  # App Password (16 belgi)
SMTP_SENDER_EMAIL = os.getenv("SMTP_SENDER_EMAIL", "")  # = SMTP_USER bilan bir xil
SMTP_SENDER_NAME = os.getenv("SMTP_SENDER_NAME", "Sartaroshxona")

# ─── AUTH SOZLAMALARI ─────────────────────────────────────────────────────────
OTP_EXPIRY_MINUTES = 10              # OTP kodi 10 daqiqa amal qiladi
OTP_MAX_ATTEMPTS = 5                 # OTP tekshirish urinishlari
PASSWORD_MIN_LENGTH = 8              # Minimum parol uzunligi
LOGIN_MAX_ATTEMPTS = 5               # Login urinishlari limiti
LOGIN_BLOCK_MINUTES = 15             # Noto'g'ri logindan keyin bloklash vaqti

# ─── DATABASE ────────────────────────────────────────────────────────────────

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

if os.getenv("DB_HOST") and "aiven" in os.getenv("DB_HOST", ""):
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE
    DB_CONFIG["ssl"] = ssl_ctx
