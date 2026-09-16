# =====================================================
# SMS SERVICE — Eskiz.uz API orqali SMS yuborish
# =====================================================

import time
import logging
import httpx
from config import ESKIZ_EMAIL, ESKIZ_PASSWORD, ESKIZ_SENDER_HEADER

logger = logging.getLogger("sms_service")

# Eskiz token kesh (muddati bilan)
_eskiz_token: str | None = None
_eskiz_token_expires_at: float = 0  # Unix timestamp

# Eskiz tokenlari 29 kunda eskiradi — 28 kundan keyin yangilaymiz
ESKIZ_TOKEN_TTL = 28 * 24 * 3600


async def _get_eskiz_token(force_refresh: bool = False) -> str:
    """Eskiz.uz access token olish (kesh bilan, muddati tekshirilib)."""
    global _eskiz_token, _eskiz_token_expires_at

    # Token hali amal qilayotgan bo'lsa — keshdan qaytarish
    if not force_refresh and _eskiz_token and time.time() < _eskiz_token_expires_at:
        return _eskiz_token

    if not ESKIZ_EMAIL or not ESKIZ_PASSWORD:
        logger.warning("[Eskiz] ESKIZ_EMAIL yoki ESKIZ_PASSWORD sozlanmagan. .env faylini tekshiring.")
        return ""

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                "https://notify.eskiz.uz/api/auth/login",
                data={"email": ESKIZ_EMAIL, "password": ESKIZ_PASSWORD},
            )
            if resp.status_code == 200:
                data = resp.json()
                token = data.get("data", {}).get("token", "")
                if token:
                    _eskiz_token = token
                    _eskiz_token_expires_at = time.time() + ESKIZ_TOKEN_TTL
                    logger.info("[Eskiz] Token muvaffaqiyatli yangilandi")
                    return _eskiz_token
            logger.error(f"[Eskiz Auth] Token olishda xatolik: {resp.status_code} — {resp.text}")
    except Exception as e:
        logger.error(f"[Eskiz Auth Exception] {e}")

    # Olishda xatolik — keshni tozalash
    _eskiz_token = None
    _eskiz_token_expires_at = 0
    return ""


async def _send_request(token: str, phone: str, message: str) -> bool:
    """Eskiz API ga SMS so'rovi yuborish."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            "https://notify.eskiz.uz/api/message/sms/send",
            headers={"Authorization": f"Bearer {token}"},
            data={
                "mobile_phone": phone,
                "message": message,
                "from": ESKIZ_SENDER_HEADER,
            },
        )
        return resp.status_code, resp


async def send_sms_otp(phone: str, code: str) -> bool:
    """
    Telefon raqamiga 6-xonali SMS OTP kodi yuborish.
    Agar Eskiz.uz kalitlari sozlanmagan bo'lsa, konsolga chiqaradi va True qaytaradi (Dev Mode).
    """
    cleaned_phone = phone.replace("+", "").replace(" ", "").replace("-", "").strip()
    message = f"Sartaroshxona ilovasi tasdiqlash kodi: {code}. Kodni hech kimga bermang."

    print(f"==================================================")
    print(f"\U0001f4f1 [SMS OTP GENERATED] Phone: {phone} | Code: {code}")
    print(f"==================================================")

    token = await _get_eskiz_token()
    if not token:
        logger.warning(
            f"[SMS Dev Mode] Eskiz.uz token yo'q. "
            f"Telefon: {phone}, Kod: {code}. "
            f"Render.com dashboard da ESKIZ_EMAIL va ESKIZ_PASSWORD ni sozlang."
        )
        return True

    try:
        status_code, resp = await _send_request(token, cleaned_phone, message)

        if status_code == 200:
            logger.info(f"[SMS Yuborildi] {phone}")
            return True

        if status_code == 401:
            # Token eskirgan — majburiy yangilash va qayta urinish
            logger.warning("[SMS] Token eskirgan (401). Yangilanmoqda...")
            new_token = await _get_eskiz_token(force_refresh=True)
            if new_token:
                status_code2, resp2 = await _send_request(new_token, cleaned_phone, message)
                if status_code2 == 200:
                    logger.info(f"[SMS Yuborildi (retry)] {phone}")
                    return True
                logger.error(f"[SMS Retry Xato] {status_code2} — {resp2.text}")
            else:
                logger.error("[SMS] Token yangilashda xatolik — SMS yuborilmadi")
        else:
            logger.error(f"[SMS Eskiz Xato] Status: {status_code}, Body: {resp.text}")

    except Exception as e:
        logger.error(f"[SMS Exception] {e}")

    # Kod DB da saqlanadi — True qaytariladi (foydalanuvchi qayta so'rashi mumkin)
    return True
