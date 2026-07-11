# =====================================================
# EMAIL SERVICE — Gmail SMTP (port 465 SSL) orqali email yuborish
# =====================================================

import smtplib
import random
import string
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from config import SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_SENDER_NAME


def generate_otp(length: int = 6) -> str:
    """6 xonali tasodifiy raqamli kod yaratish."""
    return "".join(random.choices(string.digits, k=length))


def _is_configured() -> bool:
    return bool(SMTP_USER and SMTP_PASSWORD)


async def send_verification_email(to_email: str, code: str, user_name: str = "") -> bool:
    subject = "Sartaroshxona — Email tasdiqlash kodi"
    html = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#f9fafb;border-radius:16px;">
        <div style="text-align:center;margin-bottom:24px;">
            <h2 style="color:#1a1a2e;margin:0;">Sartaroshxona</h2>
        </div>
        <div style="background:white;padding:24px;border-radius:12px;text-align:center;">
            <p style="color:#333;">Assalomu alaykum{', ' + user_name if user_name else ''}!</p>
            <p style="color:#666;">Tasdiqlash kodingiz:</p>
            <div style="background:#f0f9f4;border:2px dashed #2ecc71;border-radius:12px;padding:16px;margin:16px 0;">
                <span style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#2ecc71;">{code}</span>
            </div>
            <p style="color:#999;font-size:12px;">Kod 10 daqiqa amal qiladi.</p>
        </div>
    </div>
    """
    return _send_email(to_email, subject, html)


async def send_password_reset_email(to_email: str, code: str, user_name: str = "") -> bool:
    subject = "Sartaroshxona — Parolni tiklash"
    html = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#f9fafb;border-radius:16px;">
        <div style="text-align:center;margin-bottom:24px;">
            <h2 style="color:#1a1a2e;margin:0;">Sartaroshxona</h2>
        </div>
        <div style="background:white;padding:24px;border-radius:12px;text-align:center;">
            <p style="color:#333;">Assalomu alaykum{', ' + user_name if user_name else ''}!</p>
            <p style="color:#666;">Parol tiklash kodingiz:</p>
            <div style="background:#fef3f2;border:2px dashed #e74c3c;border-radius:12px;padding:16px;margin:16px 0;">
                <span style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#e74c3c;">{code}</span>
            </div>
            <p style="color:#999;font-size:12px;">Kod 10 daqiqa amal qiladi.</p>
        </div>
    </div>
    """
    return _send_email(to_email, subject, html)


def _send_email(to_email: str, subject: str, html_body: str) -> bool:
    if not _is_configured():
        print(f"[Email] SMTP sozlanmagan — skip")
        return True

    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"{SMTP_SENDER_NAME} <{SMTP_USER}>"
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(html_body, "html"))

        # Port 465 — SSL (SMTPS)
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, to_email, msg.as_string())

        print(f"[Email] Yuborildi: {to_email}")
        return True
    except Exception as e:
        print(f"[Email] Xatolik ({to_email}): {e}")
        return False
