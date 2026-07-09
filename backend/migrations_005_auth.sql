-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION 005: Professional Auth — Email OTP, Password Reset, Rate Limiting
-- Ishlatish: MySQL Workbench'da BIR MARTA run qiling.
-- ═══════════════════════════════════════════════════════════════════════════

USE sartaroshxona_db;

-- 1. EMAIL TASDIQLASH (OTP)
CREATE TABLE IF NOT EXISTS email_verifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    email VARCHAR(120) NOT NULL,
    code VARCHAR(6) NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    attempts INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_email_code (email, code),
    INDEX idx_user_verify (user_id, is_verified)
);

-- 2. PAROLNI TIKLASH
CREATE TABLE IF NOT EXISTS password_resets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    email VARCHAR(120) NOT NULL,
    code VARCHAR(6) NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    attempts INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_reset_email (email, code),
    INDEX idx_reset_user (user_id, is_used)
);

-- 3. LOGIN URINISHLARI (rate limiting)
CREATE TABLE IF NOT EXISTS login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(120) NOT NULL,
    ip_address VARCHAR(45),
    is_success BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_attempts_email (email, created_at),
    INDEX idx_attempts_ip (ip_address, created_at)
);

-- 4. users jadvaliga email_verified ustuni
ALTER TABLE users
    ADD COLUMN email_verified BOOLEAN DEFAULT FALSE AFTER email;

-- 5. Mavjud foydalanuvchilarni tasdiqlangan deb belgilash
UPDATE users SET email_verified = TRUE;
