# =====================================================
# AUTH — JWT, password hashing, security dependencies
# =====================================================

import datetime

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext

from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_HOURS

# =====================================================
# PASSWORD HASH
# =====================================================

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# =====================================================
# JWT TOKEN
# =====================================================

security = HTTPBearer(auto_error=False)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + datetime.timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token muddati tugagan")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Yaroqsiz token")


# =====================================================
# FASTAPI DEPENDENCIES
# =====================================================

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Ixtiyoriy autentifikatsiya — token bo'lmasa None qaytaradi."""
    if credentials is None:
        return None
    return verify_token(credentials.credentials)


async def require_auth(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Majburiy autentifikatsiya — token bo'lmasa 401."""
    if credentials is None:
        raise HTTPException(status_code=401, detail="Token talab qilinadi")
    return verify_token(credentials.credentials)


async def require_owner(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Faqat owner roli uchun — token bo'lmasa yoki roli noto'g'ri bo'lsa xatolik."""
    if credentials is None:
        raise HTTPException(status_code=401, detail="Token talab qilinadi")
    payload = verify_token(credentials.credentials)
    if payload.get("role") != "owner":
        raise HTTPException(status_code=403, detail="Bu amal faqat sartaroshxona egalari uchun")
    return payload
