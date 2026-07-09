-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION 004: Biznes logika — Komissiya, Loyalty, Referral, Push, DB fixes
-- Ishlatish: MySQL Workbench'da BIR MARTA run qiling.
-- ═══════════════════════════════════════════════════════════════════════════

USE sartaroshxona_db;

-- ═══════════════════════════════════════════════════════════════════════════
-- A. MAVJUD JADVALLAR TUZATISHLARI
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. reviews — dublikat oldini olish
ALTER TABLE reviews
    ADD UNIQUE KEY unique_review (appointment_id, customer_id);

-- 2. barber_working_days — bir kun uchun dublikat oldini olish
ALTER TABLE barber_working_days
    ADD UNIQUE KEY unique_barber_day (barber_id, day_of_week);

-- 3. appointments — status bo'yicha tezkor qidiruv
CREATE INDEX idx_appointments_barber_status
    ON appointments(barber_id, status, appointment_time);

-- 4. payments — komissiya ustunlari
ALTER TABLE payments
    ADD COLUMN platform_fee DECIMAL(10,2) DEFAULT 0 AFTER amount,
    ADD COLUMN barber_amount DECIMAL(10,2) DEFAULT 0 AFTER platform_fee;

-- 5. appointments — komissiya summasi
ALTER TABLE appointments
    ADD COLUMN commission_amount DECIMAL(10,2) DEFAULT 0 AFTER price,
    ADD COLUMN total_charged DECIMAL(10,2) DEFAULT 0 AFTER commission_amount;

-- ═══════════════════════════════════════════════════════════════════════════
-- B. LOYALTY TIZIMI (10 navbat = 1 bepul)
-- ═══════════════════════════════════════════════════════════════════════════

-- Har bir yakunlangan navbat = 1 stamp
CREATE TABLE IF NOT EXISTS loyalty_stamps (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    appointment_id INT NOT NULL,
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
    UNIQUE KEY unique_stamp (appointment_id, customer_id),
    INDEX idx_stamps_customer (customer_id, is_used, expires_at)
);

-- 10 stamp yig'ilganda beriladigan mukofot
CREATE TABLE IF NOT EXISTS loyalty_rewards (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    reward_code VARCHAR(20) NOT NULL UNIQUE,
    max_value DECIMAL(10,2) DEFAULT 100000,
    is_redeemed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    redeemed_at TIMESTAMP NULL,
    redeemed_appointment_id INT NULL,
    FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_rewards_customer (customer_id, is_redeemed)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- C. REFERRAL TIZIMI (do'stni taklif qil — ikkalaga chegirma)
-- ═══════════════════════════════════════════════════════════════════════════

-- users jadvaliga referral maydonlari
ALTER TABLE users
    ADD COLUMN referral_code VARCHAR(20) UNIQUE AFTER loyalty_points,
    ADD COLUMN referral_balance DECIMAL(10,2) DEFAULT 0 AFTER referral_code,
    ADD COLUMN referred_by INT NULL AFTER referral_balance,
    ADD COLUMN referral_count INT DEFAULT 0 AFTER referred_by;

-- Referral tarixi
CREATE TABLE IF NOT EXISTS referrals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    referrer_id INT NOT NULL,
    referred_id INT NOT NULL,
    referral_code VARCHAR(20) NOT NULL,
    status ENUM('pending', 'completed', 'expired') DEFAULT 'pending',
    reward_amount DECIMAL(10,2) DEFAULT 10000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    FOREIGN KEY (referrer_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (referred_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_referral (referred_id),
    INDEX idx_referrals_referrer (referrer_id, status)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- D. PUSH NOTIFICATION (FCM token saqlash)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS user_devices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    fcm_token VARCHAR(255) NOT NULL,
    device_type ENUM('android', 'ios') DEFAULT 'android',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_token (fcm_token),
    INDEX idx_devices_user (user_id, is_active)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- E. PLATFORMA DAROMADI — umumiy hisobot uchun
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS platform_earnings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id INT NOT NULL,
    appointment_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    commission_rate DECIMAL(4,2) DEFAULT 2.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
    INDEX idx_earnings_date (created_at)
);
