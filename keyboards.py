from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton,
    InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo
)
import os

APP_URL = os.getenv("APP_URL")
if not APP_URL:
    raise RuntimeError("Не задан APP_URL в .env")

def _build_admin_url(app_url: str) -> str:
    if app_url.endswith(".html"):
        return f"{app_url.rsplit('/', 1)[0]}/admin_programs.html"
    return f"{app_url.rstrip('/')}/admin_programs.html"

ADMIN_URL = os.getenv("ADMIN_URL") or _build_admin_url(APP_URL)



def client_kb(has_tariff: bool = False, is_admin: bool = False) -> ReplyKeyboardMarkup:
    if not has_tariff:
        # Меню до покупки (Reply-клавиатура)
        rows = [
            [KeyboardButton(text="Подробное описание")],
            [KeyboardButton(text="Тариф"), KeyboardButton(text="Профиль")],
            [KeyboardButton(text="Бесплатная консультация")],
        ]
    else:
        # Меню после покупки (Reply-клавиатура, без web_app)
        rows = [
            [KeyboardButton(text="Тариф"), KeyboardButton(text="Профиль")],
            [KeyboardButton(text="Приложение")],  # просто текст, обрабатываем в хендлере
        ]
    if is_admin:
        rows.append([
            KeyboardButton(
                text="Управление программами",
                web_app=WebAppInfo(url=ADMIN_URL)
            )
        ])

    return ReplyKeyboardMarkup(
        keyboard=rows,
        resize_keyboard=True,
        one_time_keyboard=False,
    )


def client_main_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="Профиль"), KeyboardButton(text="Тариф")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
    )


def tariffs_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💼 Базовый")],
            [KeyboardButton(text="🤑 Выгодный")],
            [KeyboardButton(text="💎 Максимум")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
    )


def tariff_detail_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💳 Купить")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        one_time_keyboard=False,
    )


def empty_kb() -> ReplyKeyboardMarkup:
    # Пустая reply-клавиатура, чтобы Telegram не поднимал системную клавиатуру устройства
    return ReplyKeyboardMarkup(
        keyboard=[],
        resize_keyboard=True,
    )


# Инлайн-клава с рабочей web_app-кнопкой
def app_inline_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [
                InlineKeyboardButton(
                    text="🚀 Открыть приложение",
                    web_app=WebAppInfo(url=APP_URL)
                )
            ]
        ]
    )
