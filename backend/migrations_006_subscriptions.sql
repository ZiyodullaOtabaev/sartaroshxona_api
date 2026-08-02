# =====================================================
# MIGRATION 006 — Obuna va Tariflar tizimi (Subscriptions)
# =====================================================

-- barbers jadvaliga obuna ustunlarini qo'shish
ALTER TABLE barbers ADD COLUMN IF NOT EXISTS subscription_tier VARCHAR(20) DEFAULT 'trial';
ALTER TABLE barbers ADD COLUMN IF NOT EXISTS subscription_expires_at DATETIME DEFAULT (NOW() + INTERVAL 30 DAY);
ALTER TABLE barbers ADD COLUMN IF NOT EXISTS is_vip BOOLEAN DEFAULT FALSE;

-- salons jadvaliga obuna ustunlarini qo'shish
ALTER TABLE salons ADD COLUMN IF NOT EXISTS subscription_tier VARCHAR(20) DEFAULT 'trial';
ALTER TABLE salons ADD COLUMN IF NOT EXISTS subscription_expires_at DATETIME DEFAULT (NOW() + INTERVAL 30 DAY);

-- Obuna to'lovlari va xaridlari jadvali
CREATE TABLE IF NOT EXISTS subscriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    barber_id INT,
    salon_id INT,
    plan_key VARCHAR(30) NOT NULL, -- 'standard_month', 'vip_month', 'salon_month'
    amount DECIMAL(10,2) NOT NULL,
    months INT DEFAULT 1,
    status ENUM('active', 'expired', 'cancelled') DEFAULT 'active',
    payment_method VARCHAR(20) DEFAULT 'payme',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
