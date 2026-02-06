import os
import asyncio
from datetime import datetime, timedelta
from aiogram import Bot, Dispatcher, F, Router
from aiogram.types import Message
from aiogram.filters import CommandStart
from reg import router as reg_router, show_client_reg, db as reg_db, main_kb
from prisma import Prisma
from dotenv import load_dotenv
from pathlib import Path
from helpers import send_keep, send_temp
from keyboards import client_kb
from aiogram.fsm.context import FSMContext

# Загружаем .env
load_dotenv(dotenv_path=Path(__file__).parent / ".env")
print("DEBUG .env BOT_TOKEN:", os.getenv("BOT_TOKEN"))

# Prisma engine общается по localhost; прокси ломают соединение → отключаем прокси для локалхоста
os.environ.setdefault("NO_PROXY", "127.0.0.1,localhost")
os.environ.setdefault("no_proxy", "127.0.0.1,localhost")
os.environ.setdefault("PRISMA_CLIENT_ENGINE_TYPE", "binary")

BOT_TOKEN = os.getenv("BOT_TOKEN")
db = Prisma()
TARIFF_REMINDER_DAYS = int(os.getenv("TARIFF_REMINDER_DAYS", "3"))
TARIFF_REMINDER_CHECK_MINUTES = int(os.getenv("TARIFF_REMINDER_CHECK_MINUTES", "60"))


REQUIRED_PROFILE_FIELDS = (
    "first_name",
    "heightCm",
    "weightKg",
    "age",
)


def _profile_complete(user) -> bool:
    if not user:
        return False
    for field in REQUIRED_PROFILE_FIELDS:
        value = getattr(user, field, None)
        if value is None:
            return False
        if isinstance(value, str) and not value.strip():
            return False
    return True


def _tariff_active(user) -> bool:
    if not user or not getattr(user, "tariffName", None):
        return False
    expires_at = getattr(user, "tariffExpiresAt", None)
    if not expires_at:
        return True
    now = datetime.now(expires_at.tzinfo) if getattr(expires_at, "tzinfo", None) else datetime.utcnow()
    return expires_at > now


def _format_date_only(value) -> str:
    if not value:
        return ""
    try:
        return value.strftime("%d.%m.%Y")
    except Exception:
        return ""


def _remaining_days(expires_at) -> int:
    if not expires_at:
        return 0
    now = datetime.now(expires_at.tzinfo) if getattr(expires_at, "tzinfo", None) else datetime.utcnow()
    remaining_seconds = (expires_at - now).total_seconds()
    if remaining_seconds <= 0:
        return 0
    return int((remaining_seconds + 86399) // 86400)


def _should_force_registration(user) -> bool:
    if not user:
        return False
    role = getattr(user, "role", None)
    is_staff = role in ("admin", "sadmin", "trainer", "curator") or bool(getattr(user, "isCurator", False))
    if is_staff:
        return False
    if _tariff_active(user):
        return False
    if getattr(user, "agreed_offer", False):
        return False
    return not _profile_complete(user)


async def _send_tariff_expiry_reminders(bot: Bot):
    if TARIFF_REMINDER_DAYS <= 0:
        return
    now = datetime.utcnow()
    threshold = now + timedelta(days=TARIFF_REMINDER_DAYS)
    users = await reg_db.user.find_many(
        where={
            "tariffExpiresAt": {"gt": now, "lte": threshold},
        },
        select={
            "id": True,
            "tg_id": True,
            "tariffName": True,
            "tariffExpiresAt": True,
            "tariffReminderFor": True,
            "role": True,
            "isCurator": True,
        },
    )
    for user in users:
        role = getattr(user, "role", None)
        if role in ("admin", "sadmin", "trainer", "curator") or bool(getattr(user, "isCurator", False)):
            continue
        if not user.tariffExpiresAt:
            continue
        if user.tariffReminderFor and user.tariffReminderFor == user.tariffExpiresAt:
            continue
        days_left = _remaining_days(user.tariffExpiresAt)
        if days_left <= 0:
            continue
        paid_until = _format_date_only(user.tariffExpiresAt)
        tariff_name = user.tariffName or "Тариф"
        text = (
            f"⏳ {tariff_name} оплачен до {paid_until}. "
            f"Осталось {days_left} дн. Продлите тариф, чтобы не потерять доступ."
        )
        try:
            await bot.send_message(user.tg_id, text)
        except Exception:
            continue
        try:
            await reg_db.user.update(
                where={"id": user.id},
                data={"tariffReminderFor": user.tariffExpiresAt},
            )
        except Exception:
            pass


async def _tariff_reminder_loop(bot: Bot):
    while True:
        try:
            await _send_tariff_expiry_reminders(bot)
        except Exception as exc:
            print("[tariff-reminder] failed:", exc)
        await asyncio.sleep(max(1, TARIFF_REMINDER_CHECK_MINUTES) * 60)


async def on_start(message: Message, state: FSMContext):
    user = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if user:
        if _should_force_registration(user):
            await show_client_reg(message, state)
            return
        has_tariff = _tariff_active(user)
        role = getattr(user, "role", None)
        is_staff = role in ("admin", "sadmin", "trainer") or bool(getattr(user, "isCurator", False))
        await send_keep(message, "👋 С возвращением! Главное меню клиента.", reply_markup=client_kb(has_tariff, is_staff))
        return
    await send_keep(message, "👋 Добро пожаловать!\nТут будет в будущем крутой текст 🚀\n\n", reply_markup=main_kb())

async def on_client(message: Message, state: FSMContext):
    user = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if user:
        if _should_force_registration(user):
            await show_client_reg(message, state)
            return
        has_tariff = _tariff_active(user)
        role = getattr(user, "role", None)
        is_staff = role in ("admin", "sadmin", "trainer") or bool(getattr(user, "isCurator", False))
        await send_keep(message, "Открываю меню клиента.", reply_markup=client_kb(has_tariff, is_staff))
        return
    await show_client_reg(message, state)



async def on_about(message: Message):
    await message.answer("ℹ️ Тут будет в будущем крутой текст о боте 🚀")


async def main():
    if not BOT_TOKEN or "REPLACE_ME" in BOT_TOKEN:
        raise SystemExit("Заполни BOT_TOKEN (переменная окружения или константа в файле).")

    bot = Bot(BOT_TOKEN)
    dp = Dispatcher()

    # Роутеры
    from tariff_handlers import router as tariff_router
    from app_handler import router as app_router  # наш новый модуль с кнопкой «Приложение»
    dp.include_router(tariff_router)
    dp.include_router(reg_router)
    dp.include_router(app_router)

    # Общий router для стартовых команд
    router = Router()
    router.message.register(on_start, CommandStart())
    router.message.register(on_client, F.text == "КЛИЕНТ")
    router.message.register(on_about, F.text == "ℹ️ О нас")
    dp.include_router(router)

    await reg_db.connect(timeout=20)
    asyncio.create_task(_tariff_reminder_loop(bot))
    await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())


if __name__ == "__main__":
    asyncio.run(main())
