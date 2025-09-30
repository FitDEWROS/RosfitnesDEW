from aiogram import Router, F
from aiogram.types import Message
from keyboards import app_inline_kb

router = Router()

# Ловим Reply-кнопку «Приложение» (с эмодзи или без) и отвечаем Inline-кнопкой
from helpers import send_temp  # <-- добавь импорт

@router.message(F.text.func(lambda t: t and "Приложение" in t))
async def send_app_button(message: Message):
    # Удалить сообщение пользователя в личке Telegram нельзя (обычное ограничение),
    # поэтому просто даём «временный» ответ и авто-удаляем его через 10 сек.
    await send_temp(
        message,
        "Для входа в приложение нажмите на кнопку ниже:",
        reply_markup=app_inline_kb(),
        delay=10,  # через 10 сек исчезнет
    )
