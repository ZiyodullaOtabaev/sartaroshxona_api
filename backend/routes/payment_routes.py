# =====================================================
# PAYMENT ROUTES — payments, checkout, Payme/Click callbacks, card payments
# =====================================================

import time
import datetime
import base64
import hashlib

import aiomysql
import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse

from config import (
    PAYME_MERCHANT_ID, PAYME_KEY, PAYME_CHECKOUT_URL,
    PAYME_SUBSCRIBE_URL, PAYME_ACCOUNT_FIELD,
    CLICK_SERVICE_ID, CLICK_MERCHANT_ID, CLICK_SECRET_KEY,
    CLICK_CHECKOUT_URL, PAYMENT_RETURN_URL,
    PLATFORM_COMMISSION_RATE,
)
from database import get_conn, release_conn
from models import PaymentCreate, PaymentWithCommission, CheckoutRequest, CardCreate, CardTokenAction, CardVerify, CardPay

router = APIRouter()

# ─── ERROR MESSAGES ──────────────────────────────────────────────────────────

_ORDER_NOT_FOUND = {"uz": "Buyurtma topilmadi", "ru": "Заказ не найден", "en": "Order not found"}
_INVALID_AMOUNT = {"uz": "Noto'g'ri summa", "ru": "Неверная сумма", "en": "Invalid amount"}
_CANT_PERFORM = {"uz": "Operatsiyani bajarib bo'lmaydi", "ru": "Невозможно выполнить операцию", "en": "Unable to perform operation"}
_TX_NOT_FOUND = {"uz": "Tranzaksiya topilmadi", "ru": "Транзакция не найдена", "en": "Transaction not found"}


def _payme_error(req_id, code, message, data=None):
    err = {"code": code, "message": message}
    if data is not None:
        err["data"] = data
    return {"error": err, "id": req_id}


def _click_sign(*parts):
    return hashlib.md5("".join("" if p is None else str(p) for p in parts).encode()).hexdigest()


async def _gw_mark_paid(cur, order_id: int, method: str):
    """Buyurtmani 'paid' qilish + payments + komissiya + loyalty + bildirishnoma."""
    await cur.execute("SELECT price, commission_amount, total_charged, customer_id, payment_status FROM appointments WHERE id=%s", (order_id,))
    appt = await cur.fetchone()
    if not appt or appt['payment_status'] == 'paid':
        return
    price = float(appt['price'] or 0)
    commission = float(appt['commission_amount'] or 0)
    total = float(appt['total_charged'] or price)
    barber_amount = price
    platform_fee = commission

    await cur.execute(
        "INSERT INTO payments (appointment_id, amount, platform_fee, barber_amount, method, status, transaction_id) "
        "VALUES (%s,%s,%s,%s,%s,'completed',%s)",
        (order_id, total, platform_fee, barber_amount, method, f"{method.upper()}-{order_id}-{int(time.time())}"),
    )
    payment_id = cur.lastrowid
    await cur.execute("UPDATE appointments SET payment_status='paid', payment_method=%s WHERE id=%s", (method, order_id))

    # Platforma daromadini yozish
    if platform_fee > 0:
        await cur.execute(
            "INSERT INTO platform_earnings (payment_id, appointment_id, amount, commission_rate) VALUES (%s,%s,%s,%s)",
            (payment_id, order_id, platform_fee, PLATFORM_COMMISSION_RATE * 100),
        )

    # Legacy loyalty points
    points = int(price // 50000)
    if points > 0:
        await cur.execute("UPDATE users SET loyalty_points = loyalty_points + %s WHERE id=%s", (points, appt['customer_id']))

    try:
        await cur.execute(
            "INSERT INTO notifications (user_id, title, body, type) VALUES (%s,%s,%s,'payment')",
            (appt['customer_id'], "To'lov qabul qilindi", f"{int(total)} so'm to'lovingiz qabul qilindi"),
        )
    except Exception:
        pass


# ─── BASIC PAYMENT ───────────────────────────────────────────────────────────

@router.get("/payment/calculate/{appointment_id}")
async def calculate_payment(appointment_id: int):
    """To'lov oldidan komissiya hisobini ko'rsatish (UI uchun)."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, price, payment_status FROM appointments WHERE id=%s", (appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")
            price = float(appt['price'] or 0)
            commission = round(price * PLATFORM_COMMISSION_RATE, 2)
            total = round(price + commission, 2)
            return {
                "appointment_id": appointment_id,
                "service_price": price,
                "commission_rate": PLATFORM_COMMISSION_RATE,
                "commission_amount": commission,
                "total_charged": total,
                "message": f"Xizmat haqqi ({int(PLATFORM_COMMISSION_RATE*100)}%) — ilova orqali navbat olish va onlayn to'lash qulayligi uchun olinadi.",
            }
    finally:
        await release_conn(conn)


@router.post("/create_payment")
async def create_payment(payment: PaymentWithCommission):
    """To'lov yaratish — 2% komissiya bilan. accept_commission=True bo'lishi shart."""
    if not payment.accept_commission:
        raise HTTPException(
            status_code=400,
            detail="Komissiya shartlariga rozilik bildiring (accept_commission: true)",
        )
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, price, customer_id, payment_status FROM appointments WHERE id=%s", (payment.appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")

            price = float(appt['price'] or 0)
            commission = round(price * PLATFORM_COMMISSION_RATE, 2)
            total = round(price + commission, 2)
            barber_amount = price

            # Appointments jadvalida komissiya ma'lumotlarini saqlash
            await cur.execute(
                "UPDATE appointments SET commission_amount=%s, total_charged=%s WHERE id=%s",
                (commission, total, payment.appointment_id),
            )

            # Payment yozuvi
            await cur.execute(
                "INSERT INTO payments (appointment_id, amount, platform_fee, barber_amount, method, status) "
                "VALUES (%s,%s,%s,%s,%s,'pending')",
                (payment.appointment_id, total, commission, barber_amount, payment.method),
            )
            payment_id = cur.lastrowid

            # To'lovni yakunlash
            if payment.method in ['click', 'payme']:
                transaction_id = f"{payment.method.upper()}-{payment_id}-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
                await cur.execute(
                    "UPDATE payments SET status='completed', transaction_id=%s WHERE id=%s",
                    (transaction_id, payment_id),
                )
            else:
                await cur.execute("UPDATE payments SET status='completed' WHERE id=%s", (payment_id,))

            await cur.execute(
                "UPDATE appointments SET payment_status='paid', payment_method=%s WHERE id=%s",
                (payment.method, payment.appointment_id),
            )

            # Platform earning yozish
            await cur.execute(
                "INSERT INTO platform_earnings (payment_id, appointment_id, amount, commission_rate) VALUES (%s,%s,%s,%s)",
                (payment_id, payment.appointment_id, commission, PLATFORM_COMMISSION_RATE * 100),
            )

            # Legacy loyalty points
            points = int(price // 50000)
            if points > 0:
                await cur.execute(
                    "UPDATE users SET loyalty_points = loyalty_points + %s WHERE id=%s",
                    (points, appt['customer_id']),
                )

            await conn.commit()
            return {
                "status": "success",
                "payment_id": payment_id,
                "service_price": price,
                "commission": commission,
                "total_charged": total,
                "loyalty_points_earned": points,
            }
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


@router.get("/payment_history/{customer_id}")
async def get_payment_history(customer_id: int):
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(
                "SELECT p.*, a.service_name, b.name as barber_name FROM payments p "
                "JOIN appointments a ON p.appointment_id = a.id JOIN barbers b ON a.barber_id = b.id "
                "WHERE a.customer_id=%s AND p.status='completed' ORDER BY p.created_at DESC",
                (customer_id,),
            )
            result = await cur.fetchall()
            rows = []
            for r in result:
                d = dict(r)
                if d.get('created_at') and hasattr(d['created_at'], 'isoformat'):
                    d['created_at'] = d['created_at'].isoformat()
                rows.append(d)
            return rows
    finally:
        await release_conn(conn)


# ─── CHECKOUT ────────────────────────────────────────────────────────────────

@router.post("/payment/checkout")
async def payment_checkout(data: CheckoutRequest):
    """Tanlangan tizim uchun checkout URL qaytaradi (ilova uni ochadi)."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT id, price, payment_status FROM appointments WHERE id=%s", (data.appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")
            amount_sum = float(appt['price'] or 0)
            if amount_sum <= 0:
                raise HTTPException(status_code=400, detail="To'lov summasi noto'g'ri")
            gw = data.gateway.lower()
            if gw == 'payme':
                amount_tiyin = int(round(amount_sum * 100))
                raw = f"m={PAYME_MERCHANT_ID};ac.order_id={data.appointment_id};a={amount_tiyin};c={PAYMENT_RETURN_URL}"
                encoded = base64.b64encode(raw.encode()).decode()
                url = f"{PAYME_CHECKOUT_URL}/{encoded}"
            elif gw == 'click':
                amount_int = int(round(amount_sum))
                url = (
                    f"{CLICK_CHECKOUT_URL}?service_id={CLICK_SERVICE_ID}"
                    f"&merchant_id={CLICK_MERCHANT_ID}&amount={amount_int}"
                    f"&transaction_param={data.appointment_id}&return_url={PAYMENT_RETURN_URL}"
                )
            else:
                raise HTTPException(status_code=400, detail="Noto'g'ri to'lov tizimi")
            return {"checkout_url": url, "order_id": data.appointment_id, "amount": amount_sum, "gateway": gw}
    finally:
        await release_conn(conn)


@router.get("/payment/status/{appointment_id}")
async def payment_status(appointment_id: int):
    """Ilova to'lov holatini polling qilish uchun."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT payment_status FROM appointments WHERE id=%s", (appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            await cur.execute(
                "SELECT gateway, state FROM gateway_transactions WHERE order_id=%s ORDER BY id DESC LIMIT 1",
                (appointment_id,),
            )
            tx = await cur.fetchone()
            return {
                "payment_status": appt['payment_status'],
                "paid": appt['payment_status'] == 'paid',
                "gateway": tx['gateway'] if tx else None,
                "state": tx['state'] if tx else 0,
            }
    finally:
        await release_conn(conn)


@router.get("/payment/return", response_class=HTMLResponse)
async def payment_return():
    return HTMLResponse(
        "<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>To'lov</title></head>"
        "<body style='font-family:sans-serif;text-align:center;padding:48px;color:#222'>"
        "<h2>To'lov jarayoni yakunlandi</h2>"
        "<p>Ilovaga qaytishingiz mumkin.</p></body></html>"
    )


# ─── PAYME JSON-RPC CALLBACK ─────────────────────────────────────────────────

@router.post("/payme/callback")
async def payme_callback(request: Request):
    try:
        body = await request.json()
    except Exception:
        return _payme_error(None, -32700, "JSON parse xatosi")
    req_id = body.get("id")
    method = body.get("method")
    params = body.get("params", {}) or {}

    # Basic Auth tekshiruvi
    auth = request.headers.get("Authorization", "")
    expected = "Basic " + base64.b64encode(f"Paycom:{PAYME_KEY}".encode()).decode()
    if auth != expected:
        return _payme_error(req_id, -32504, "Avtorizatsiya xatosi")

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            if method == "CheckPerformTransaction":
                amount = params.get("amount")
                order_id = (params.get("account") or {}).get("order_id")
                if not order_id:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (order_id,))
                appt = await cur.fetchone()
                if not appt:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                if amount != int(round(float(appt['price']) * 100)):
                    return _payme_error(req_id, -31001, _INVALID_AMOUNT)
                return {"result": {"allow": True}, "id": req_id}

            elif method == "CreateTransaction":
                trans_id = params.get("id")
                amount = params.get("amount")
                ptime = params.get("time")
                order_id = (params.get("account") or {}).get("order_id")
                await cur.execute(
                    "SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s",
                    (trans_id,),
                )
                tx = await cur.fetchone()
                if tx:
                    if tx['state'] != 1:
                        return _payme_error(req_id, -31008, _CANT_PERFORM)
                    return {"result": {"create_time": tx['create_time'], "transaction": str(tx['id']), "state": 1}, "id": req_id}
                if not order_id:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (order_id,))
                appt = await cur.fetchone()
                if not appt:
                    return _payme_error(req_id, -31050, _ORDER_NOT_FOUND, "order_id")
                if amount != int(round(float(appt['price']) * 100)):
                    return _payme_error(req_id, -31001, _INVALID_AMOUNT)
                await cur.execute(
                    "SELECT id FROM gateway_transactions WHERE gateway='payme' AND order_id=%s AND state IN (1,2)",
                    (order_id,),
                )
                if await cur.fetchone():
                    return _payme_error(req_id, -31008, _CANT_PERFORM)
                await cur.execute(
                    "INSERT INTO gateway_transactions (gateway, order_id, amount, state, provider_trans_id, create_time) "
                    "VALUES ('payme',%s,%s,1,%s,%s)",
                    (order_id, amount, trans_id, ptime),
                )
                new_id = cur.lastrowid
                await conn.commit()
                return {"result": {"create_time": ptime, "transaction": str(new_id), "state": 1}, "id": req_id}

            elif method == "PerformTransaction":
                trans_id = params.get("id")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if not tx:
                    return _payme_error(req_id, -31003, _TX_NOT_FOUND)
                if tx['state'] == 2:
                    return {"result": {"transaction": str(tx['id']), "perform_time": tx['perform_time'], "state": 2}, "id": req_id}
                if tx['state'] != 1:
                    return _payme_error(req_id, -31008, _CANT_PERFORM)
                perform_time = int(time.time() * 1000)
                await cur.execute("UPDATE gateway_transactions SET state=2, perform_time=%s WHERE id=%s", (perform_time, tx['id']))
                await _gw_mark_paid(cur, tx['order_id'], 'payme')
                await conn.commit()
                return {"result": {"transaction": str(tx['id']), "perform_time": perform_time, "state": 2}, "id": req_id}

            elif method == "CancelTransaction":
                trans_id = params.get("id")
                reason = params.get("reason")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if not tx:
                    return _payme_error(req_id, -31003, _TX_NOT_FOUND)
                if tx['state'] in (-1, -2):
                    return {"result": {"transaction": str(tx['id']), "cancel_time": tx['cancel_time'], "state": tx['state']}, "id": req_id}
                cancel_time = int(time.time() * 1000)
                if tx['state'] == 1:
                    new_state = -1
                else:
                    new_state = -2
                    await cur.execute("UPDATE appointments SET payment_status='unpaid' WHERE id=%s", (tx['order_id'],))
                await cur.execute("UPDATE gateway_transactions SET state=%s, cancel_time=%s, reason=%s WHERE id=%s", (new_state, cancel_time, reason, tx['id']))
                await conn.commit()
                return {"result": {"transaction": str(tx['id']), "cancel_time": cancel_time, "state": new_state}, "id": req_id}

            elif method == "CheckTransaction":
                trans_id = params.get("id")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND provider_trans_id=%s", (trans_id,))
                tx = await cur.fetchone()
                if not tx:
                    return _payme_error(req_id, -31003, _TX_NOT_FOUND)
                return {"result": {
                    "create_time": tx['create_time'], "perform_time": tx['perform_time'],
                    "cancel_time": tx['cancel_time'], "transaction": str(tx['id']),
                    "state": tx['state'], "reason": tx['reason'],
                }, "id": req_id}

            elif method == "GetStatement":
                frm = params.get("from")
                to = params.get("to")
                await cur.execute("SELECT * FROM gateway_transactions WHERE gateway='payme' AND create_time BETWEEN %s AND %s", (frm, to))
                rows = await cur.fetchall()
                transactions = [{
                    "id": r['provider_trans_id'], "time": r['create_time'], "amount": r['amount'],
                    "account": {"order_id": r['order_id']}, "create_time": r['create_time'],
                    "perform_time": r['perform_time'], "cancel_time": r['cancel_time'],
                    "transaction": str(r['id']), "state": r['state'], "reason": r['reason'],
                } for r in rows]
                return {"result": {"transactions": transactions}, "id": req_id}

            else:
                return _payme_error(req_id, -32601, "Metod topilmadi")
    except Exception as e:
        await conn.rollback()
        return _payme_error(req_id, -31008, {"uz": str(e), "ru": str(e), "en": str(e)})
    finally:
        await release_conn(conn)


# ─── CLICK SHOP API ──────────────────────────────────────────────────────────

@router.post("/click/prepare")
async def click_prepare(request: Request):
    form = await request.form()
    click_trans_id = form.get("click_trans_id")
    service_id = form.get("service_id")
    merchant_trans_id = form.get("merchant_trans_id")
    amount = form.get("amount")
    action = form.get("action")
    sign_time = form.get("sign_time")
    sign_string = form.get("sign_string")

    expected_sign = _click_sign(click_trans_id, service_id, CLICK_SECRET_KEY, merchant_trans_id, amount, action, sign_time)
    if sign_string != expected_sign:
        return {"error": -1, "error_note": "SIGN CHECK FAILED"}
    if str(action) != "0":
        return {"error": -3, "error_note": "Action not found"}

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (merchant_trans_id,))
            appt = await cur.fetchone()
            if not appt:
                return {"error": -5, "error_note": "Buyurtma topilmadi"}
            if appt['payment_status'] == 'paid':
                return {"error": -4, "error_note": "Allaqachon to'langan"}
            if abs(float(amount) - float(appt['price'])) > 0.01:
                return {"error": -2, "error_note": "Noto'g'ri summa"}
            await cur.execute(
                "INSERT INTO gateway_transactions (gateway, order_id, amount, state, provider_trans_id, create_time) "
                "VALUES ('click',%s,%s,1,%s,%s)",
                (merchant_trans_id, int(round(float(amount))), click_trans_id, int(time.time())),
            )
            prepare_id = cur.lastrowid
            await conn.commit()
            return {
                "click_trans_id": click_trans_id, "merchant_trans_id": merchant_trans_id,
                "merchant_prepare_id": prepare_id, "error": 0, "error_note": "Success",
            }
    finally:
        await release_conn(conn)


@router.post("/click/complete")
async def click_complete(request: Request):
    form = await request.form()
    click_trans_id = form.get("click_trans_id")
    service_id = form.get("service_id")
    merchant_trans_id = form.get("merchant_trans_id")
    merchant_prepare_id = form.get("merchant_prepare_id")
    amount = form.get("amount")
    action = form.get("action")
    sign_time = form.get("sign_time")
    sign_string = form.get("sign_string")
    try:
        click_error = int(form.get("error", "0") or 0)
    except (TypeError, ValueError):
        click_error = 0

    expected_sign = _click_sign(click_trans_id, service_id, CLICK_SECRET_KEY, merchant_trans_id, merchant_prepare_id, amount, action, sign_time)
    if sign_string != expected_sign:
        return {"error": -1, "error_note": "SIGN CHECK FAILED"}
    if str(action) != "1":
        return {"error": -3, "error_note": "Action not found"}

    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT * FROM gateway_transactions WHERE id=%s AND gateway='click'", (merchant_prepare_id,))
            tx = await cur.fetchone()
            if not tx:
                return {"error": -6, "error_note": "Tranzaksiya topilmadi"}
            if tx['state'] == -1:
                return {"error": -9, "error_note": "Tranzaksiya bekor qilingan"}
            if click_error < 0:
                await cur.execute("UPDATE gateway_transactions SET state=-1, cancel_time=%s WHERE id=%s", (int(time.time()), tx['id']))
                await conn.commit()
                return {"error": click_error, "error_note": "Bekor qilindi"}
            await cur.execute("SELECT payment_status FROM appointments WHERE id=%s", (merchant_trans_id,))
            appt = await cur.fetchone()
            if not appt:
                return {"error": -5, "error_note": "Buyurtma topilmadi"}
            if appt['payment_status'] != 'paid':
                await cur.execute("UPDATE gateway_transactions SET state=2, perform_time=%s WHERE id=%s", (int(time.time()), tx['id']))
                await _gw_mark_paid(cur, int(merchant_trans_id), 'click')
                await conn.commit()
            return {
                "click_trans_id": click_trans_id, "merchant_trans_id": merchant_trans_id,
                "merchant_confirm_id": tx['id'], "error": 0, "error_note": "Success",
            }
    finally:
        await release_conn(conn)


# ─── PAYME SUBSCRIBE (CARDS) — ilova ichida karta bilan to'lash ──────────────

async def _payme_subscribe(method: str, params: dict, use_key: bool = False):
    """Payme Subscribe API ga JSON-RPC so'rov yuboradi."""
    auth = f"{PAYME_MERCHANT_ID}:{PAYME_KEY}" if use_key else PAYME_MERCHANT_ID
    payload = {"id": int(time.time() * 1000) % 1000000, "method": method, "params": params}
    headers = {"X-Auth": auth, "Content-Type": "application/json"}
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(PAYME_SUBSCRIBE_URL, json=payload, headers=headers)
        data = resp.json()
        return data.get("result"), data.get("error")
    except Exception as e:
        return None, {"message": f"To'lov xizmatiga ulanib bo'lmadi: {e}"}


def _payme_err_msg(error, fallback):
    msg = error.get("message") if isinstance(error, dict) else None
    if isinstance(msg, dict):
        return msg.get("uz") or msg.get("ru") or msg.get("en") or fallback
    return msg or fallback


@router.post("/card/create")
async def card_create(data: CardCreate):
    """Karta tokenini yaratadi (hali tasdiqlanmagan)."""
    result, error = await _payme_subscribe("cards.create", {
        "card": {"number": data.number, "expire": data.expire}, "save": True,
    })
    if error or not result:
        raise HTTPException(status_code=400, detail=_payme_err_msg(error, "Kartani qo'shib bo'lmadi"))
    card = result.get("card", {})
    return {"token": card.get("token"), "verify": card.get("verify", False)}


@router.post("/card/send_code")
async def card_send_code(data: CardTokenAction):
    """Kartaga bog'langan telefon raqamiga SMS-kod yuboradi."""
    result, error = await _payme_subscribe("cards.get_verify_code", {"token": data.token})
    if error or not result:
        raise HTTPException(status_code=400, detail=_payme_err_msg(error, "Kod yuborib bo'lmadi"))
    return {"sent": True, "phone": result.get("phone"), "wait": result.get("wait")}


@router.post("/card/verify")
async def card_verify(data: CardVerify):
    """SMS-kod orqali kartani tasdiqlaydi."""
    result, error = await _payme_subscribe("cards.verify", {"token": data.token, "code": data.code})
    if error or not result:
        raise HTTPException(status_code=400, detail=_payme_err_msg(error, "Kod noto'g'ri"))
    card = result.get("card", {})
    return {"verified": card.get("verify", False)}


@router.post("/card/pay")
async def card_pay(data: CardPay):
    """Tasdiqlangan karta tokeni bilan navbat uchun to'lov qiladi."""
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute("SELECT price, payment_status FROM appointments WHERE id=%s", (data.appointment_id,))
            appt = await cur.fetchone()
            if not appt:
                raise HTTPException(status_code=404, detail="Navbat topilmadi")
            if appt['payment_status'] == 'paid':
                raise HTTPException(status_code=409, detail="Allaqachon to'langan")
            amount_tiyin = int(round(float(appt['price']) * 100))

            # 1) Chek yaratish
            result, error = await _payme_subscribe("receipts.create", {
                "amount": amount_tiyin,
                "account": {PAYME_ACCOUNT_FIELD: data.appointment_id},
            }, use_key=True)
            if error or not result:
                raise HTTPException(status_code=400, detail=_payme_err_msg(error, "Chek yaratib bo'lmadi"))
            receipt_id = (result.get("receipt") or {}).get("_id")
            if not receipt_id:
                raise HTTPException(status_code=400, detail="Chek identifikatori olinmadi")

            # 2) Chekni to'lash
            result2, error2 = await _payme_subscribe("receipts.pay", {
                "id": receipt_id, "token": data.token,
            }, use_key=True)
            if error2 or not result2:
                raise HTTPException(status_code=400, detail=_payme_err_msg(error2, "To'lov amalga oshmadi"))
            state = (result2.get("receipt") or {}).get("state")
            if state != 4:
                raise HTTPException(status_code=400, detail="To'lov tasdiqlanmadi")

            await _gw_mark_paid(cur, data.appointment_id, 'card')
            await conn.commit()
            return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        await conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await release_conn(conn)


# ─── PLATFORMA DAROMADI HISOBOTI ─────────────────────────────────────────────

@router.get("/platform/earnings")
async def get_platform_earnings(days: int = 30):
    """Platforma daromadi hisoboti (admin uchun)."""
    import datetime as dt
    conn = await get_conn()
    try:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            start_date = dt.date.today() - dt.timedelta(days=days - 1)
            # Umumiy daromad
            await cur.execute("SELECT COALESCE(SUM(amount),0) as total FROM platform_earnings")
            total_all = float((await cur.fetchone())["total"])
            # Tanlangan davr
            await cur.execute(
                "SELECT COALESCE(SUM(amount),0) as total, COUNT(*) as count "
                "FROM platform_earnings WHERE DATE(created_at) >= %s",
                (start_date,),
            )
            period = await cur.fetchone()
            # Kunlik breakdown
            await cur.execute(
                "SELECT DATE(created_at) as day, SUM(amount) as revenue, COUNT(*) as transactions "
                "FROM platform_earnings WHERE DATE(created_at) >= %s "
                "GROUP BY DATE(created_at) ORDER BY day",
                (start_date,),
            )
            rows = await cur.fetchall()
            daily = []
            for r in rows:
                daily.append({
                    "date": r["day"].isoformat() if hasattr(r["day"], "isoformat") else str(r["day"]),
                    "revenue": float(r["revenue"]),
                    "transactions": r["transactions"],
                })
            return {
                "total_earnings": total_all,
                "period_days": days,
                "period_earnings": float(period["total"]),
                "period_transactions": period["count"],
                "daily": daily,
            }
    finally:
        await release_conn(conn)
