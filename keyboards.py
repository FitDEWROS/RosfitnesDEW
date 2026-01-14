from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton,
    InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo
)
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
import os

APP_URL_RAW = os.getenv("APP_URL")
if not APP_URL_RAW:
    raise RuntimeError("Не задан APP_URL в .env")

APP_VERSION = os.getenv("APP_VERSION", "20260115")

def _with_version(url: str, version: str) -> str:
    if not version:
        return url
    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["v"] = version
    new_query = urlencode(query, doseq=True)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, new_query, parts.fragment))

def _build_admin_url(app_url: str) -> str:
    parts = urlsplit(app_url)
    path = parts.path or "/"
    if path.endswith(".html"):
        base_path = path.rsplit("/", 1)[0]
    else:
        base_path = path.rstrip("/")
    admin_path = f"{base_path}/admin_programs.html"
    return urlunsplit((parts.scheme, parts.netloc, admin_path, "", ""))

ADMIN_URL_RAW = os.getenv("ADMIN_URL") or _build_admin_url(APP_URL_RAW)

APP_URL = _with_version(APP_URL_RAW, APP_VERSION)
ADMIN_URL = _with_version(ADMIN_URL_RAW, APP_VERSION)



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
