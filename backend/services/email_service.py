# =====================================================
# EMAIL SERVICE — Gmail SMTP orqali email yuborish
# =====================================================

import smtplib
import random
import string
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from config import (
    SMTP_HOST, SMTP_PORT,
    SMTP_USER, SMTP_PASSWORD,
    SMTP_SENDER_EMAIL, SMTP_SENDER_NAME,
)


def generate_otp(length: int = 6) -> str:
    """6 xonali tasodifiy raqamli kod yaratish."""
    return "".join(random.choices(string.digits, k=length))


def _is_configured() -> bool:
    """SMTP sozlanganmi?"""
    return bool(SMTP_USER and SMTP_PASSWORD)


async def send_verification_email(to_email: str, code: str, user_name: str = "") -> bool:
    """Email tasdiqlash kodi yuborish."""
    subject = "Sartaroshxona — Email tasdiqlash kodi"
    html = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#f9fafb;border-radius:16px;">
        <div style="text-align:center;margin-bottom:24px;">
            <h2 style="color:#1a1a2e;margin:0;">Sartaroshxona</h2>
            <p style="color:#666;font-size:14px;">Email tasdiqlash</p>
        </div>
        <div style="background:white;padding:24px;border-radius:12px;text-align:center;">
            <p style="color:#333;font-size:15px;">Assalomu alaykum{', ' + user_name if user_name else ''}!</p>
            <p style="color:#666;font-size:14px;">Tasdiqlash kodingiz:</p>
            <div style="background:#f0f9f4;border:2px dashed #2ecc71;border-radius:12px;padding:16px;margin:16px 0;">
                <span style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#2ecc71;">{code}</span>
            </div>
            <p style="color:#999;font-size:12px;">Kod 10 daqiqa ichida amal qiladi.</p>
            <p style="color:#999;font-size:12px;">Agar siz ro'yxatdan o'tmagan bo'lsangiz, bu xabarni e'tiborsiz qoldiring.</p>
        </div>
    </div>
    """
    return _send_email(to_email, subject, html)


async def send_password_reset_email(to_email: str, code: str, user_name: str = "") -> bool:
    """Parol tiklash kodi yuborish."""
    subject = "Sartaroshxona — Parolni tiklash"
    html = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#f9fafb;border-radius:16px;">
        <div style="text-align:center;margin-bottom:24px;">
            <h2 style="color:#1a1a2e;margin:0;">Sartaroshxona</h2>
            <p style="color:#666;font-size:14px;">Parolni tiklash</p>
        </div>
        <div style="background:white;padding:24px;border-radius:12px;text-align:center;">
            <p style="color:#333;font-size:15px;">Assalomu alaykum{', ' + user_name if user_name else ''}!</p>
            <p style="color:#666;font-size:14px;">Parolingizni tiklash uchun quyidagi kodni kiriting:</p>
            <div style="background:#fef3f2;border:2px dashed #e74c3c;border-radius:12px;padding:16px;margin:16px 0;">
                <span style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#e74c3c;">{code}</span>
            </div>
            <p style="color:#999;font-size:12px;">Kod 10 daqiqa ichida amal qiladi.</p>
            <p style="color:#999;font-size:12px;">Agar siz parolni tiklamoqchi bo'lmagan bo'lsangiz, bu xabarni e'tiborsiz qoldiring.</p>
        </div>
    </div>
    """
    return _send_email(to_email, subject, html)


def _send_email(to_email: str, subject: str, html_body: str) -> bool:
    """SMTP orqali email yuborish."""
    if not _is_configured():
        print(f"[Email] SMTP sozlanmagan — Development rejim (kod konsolga chiqadi)")
        return True  # Development'da xatolik bermaslik uchun

    try:
        sender = SMTP_SENDER_EMAIL or SMTP_USER
        msg = MIMEMultipart("alternative")
        msg["From"] = f"{SMTP_SENDER_NAME} <{sender}>"
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(sender, to_email, msg.as_string())

        print(f"[Email] Yuborildi: {to_email}")
        return True
    except Exception as e:
        print(f"[Email] Xatolik ({to_email}): {e}")
        return False
