import asyncio
import os
from datetime import datetime, timedelta
from uuid import uuid4

from aiogram import Router, F
from aiogram.types import Message, ReplyKeyboardMarkup, KeyboardButton, LabeledPrice, PreCheckoutQuery
from aiogram.filters import StateFilter
from aiogram.fsm.context import FSMContext

from helpers import send_temp
from keyboards import tariffs_kb, client_kb
from reg import profile_open
from reg import db as reg_db

router = Router()

INVISIBLE = "\u2063"  # invisible placeholder

YOOKASSA_PROVIDER_TOKEN = os.getenv("YOOKASSA_PROVIDER_TOKEN", "").strip()

TARIFF_CODE_MAP = {
    "Базовый": "base",
    "Оптимальный": "optimal",
    "Максимум": "maximum",
}
TARIFF_NAME_MAP = {value: key for key, value in TARIFF_CODE_MAP.items()}
TARIFF_PRICE_DEFAULTS_RUB = {
    "base": 1000,
    "optimal": 5000,
    "maximum": 15000,
}
TARIFF_PRICE_ENV_KEYS = {
    "base": "TARIFF_PRICE_BASE_RUB",
    "optimal": "TARIFF_PRICE_OPTIMAL_RUB",
    "maximum": "TARIFF_PRICE_MAX_RUB",
}
TARIFF_PERIOD_DAYS = 30
TARIFF_ORDER = {"base": 1, "optimal": 2, "maximum": 3}


def _price_rub(tariff_code: str) -> int:
    env_key = TARIFF_PRICE_ENV_KEYS.get(tariff_code, "")
    raw = os.getenv(env_key, "") if env_key else ""
    try:
        value = int(raw)
    except (TypeError, ValueError):
        value = TARIFF_PRICE_DEFAULTS_RUB.get(tariff_code, 100)
    return max(value, 1)


def _build_invoice_payload(tariff_code: str, mode, user_id: int) -> str:
    mode_value = mode or ""
    nonce = uuid4().hex[:8]
    return f"tariff={tariff_code};mode={mode_value};uid={user_id};n={nonce}"


def _parse_invoice_payload(payload: str) -> dict:
    data = {}
    for part in payload.split(";"):
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        data[key] = value
    return data


def _text_contains(text, needle: str) -> bool:
    return isinstance(text, str) and needle in text.casefold()


def _schedule_delete(bot, chat_id: int, message_id: int, delay: int) -> None:
    async def _delete_later():
        await asyncio.sleep(delay)
        try:
            await bot.delete_message(chat_id, message_id)
        except Exception:
            pass

    asyncio.create_task(_delete_later())


def _normalize_tariff_code(value):
    if not value:
        return None
    name = str(value).strip().lower()
    if "базов" in name:
        return "base"
    if "оптим" in name:
        return "optimal"
    if "максим" in name:
        return "maximum"
    return None


def _remaining_days(expires_at) -> int:
    if not expires_at:
        return 0
    now = datetime.now(expires_at.tzinfo) if getattr(expires_at, "tzinfo", None) else datetime.utcnow()
    remaining_seconds = (expires_at - now).total_seconds()
    if remaining_seconds <= 0:
        return 0
    return min(TARIFF_PERIOD_DAYS, int((remaining_seconds + 86399) // 86400))


def _remaining_fraction(expires_at) -> float:
    if not expires_at:
        return 0.0
    now = datetime.now(expires_at.tzinfo) if getattr(expires_at, "tzinfo", None) else datetime.utcnow()
    remaining_seconds = (expires_at - now).total_seconds()
    if remaining_seconds <= 0:
        return 0.0
    total_seconds = TARIFF_PERIOD_DAYS * 24 * 60 * 60
    return min(1.0, remaining_seconds / total_seconds)


def _tariff_active(user) -> bool:
    if not user or not getattr(user, "tariffName", None):
        return False
    expires_at = getattr(user, "tariffExpiresAt", None)
    if not expires_at:
        return True
    now = datetime.now(expires_at.tzinfo) if getattr(expires_at, "tzinfo", None) else datetime.utcnow()
    return expires_at > now


def _is_staff(user) -> bool:
    if not user:
        return False
    role = getattr(user, "role", None)
    return role in ("admin", "sadmin", "trainer", "curator") or bool(getattr(user, "isCurator", False))


# ---------- temporary state ----------
class TempState:
    TARIFF = "temp_tariff"
    MODE = "temp_mode"


# ---------- local reply keyboards ----------
def base_tariff_menu_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💳 Купить")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


def base_tariff_mode_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="Зал"), KeyboardButton(text="Кроссфит")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


def value_tariff_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="Чат с куратором"), KeyboardButton(text="Тренировки")],
            [KeyboardButton(text="💳 Купить")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


def tariff_status_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="✏️ Изменить")],
            [KeyboardButton(text="🏠 На главную")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


def buy_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💳 Купить")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


def section_action_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💳 Купить")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


def value_tariff_final_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="Чат с куратором"), KeyboardButton(text="Тренировки")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
        is_persistent=True,
    )


# ---------- handlers ----------
@router.message(StateFilter("*"), F.text.in_({"Меню", "Профиль", "Тариф"}))
async def forced_exit_from_fsm(message: Message, state: FSMContext):
    await state.clear()
    if message.text == "Профиль":
        await profile_open(message)
        return
    if message.text == "Тариф":
        await show_tariffs(message, state)
        return
    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    has_app = _tariff_active(u)
    is_admin = _is_staff(u)
    await send_temp(message, "🏠 Главное меню клиента", reply_markup=client_kb(has_app, is_admin))


@router.message(StateFilter(None), F.text.func(lambda t: _text_contains(t, "тариф")))
async def show_tariffs(message: Message, state: FSMContext):
    await state.clear()
    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if _is_staff(u):
        await send_temp(
            message,
            "Покупка тарифа не требуется.",
            reply_markup=client_kb(_tariff_active(u), True),
        )
        return
    if _tariff_active(u):
        await send_temp(
            message,
            f"У вас куплен тариф: *{u.tariffName}*",
            parse_mode="Markdown",
            reply_markup=tariff_status_kb(),
        )
        return
    await send_temp(message, "Выберите подходящий тариф:", reply_markup=tariffs_kb())


@router.message(StateFilter(None), F.text == "✏️ Изменить")
async def tariff_change(message: Message, state: FSMContext):
    await state.clear()
    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if _is_staff(u):
        await send_temp(
            message,
            "Покупка тарифа не требуется.",
            reply_markup=client_kb(_tariff_active(u), True),
        )
        return
    await send_temp(message, "Выберите новый тариф:", reply_markup=tariffs_kb())


@router.message(StateFilter(None), F.text == "🏠 На главную")
async def tariff_to_home(message: Message, state: FSMContext):
    await state.clear()
    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    has_app = _tariff_active(u)
    is_admin = _is_staff(u)
    await send_temp(message, "🏠 Главное меню клиента", reply_markup=client_kb(has_app, is_admin))


# ---------- basic ----------
@router.message(StateFilter(None), F.text == "💼 Базовый")
async def show_base_tariff(message: Message, state: FSMContext):
    await state.set_data({TempState.TARIFF: "Базовый", TempState.MODE: ""})
    await send_temp(
        message,
        "🧾 *Базовый тариф*\n\n"
        "Выберите направление: зал или кроссфит.\n"
        "От выбора зависит доступный контент.",
        parse_mode="Markdown",
        reply_markup=base_tariff_mode_kb(),
    )


@router.message(StateFilter(None), F.text.in_({"Зал", "Кроссфит"}))
async def select_base_tariff_mode(message: Message, state: FSMContext):
    data = await state.get_data()
    if data.get(TempState.TARIFF) != "Базовый":
        return

    mode = "gym" if message.text == "Зал" else "crossfit"
    await state.update_data({TempState.MODE: mode})
    await send_temp(
        message,
        f"Вы выбрали направление: *{message.text}*.\n"
        "Можно продолжать покупку тарифа.",
        parse_mode="Markdown",
        reply_markup=base_tariff_menu_kb(),
    )


# ---------- optimal ----------
@router.message(StateFilter(None), F.text == "🤑 Оптимальный")
async def show_value_tariff(message: Message, state: FSMContext):
    await state.set_data({TempState.TARIFF: "Оптимальный"})
    await send_temp(
        message,
        "🧾 *Оптимальный тариф*\n\nЗдесь будет описание тарифа.",
        parse_mode="Markdown",
        reply_markup=buy_kb(),
    )


# ---------- maximum ----------
@router.message(StateFilter(None), F.text == "💎 Максимум")
async def show_maximum_tariff(message: Message, state: FSMContext):
    await state.set_data({TempState.TARIFF: "Максимум"})
    await send_temp(
        message,
        "🧾 *Максимум*\n\nЗдесь будет описание тарифа.",
        parse_mode="Markdown",
        reply_markup=buy_kb(),
    )


@router.message(F.text.func(lambda t: _text_contains(t, "купить")))
async def handle_tariff_purchase(message: Message, state: FSMContext):
    data = await state.get_data()
    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if _is_staff(u):
        await state.clear()
        await send_temp(
            message,
            "Покупка тарифа не требуется.",
            reply_markup=client_kb(_tariff_active(u), True),
        )
        return
    bought_tariff = data.get(TempState.TARIFF, "Базовый")
    selected_mode = data.get(TempState.MODE)

    if bought_tariff == "Базовый" and selected_mode not in ("gym", "crossfit"):
        await send_temp(
            message,
            "Сначала выберите тренировочный режим: зал или кроссфит.",
            reply_markup=base_tariff_mode_kb(),
        )
        return

    if not YOOKASSA_PROVIDER_TOKEN:
        await send_temp(
            message,
            "ЮKassa не настроена. Добавьте YOOKASSA_PROVIDER_TOKEN в .env.",
            reply_markup=client_kb(_tariff_active(u), False),
        )
        await state.clear()
        return

    tariff_code = TARIFF_CODE_MAP.get(bought_tariff, "base")
    price_rub = _price_rub(tariff_code)
    description = "Оплата тарифа Fit Dew (тестовый платеж)."

    current_code = None
    current_expires = None
    if _tariff_active(u):
        current_code = _normalize_tariff_code(getattr(u, "tariffName", None))
        current_expires = getattr(u, "tariffExpiresAt", None)

    if current_code:
        current_rank = TARIFF_ORDER.get(current_code, 0)
        target_rank = TARIFF_ORDER.get(tariff_code, 0)
        if current_rank >= target_rank:
            await send_temp(message, "У вас уже этот тариф или выше.", reply_markup=tariff_status_kb())
            await state.clear()
            return
        remaining_days = _remaining_days(current_expires)
        remaining_fraction = _remaining_fraction(current_expires)
        credit_rub = int(round(_price_rub(current_code) * remaining_fraction))
        if credit_rub > 0:
            price_rub = max(1, price_rub - credit_rub)
            description = (
                f"Апгрейд тарифа Fit Dew (остаток {remaining_days} дн.)."
            )
    payload = _build_invoice_payload(tariff_code, selected_mode, message.from_user.id)
    title = f"Тариф {bought_tariff}"

    invoice_message = await message.answer_invoice(
        title=title,
        description=description,
        payload=payload,
        provider_token=YOOKASSA_PROVIDER_TOKEN,
        currency="RUB",
        prices=[LabeledPrice(label=title, amount=price_rub * 100)],
    )
    _schedule_delete(message.bot, message.chat.id, invoice_message.message_id, 320)

    await state.clear()


@router.pre_checkout_query()
async def handle_pre_checkout(pre_checkout_query: PreCheckoutQuery):
    await pre_checkout_query.answer(ok=True)


@router.message(F.successful_payment)
async def handle_successful_payment(message: Message, state: FSMContext):
    payload = message.successful_payment.invoice_payload or ""
    data = _parse_invoice_payload(payload)
    tariff_code = data.get("tariff", "base")
    mode = data.get("mode") or None
    tariff_name = TARIFF_NAME_MAP.get(tariff_code, "Базовый")

    create_data = {
        "tg_id": message.from_user.id,
        "username": message.from_user.username,
        "tariffName": tariff_name,
        "tariffReminderFor": None,
    }
    update_data = {
        "username": message.from_user.username,
        "tariffName": tariff_name,
        "tariffReminderFor": None,
    }
    expires_at = datetime.utcnow() + timedelta(days=30)

    create_data["tariffExpiresAt"] = expires_at
    update_data["tariffExpiresAt"] = expires_at

    if tariff_name == "Базовый" and mode in ("gym", "crossfit"):
        create_data["trainingMode"] = mode
        update_data["trainingMode"] = mode

    await reg_db.user.upsert(
        where={"tg_id": message.from_user.id},
        data={"create": create_data, "update": update_data},
    )

    await send_temp(
        message,
        f"✅ Оплата прошла! Тариф: *{tariff_name}*",
        parse_mode="Markdown",
    )

    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if tariff_name in ("Оптимальный", "Максимум") and not _is_staff(u):
        if getattr(u, "trainerId", None):
            await send_temp(message, "Вам назначен куратор. Теперь вам доступен чат с куратором.")
        else:
            await send_temp(message, "В ближайшее время вам будет назначен куратор.")
    has_app = _tariff_active(u)
    is_admin = _is_staff(u)
    await send_temp(message, "🏠 Главное меню клиента", reply_markup=client_kb(has_app, is_admin))
    await state.clear()


# ---------- back ----------
@router.message(StateFilter(None), F.text == "⬅️ Назад")
async def back_to_main_menu(message: Message, state: FSMContext):
    await state.clear()
    u = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    has_app = _tariff_active(u)
    is_admin = _is_staff(u)
    await send_temp(message, "🏠 Главное меню клиента", reply_markup=client_kb(has_app, is_admin))
