import asyncio
from aiogram import Bot
from aiogram.types import Message, ReplyKeyboardMarkup

# Храним ID последнего «главного» сообщения для каждого пользователя
_last_keep_message_id = {}  # user_id → message_id


async def send_temp(
    message: Message, text: str, *,
    reply_markup=None, parse_mode=None, delay: int = 50,
    delete_after: bool = True, delete_user_message: bool = True
):
    """
    Сообщение, которое удаляется через delay секунд.
    Используй для уведомлений («✅ Куплено», «❌ Ошибка» и т.п.).
    """
    if reply_markup is None:
        reply_markup = ReplyKeyboardMarkup(
            keyboard=[], resize_keyboard=True, is_persistent=False
        )

    msg = await message.answer(text, reply_markup=reply_markup, parse_mode=parse_mode)

    # Запускаем задачу на удаление
    if delete_after:
        asyncio.create_task(_expire_message(message.bot, message.chat.id, msg.message_id, delay))

    # Удаляем и сообщение пользователя (чтобы не висело «Приложение» и т.п.)
    if delete_user_message:
        try:
            await message.delete()
        except Exception:
            pass

    return msg


async def _expire_message(bot: Bot, chat_id: int, message_id: int, delay: int = 50):
    """Удаляет сообщение через delay секунд (если не удалено раньше)."""
    await asyncio.sleep(delay)
    try:
        await bot.delete_message(chat_id, message_id)
    except Exception:
        pass


async def send_keep(message: Message, text: str, *, reply_markup=None, parse_mode=None):
    """
    Сообщение без удаления. Но перед этим удаляет предыдущее «главное меню»,
    чтобы в чате оставалось только одно актуальное.
    """
    user_id = message.from_user.id

    # Удаляем предыдущее меню, если было
    if user_id in _last_keep_message_id:
        try:
            await message.bot.delete_message(message.chat.id, _last_keep_message_id[user_id])
        except Exception:
            pass

    msg = await message.answer(text, reply_markup=reply_markup, parse_mode=parse_mode)

    # Запоминаем ID последнего «keep»-сообщения
    _last_keep_message_id[user_id] = msg.message_id

    # Удаляем сообщение пользователя
    try:
        await message.delete()
    except Exception:
        pass

    return msg


async def send_ephemeral(message: Message, text: str, *, reply_markup=None, parse_mode=None):
    """
    Одноразовое сообщение без удаления и без хранения ID.
    Используй для сервисных ответов.
    """
    # Удаляем сообщение пользователя
    try:
        await message.delete()
    except Exception:
        pass

    return await message.answer(text, reply_markup=reply_markup, parse_mode=parse_mode)
