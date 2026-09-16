# =====================================================
# DATABASE — Connection pool, helper funksiyalar
# asyncmy ishlatiladi (aiomysql o'rniga) — Python 3.14 + Aiven SSL uchun
# =====================================================

import os
import ssl
import math
import datetime

import asyncmy

from config import DB_CONFIG

# =====================================================
# CONNECTION POOL
# =====================================================

pool: asyncmy.Pool = None


def _build_ssl():
    """
    Aiven uchun SSL context.
    asyncmy ssl.SSLContext ni to'g'ri qo'llab-quvvatlaydi.
    check_hostname=False + CERT_NONE => sertifikat tekshirilmaydi.
    """
    host = os.getenv("DB_HOST", "")
    if "aiven" not in host:
        return None

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    print(f"[DB] Aiven SSL context yaratildi (CERT_NONE)")
    return ctx


async def create_pool():
    """DB connection pool yaratish (lifespan boshida chaqiriladi)."""
    global pool

    ssl_ctx = _build_ssl()
    print(f"[DB] Ulanish: host={DB_CONFIG['host']}, port={DB_CONFIG['port']}, ssl={'bor' if ssl_ctx else 'yo\'q'}")

    pool_config = {
        "host": DB_CONFIG["host"],
        "port": DB_CONFIG["port"],
        "user": DB_CONFIG["user"],
        "password": DB_CONFIG["password"],
        "db": DB_CONFIG["db"],
        "autocommit": DB_CONFIG["autocommit"],
        "minsize": DB_CONFIG["minsize"],
        "maxsize": DB_CONFIG["maxsize"],
    }

    if ssl_ctx is not None:
        pool_config["ssl"] = ssl_ctx

    pool = await asyncmy.create_pool(**pool_config)
    print("[DB] Connection pool muvaffaqiyatli yaratildi ✅")
    return pool


async def close_pool():
    """Pool'ni yopish (lifespan oxirida chaqiriladi)."""
    global pool
    if pool:
        pool.close()
        await pool.wait_closed()


async def init_tables():
    """Zarur jadvallarni avtomatik yaratish (idempotent)."""
    global pool
    try:
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS users ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "full_name VARCHAR(100) NOT NULL, "
                    "email VARCHAR(120) NULL, "
                    "email_verified BOOLEAN DEFAULT FALSE, "
                    "password_hash VARCHAR(255) NULL, "
                    "role ENUM('customer','barber','owner') NOT NULL DEFAULT 'customer', "
                    "avatar_url VARCHAR(255), "
                    "phone VARCHAR(30), "
                    "firebase_uid VARCHAR(128) NULL, "
                    "loyalty_points INT DEFAULT 0, "
                    "referral_code VARCHAR(20) UNIQUE, "
                    "referral_balance DECIMAL(10,2) DEFAULT 0, "
                    "referred_by INT NULL, "
                    "referral_count INT DEFAULT 0, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS barbers ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "user_id INT NOT NULL UNIQUE, "
                    "salon_id INT NULL, "
                    "name VARCHAR(100) NOT NULL, "
                    "experience VARCHAR(100), "
                    "phone VARCHAR(30), "
                    "specialization VARCHAR(150), "
                    "bio TEXT, "
                    "lat DOUBLE, lng DOUBLE, "
                    "district VARCHAR(100) DEFAULT 'Toshkent', "
                    "subscription_tier VARCHAR(20) DEFAULT 'trial', "
                    "subscription_expires_at DATETIME DEFAULT NULL, "
                    "is_vip BOOLEAN DEFAULT FALSE, "
                    "rating FLOAT DEFAULT 5.0, "
                    "total_reviews INT DEFAULT 0, "
                    "is_online BOOLEAN DEFAULT TRUE, "
                    "is_accepting_bookings BOOLEAN DEFAULT TRUE, "
                    "verification_status ENUM('pending','approved','rejected') DEFAULT 'pending', "
                    "avatar_url VARCHAR(255), "
                    "working_hours_start TIME DEFAULT '09:00:00', "
                    "working_hours_end TIME DEFAULT '20:00:00', "
                    "slot_duration_minutes INT DEFAULT 30, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS salons ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "owner_id INT NOT NULL, "
                    "name VARCHAR(150) NOT NULL, "
                    "description TEXT, "
                    "address VARCHAR(255), "
                    "district VARCHAR(100) DEFAULT 'Toshkent', "
                    "lat DOUBLE, lng DOUBLE, "
                    "phone VARCHAR(30), "
                    "avatar_url VARCHAR(255), "
                    "cover_url VARCHAR(255), "
                    "working_hours_start TIME DEFAULT '09:00:00', "
                    "working_hours_end TIME DEFAULT '20:00:00', "
                    "rating FLOAT DEFAULT 5.0, "
                    "total_reviews INT DEFAULT 0, "
                    "subscription_tier VARCHAR(20) DEFAULT 'trial', "
                    "subscription_expires_at DATETIME DEFAULT NULL, "
                    "is_active BOOLEAN DEFAULT TRUE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS barber_services ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "barber_id INT NOT NULL, "
                    "service_name VARCHAR(100) NOT NULL, "
                    "price DECIMAL(10,2) NOT NULL, "
                    "duration_minutes INT DEFAULT 30, "
                    "description VARCHAR(255), "
                    "is_active BOOLEAN DEFAULT TRUE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS appointments ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "customer_id INT NOT NULL, "
                    "barber_id INT NOT NULL, "
                    "service_id INT, "
                    "appointment_time DATETIME NOT NULL, "
                    "end_time DATETIME, "
                    "service_name VARCHAR(100), "
                    "price DECIMAL(10,2) DEFAULT 0, "
                    "commission_amount DECIMAL(10,2) DEFAULT 0, "
                    "total_charged DECIMAL(10,2) DEFAULT 0, "
                    "status ENUM('pending','confirmed','cancelled','completed') DEFAULT 'pending', "
                    "payment_status ENUM('unpaid','paid','refunded') DEFAULT 'unpaid', "
                    "payment_method ENUM('cash','card','click','payme','loyalty') DEFAULT 'cash', "
                    "notes TEXT, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (service_id) REFERENCES barber_services(id) ON DELETE SET NULL"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS reviews ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "appointment_id INT NOT NULL, "
                    "customer_id INT NOT NULL, "
                    "barber_id INT NOT NULL, "
                    "rating INT NOT NULL, "
                    "comment TEXT, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS payments ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "appointment_id INT NOT NULL, "
                    "amount DECIMAL(10,2) NOT NULL, "
                    "platform_fee DECIMAL(10,2) DEFAULT 0, "
                    "barber_amount DECIMAL(10,2) DEFAULT 0, "
                    "method ENUM('cash','card','click','payme') NOT NULL, "
                    "status ENUM('pending','completed','failed','refunded') DEFAULT 'pending', "
                    "transaction_id VARCHAR(120), "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS notifications ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "user_id INT NOT NULL, "
                    "title VARCHAR(100) NOT NULL, "
                    "body TEXT NOT NULL, "
                    "type ENUM('appointment','payment','promotion','system') DEFAULT 'system', "
                    "is_read BOOLEAN DEFAULT FALSE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS barber_blocked_slots ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "barber_id INT NOT NULL, "
                    "blocked_date DATE NOT NULL, "
                    "start_time TIME NOT NULL, "
                    "end_time TIME NOT NULL, "
                    "reason VARCHAR(150), "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS barber_working_days ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "barber_id INT NOT NULL, "
                    "day_of_week TINYINT NOT NULL, "
                    "is_working BOOLEAN DEFAULT TRUE, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS favorites ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "customer_id INT NOT NULL, "
                    "barber_id INT NOT NULL, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "UNIQUE KEY unique_favorite (customer_id, barber_id), "
                    "FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS salon_invitations ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "salon_id INT NOT NULL, "
                    "barber_id INT NOT NULL, "
                    "initiated_by ENUM('owner','barber') NOT NULL, "
                    "status ENUM('pending','accepted','rejected','cancelled') DEFAULT 'pending', "
                    "message VARCHAR(255), "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "responded_at TIMESTAMP NULL, "
                    "FOREIGN KEY (salon_id) REFERENCES salons(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS hairstyles ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "barber_id INT NOT NULL, "
                    "name VARCHAR(100) NOT NULL, "
                    "description VARCHAR(255), "
                    "image_url VARCHAR(500), "
                    "is_active BOOLEAN DEFAULT TRUE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (barber_id) REFERENCES barbers(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS messages ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "sender_id INT NOT NULL, "
                    "receiver_id INT NOT NULL, "
                    "body TEXT NOT NULL, "
                    "is_read BOOLEAN DEFAULT FALSE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "INDEX idx_pair (sender_id, receiver_id), "
                    "FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS gateway_transactions ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "gateway VARCHAR(10) NOT NULL, "
                    "order_id INT NOT NULL, "
                    "amount BIGINT NOT NULL, "
                    "state INT NOT NULL DEFAULT 0, "
                    "provider_trans_id VARCHAR(64), "
                    "create_time BIGINT DEFAULT 0, "
                    "perform_time BIGINT DEFAULT 0, "
                    "cancel_time BIGINT DEFAULT 0, "
                    "reason INT DEFAULT NULL, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "INDEX idx_order (order_id), "
                    "INDEX idx_provider (gateway, provider_trans_id)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS loyalty_stamps ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "customer_id INT NOT NULL, "
                    "appointment_id INT NOT NULL, "
                    "earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "expires_at TIMESTAMP NOT NULL, "
                    "is_used BOOLEAN DEFAULT FALSE, "
                    "FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE, "
                    "UNIQUE KEY unique_stamp (appointment_id, customer_id), "
                    "INDEX idx_stamps_customer (customer_id, is_used, expires_at)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS loyalty_rewards ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "customer_id INT NOT NULL, "
                    "reward_code VARCHAR(20) NOT NULL UNIQUE, "
                    "max_value DECIMAL(10,2) DEFAULT 100000, "
                    "is_redeemed BOOLEAN DEFAULT FALSE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "expires_at TIMESTAMP NOT NULL, "
                    "redeemed_at TIMESTAMP NULL, "
                    "redeemed_appointment_id INT NULL, "
                    "FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "INDEX idx_rewards_customer (customer_id, is_redeemed)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS referrals ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "referrer_id INT NOT NULL, "
                    "referred_id INT NOT NULL, "
                    "referral_code VARCHAR(20) NOT NULL, "
                    "status ENUM('pending','completed','expired') DEFAULT 'pending', "
                    "reward_amount DECIMAL(10,2) DEFAULT 10000, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "completed_at TIMESTAMP NULL, "
                    "FOREIGN KEY (referrer_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "FOREIGN KEY (referred_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "UNIQUE KEY unique_referral (referred_id), "
                    "INDEX idx_referrals_referrer (referrer_id, status)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS user_devices ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "user_id INT NOT NULL, "
                    "fcm_token VARCHAR(255) NOT NULL, "
                    "device_type ENUM('android','ios') DEFAULT 'android', "
                    "is_active BOOLEAN DEFAULT TRUE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, "
                    "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "UNIQUE KEY unique_token (fcm_token), "
                    "INDEX idx_devices_user (user_id, is_active)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS platform_earnings ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "payment_id INT NOT NULL, "
                    "appointment_id INT NOT NULL, "
                    "amount DECIMAL(10,2) NOT NULL, "
                    "commission_rate DECIMAL(4,2) DEFAULT 2.00, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "INDEX idx_earnings_date (created_at)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS email_verifications ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "user_id INT NOT NULL, "
                    "email VARCHAR(120) NOT NULL, "
                    "code VARCHAR(6) NOT NULL, "
                    "is_verified BOOLEAN DEFAULT FALSE, "
                    "attempts INT DEFAULT 0, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "expires_at TIMESTAMP NOT NULL, "
                    "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "INDEX idx_email_code (email, code), "
                    "INDEX idx_user_verify (user_id, is_verified)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS password_resets ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "user_id INT NOT NULL, "
                    "email VARCHAR(120) NOT NULL, "
                    "code VARCHAR(6) NOT NULL, "
                    "is_used BOOLEAN DEFAULT FALSE, "
                    "attempts INT DEFAULT 0, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "expires_at TIMESTAMP NOT NULL, "
                    "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, "
                    "INDEX idx_reset_email (email, code)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS login_attempts ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "email VARCHAR(120) NOT NULL, "
                    "ip_address VARCHAR(45), "
                    "is_success BOOLEAN DEFAULT FALSE, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "INDEX idx_attempts_email (email, created_at)"
                    ")"
                )
                await cur.execute(
                    "CREATE TABLE IF NOT EXISTS subscriptions ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "user_id INT NOT NULL, "
                    "barber_id INT, "
                    "salon_id INT, "
                    "plan_key VARCHAR(30) NOT NULL, "
                    "amount DECIMAL(10,2) NOT NULL, "
                    "months INT DEFAULT 1, "
                    "status ENUM('active', 'expired', 'cancelled') DEFAULT 'active', "
                    "payment_method VARCHAR(20) DEFAULT 'payme', "
                    "started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
                    "expires_at DATETIME NOT NULL, "
                    "FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE"
                    ")"
                )
                await conn.commit()
            print("[DB] Barcha jadvallar tayyor ✅")
    except Exception as e:
        print(f"[DB] Jadvallarni yaratishda ogohlantirish: {e}")


async def get_conn():
    """Pool'dan ulanish olish."""
    conn = await pool.acquire()
    try:
        await conn.rollback()
    except Exception:
        pass
    return conn


async def release_conn(conn):
    """Ulanishni pool'ga qaytarish."""
    pool.release(conn)


def haversine(lat1, lon1, lat2, lon2):
    """Ikki nuqta orasidagi masofani km da hisoblash."""
    if None in (lat1, lon1, lat2, lon2):
        return 0.0
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def timedelta_to_str(td):
    """timedelta yoki vaqtni 'HH:MM' formatga o'girish."""
    if td is None:
        return None
    if isinstance(td, datetime.timedelta):
        total = int(td.total_seconds())
        h = total // 3600
        m = (total % 3600) // 60
        return f"{h:02d}:{m:02d}"
    return str(td)
