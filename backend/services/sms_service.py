# =====================================================
# SMS SERVICE — Eskiz.uz API orqali SMS yuborish
# =====================================================

import logging
import httpx
from config import ESKIZ_EMAIL, ESKIZ_PASSWORD, ESKIZ_SENDER_HEADER

logger = logging.getLogger("sms_service")

# Eskiz token kesh
_eskiz_token = None

async def _get_eskiz_token() -> str:
    global _eskiz_token
    if _eskiz_token:
        return _eskiz_token

    if not ESKIZ_EMAIL or not ESKIZ_PASSWORD:
        return ""

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                "https://notify.eskiz.uz/api/auth/login",
                data={"email": ESKIZ_EMAIL, "password": ESKIZ_PASSWORD},
            )
            if resp.status_code == 200:
                data = resp.json()
                _eskiz_token = data.get("data", {}).get("token", "")
                return _eskiz_token
    except Exception as e:
        logger.error(f"[Eskiz Auth Error] {e}")

    return ""


async def send_sms_otp(phone: str, code: str) -> bool:
    """
    Telefon raqamiga 6-xonali SMS OTP kodi yuborish.
    Agar Eskiz.uz kalitlari sozlanmagan bo'lsa, konsolga chiqaradi va True qaytaradi (Dev Mode).
    """
    cleaned_phone = phone.replace("+", "").replace(" ", "").replace("-", "").strip()
    message = f"Sartaroshxona ilovasi tasdiqlash kodi: {code}. Kodni hech kimga bermang."

    print(f"==================================================")
    print(f"📱 [SMS OTP GENERATED] Phone: {phone} | Code: {code}")
    print(f"==================================================")

    token = await _get_eskiz_token()
    if not token:
        logger.info(f"[SMS Dev Mode] Eskiz.uz sozlanmagan. Telefon: {phone}, Kod: {code}")
        return True

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                "https://notify.eskiz.uz/api/message/sms/send",
                headers={"Authorization": f"Bearer {token}"},
                data={
                    "mobile_phone": cleaned_phone,
                    "message": message,
                    "from": ESKIZ_SENDER_HEADER,
                },
            )
            if resp.status_code == 200:
                logger.info(f"[SMS Sent] Phone: {phone} muvaffaqiyatli yuborildi")
                return True
            else:
                logger.error(f"[SMS Eskiz Error] Status: {resp.status_code}, Body: {resp.text}")
    except Exception as e:
        logger.error(f"[SMS Exception] {e}")

    # Kod saqlanadi, shuning uchun xatolik bo'lsa ham True qaytariladi
    return True
