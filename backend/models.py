# =====================================================
# MODELS — Barcha Pydantic modellar
# =====================================================

from typing import Optional
from pydantic import BaseModel, EmailStr


# ─── AUTH ────────────────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    role: str
    phone: str
    experience: Optional[str] = None
    specialization: Optional[str] = None
    bio: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    # Owner (sartaroshxona egasi) uchun
    salon_name: Optional[str] = None
    salon_address: Optional[str] = None
    also_barber: bool = False


class UserLogin(BaseModel):
    email: str
    password: str


class ChangePassword(BaseModel):
    user_id: int
    old_password: str
    new_password: str


# ─── BARBER ──────────────────────────────────────────────────────────────────

class UpdateProfile(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    bio: Optional[str] = None
    specialization: Optional[str] = None
    experience: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None


class BlockedSlot(BaseModel):
    barber_id: int
    blocked_date: str
    start_time: str
    end_time: str
    reason: Optional[str] = ""


# ─── APPOINTMENTS ────────────────────────────────────────────────────────────

class AppointmentCreate(BaseModel):
    customer_id: int
    barber_id: int
    service_id: Optional[int] = None
    appointment_time: str
    service_name: str
    price: float
    notes: Optional[str] = ""


# ─── REVIEWS ─────────────────────────────────────────────────────────────────

class ReviewCreate(BaseModel):
    appointment_id: int
    customer_id: int
    barber_id: int
    rating: int
    comment: Optional[str] = ""


# ─── PAYMENTS ────────────────────────────────────────────────────────────────

class PaymentCreate(BaseModel):
    appointment_id: int
    amount: float
    method: str


class CheckoutRequest(BaseModel):
    appointment_id: int
    gateway: str  # 'payme' yoki 'click'


class CardCreate(BaseModel):
    number: str        # karta raqami (16 raqam)
    expire: str        # YYMM yoki MMYY (Payme formati: "MMYY")


class CardTokenAction(BaseModel):
    token: str


class CardVerify(BaseModel):
    token: str
    code: str


class CardPay(BaseModel):
    appointment_id: int
    token: str


# ─── CRM: SALON MODELLARI ───────────────────────────────────────────────────

class SalonCreate(BaseModel):
    name: str
    description: Optional[str] = None
    address: Optional[str] = None
    district: str = "Toshkent"
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None


class SalonUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    district: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None


class StaffInvite(BaseModel):
    barber_id: Optional[int] = None
    barber_email: Optional[EmailStr] = None
    message: Optional[str] = ""


class JoinRequest(BaseModel):
    salon_id: int
    message: Optional[str] = ""


class InvitationResponse(BaseModel):
    accept: bool


# ─── CHAT ────────────────────────────────────────────────────────────────────

class MessageCreate(BaseModel):
    sender_id: int
    receiver_id: int
    body: str


# ─── LOYALTY ─────────────────────────────────────────────────────────────────

class RedeemReward(BaseModel):
    customer_id: int
    reward_code: str
    appointment_id: int


# ─── REFERRAL ────────────────────────────────────────────────────────────────

class ReferralApply(BaseModel):
    referral_code: str


class RegisterWithReferral(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    role: str
    phone: str
    referral_code: Optional[str] = None
    experience: Optional[str] = None
    specialization: Optional[str] = None
    bio: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    salon_name: Optional[str] = None
    salon_address: Optional[str] = None
    also_barber: bool = False


# ─── PUSH NOTIFICATION ───────────────────────────────────────────────────────

class DeviceRegister(BaseModel):
    user_id: int
    fcm_token: str
    device_type: str = "android"  # 'android' yoki 'ios'


# ─── PAYMENT (yangilangan — komissiya bilan) ─────────────────────────────────

class PaymentWithCommission(BaseModel):
    appointment_id: int
    amount: float
    method: str
    accept_commission: bool = False  # Foydalanuvchi komissiyaga rozilik berdi


# ─── AUTH (yangilangan) ──────────────────────────────────────────────────────

class VerifyEmail(BaseModel):
    email: str
    code: str


class ForgotPassword(BaseModel):
    email: str


class ResetPassword(BaseModel):
    email: str
    code: str
    new_password: str


class TokenRefresh(BaseModel):
    token: str
