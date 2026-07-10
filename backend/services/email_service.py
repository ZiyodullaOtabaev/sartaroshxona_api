# =====================================================
# EMAIL SERVICE — Resend HTTP API orqali email yuborish
# SMTP kerak emas — Render'da ishlaydi
# =====================================================

import random
import string

import httpx

from config import RESEND_API_KEY, RESEND_SENDER_EMAIL, RESEND_SENDER_NAME


def generate_otp(length: int = 6) -> str:
    """6 xonali tasodifiy raqamli kod yaratish."""
    return "".join(random.choices(string.digits, k=length))


def _is_configured() -> bool:
    """Resend API sozlanganmi?"""
    return bool(RESEND_API_KEY)


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
    return await _send_email(to_email, subject, html)


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
    return await _send_email(to_email, subject, html)


async def _send_email(to_email: str, subject: str, html_body: str) -> bool:
    """Resend HTTP API orqali email yuborish."""
    if not _is_configured():
        print(f"[Email] Resend sozlanmagan — Development rejim (kod konsolga chiqadi)")
        return True

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "from": f"{RESEND_SENDER_NAME} <{RESEND_SENDER_EMAIL}>",
                    "to": [to_email],
                    "subject": subject,
                    "html": html_body,
                },
            )

        if response.status_code in (200, 201):
            print(f"[Email] Yuborildi: {to_email}")
            return True
        else:
            print(f"[Email] Resend xatolik ({response.status_code}): {response.text[:200]}")
            return False
    except Exception as e:
        print(f"[Email] Xatolik ({to_email}): {e}")
        return False
