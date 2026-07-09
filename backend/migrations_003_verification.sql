-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION 003: Sartarosh tasdiqlash (verification) tizimi
-- Ishlatish: MySQL Workbench'da BIR MARTA run qiling.
-- ═══════════════════════════════════════════════════════════════════════════

USE sartaroshxona_db;

-- 1. barbers jadvaliga verification_status ustuni
ALTER TABLE barbers
    ADD COLUMN verification_status ENUM('pending', 'approved', 'rejected')
    NOT NULL DEFAULT 'pending' AFTER is_accepting_bookings;

-- 2. Mavjud sartaroshlarni 'approved' qilish (grandfather — yo'qolib qolmasin)
UPDATE barbers SET verification_status = 'approved';

-- 3. Salonda ishlayotganlar har doim approved
UPDATE barbers SET verification_status = 'approved' WHERE salon_id IS NOT NULL;

-- 4. Tez filtrlash uchun index
CREATE INDEX idx_barbers_verification ON barbers(verification_status);
