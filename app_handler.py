from aiogram import Router, F
from aiogram.types import Message
from keyboards import app_inline_kb, admin_inline_kb
from reg import db as reg_db

router = Router()

def _text_contains(text: str, needle: str) -> bool:
    return isinstance(text, str) and needle in text.casefold()

# Ловим Reply-кнопку «Приложение» (с эмодзи или без) и отвечаем Inline-кнопкой
from helpers import send_temp  # <-- добавь импорт

@router.message(F.text.func(lambda t: _text_contains(t, "приложение")))
async def send_app_button(message: Message):
    # Удалить сообщение пользователя в личке Telegram нельзя (обычное ограничение),
    # поэтому просто даём «временный» ответ и авто-удаляем его через 10 сек.
    await send_temp(
        message,
        "Для входа в приложение нажмите на кнопку ниже:",
        reply_markup=app_inline_kb(),
        delay=30,  # через 30 сек исчезнет
    )


@router.message(F.text.func(lambda t: _text_contains(t, "управление программами")))
async def send_admin_button(message: Message):
    user = await reg_db.user.find_unique(where={"tg_id": message.from_user.id})
    role = getattr(user, "role", None) if user else None
    is_staff = role in ("admin", "sadmin", "trainer") or bool(getattr(user, "isCurator", False))
    if not is_staff:
        await send_temp(message, "Доступ закрыт. Нужна роль admin, sadmin, trainer или куратор.", delay=30)
        return

    await send_temp(
        message,
        "Для входа в админку нажмите на кнопку ниже:",
        reply_markup=admin_inline_kb(),
        delay=30,
    )
