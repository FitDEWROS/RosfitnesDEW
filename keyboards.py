from aiogram.types import (
    ReplyKeyboardMarkup, KeyboardButton,
    InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo
)
import os

APP_URL = os.getenv("APP_URL")


def client_kb(has_tariff: bool = False):
    if not has_tariff:
        # Меню до покупки (Reply-клавиатура)
        rows = [
            [KeyboardButton(text="Подробное описание")],
            [KeyboardButton(text="Тариф"), KeyboardButton(text="Профиль")],
            [KeyboardButton(text="Бесплатная консультация")],
        ]
        return ReplyKeyboardMarkup(
            keyboard=rows,
            resize_keyboard=True,
            is_persistent=False,
            one_time_keyboard=False,
        )
    else:
        # Меню после покупки (Inline-клавиатура с web_app)
        return InlineKeyboardMarkup(
            inline_keyboard=[
                [
                    InlineKeyboardButton(text="Тариф", callback_data="tariff"),
                    InlineKeyboardButton(text="Профиль", callback_data="profile"),
                ],
                [
                    InlineKeyboardButton(
                        text="🚀 Приложение",
                        web_app=WebAppInfo(url=APP_URL or "https://example.com")
                    )
                ]
            ]
        )


def client_main_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="Профиль"), KeyboardButton(text="Тариф")],
        ],
        resize_keyboard=True,
        is_persistent=False,
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
        is_persistent=False,
        one_time_keyboard=False,
    )


def tariff_detail_kb() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💳 Купить")],
            [KeyboardButton(text="⬅️ Назад")],
        ],
        resize_keyboard=True,
        is_persistent=False,
        one_time_keyboard=False,
    )


def empty_kb() -> ReplyKeyboardMarkup:
    # Пустая reply-клавиатура, чтобы Telegram не поднимал системную клавиатуру устройства
    return ReplyKeyboardMarkup(
        keyboard=[],
        resize_keyboard=True,
        is_persistent=False
    )
