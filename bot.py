import os
import asyncio
from aiogram import Bot, Dispatcher, F, Router
from aiogram.types import Message
from aiogram.filters import CommandStart
from reg import router as reg_router, show_client_reg, db as reg_db, main_kb
from prisma import Prisma
from dotenv import load_dotenv
from pathlib import Path
from helpers import send_keep, send_temp
from keyboards import client_kb, app_inline_kb
from aiogram.fsm.context import FSMContext

# Загружаем .env
load_dotenv(dotenv_path=Path(__file__).parent / ".env")
print("DEBUG .env BOT_TOKEN:", os.getenv("BOT_TOKEN"))

# Prisma engine общается по localhost; прокси ломают соединение → отключаем прокси для локалхоста
os.environ.setdefault("NO_PROXY", "127.0.0.1,localhost")
os.environ.setdefault("no_proxy", "127.0.0.1,localhost")
# (опционально) форсируем бинарный движок
os.environ.setdefault("PRISMA_CLIENT_ENGINE_TYPE", "binary")

BOT_TOKEN = os.getenv("BOT_TOKEN")
db = Prisma()


async def on_start(message: Message):
    user = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if user:
        has_tariff = bool(user.tariffName)
        await send_temp(message, "👋 С возвращением! Главное меню клиента.", reply_markup=client_kb(has_tariff))
        return
    await send_keep(message, "👋 Добро пожаловать!\nТут будет в будущем крутой текст 🚀\n\n", reply_markup=main_kb())


async def on_client(message: Message, state: FSMContext):
    user = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    if user:
        has_tariff = bool(user.tariffName)
        await send_temp(message, "Открываю меню клиента.", reply_markup=client_kb(has_tariff))
        return
    await show_client_reg(message, state)


async def on_about(message: Message):
    await message.answer("ℹ️ Тут будет в будущем крутой текст о боте 🚀")


async def send_app_button(message: Message):
    await message.answer(
        "Для входа в приложение нажмите на кнопку ниже:",
        reply_markup=app_inline_kb()
    )


# Временный отладочный хендлер (чтобы видеть тексты в консоли)
async def debug_all(message: Message):
    print("DEBUG TEXT:", repr(message.text))


async def main():
    if not BOT_TOKEN or "REPLACE_ME" in BOT_TOKEN:
        raise SystemExit("Заполни BOT_TOKEN (переменная окружения или константа в файле).")

    bot = Bot(BOT_TOKEN)
    dp = Dispatcher()

    # Роутеры
    from tariff_handlers import router as tariff_router
    dp.include_router(tariff_router)
    dp.include_router(reg_router)

    # Общий router для стартовых команд и кнопок
    router = Router()
    router.message.register(on_start, CommandStart())
    router.message.register(on_client, F.text == "КЛИЕНТ")
    router.message.register(on_about, F.text == "ℹ️ О нас")
    # Хендлер нажатия Reply-кнопки "Приложение"
    @router.message(F.text == "Приложение")
    async def send_app_button(message: Message):
        await message.answer(
        "Для входа в приложение нажмите на кнопку ниже:",
        reply_markup=app_inline_kb()
    )

    dp.include_router(router)

    await reg_db.connect(timeout=20)
    await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())


if __name__ == "__main__":
    asyncio.run(main())
