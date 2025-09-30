from aiogram import Router, F
from aiogram.types import Message
from keyboards import app_inline_kb

router = Router()

# Ловим Reply-кнопку «Приложение» и отвечаем Inline-кнопкой
@router.message(F.text == "Приложение")
async def send_app_button(message: Message):
    await message.answer(
        "Для входа в приложение нажмите на кнопку ниже:",
        reply_markup=app_inline_kb()
    )
