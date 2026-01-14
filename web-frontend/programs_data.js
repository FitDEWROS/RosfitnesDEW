(function () {
  const PROGRAMS_FALLBACK = [
    {
      slug: "crossfit-busy-fullbody",
      type: "crossfit",
      title: "Для самых занятых: программа на все тело",
      subtitle: "Кроссфит • Фуллбоди",
      summary: "Короткие, но плотные тренировки для старта и тонуса.",
      description: "Тренировочная программа на все тело для новичков. Компактные занятия помогают включить все группы мышц, развить выносливость и сформировать привычку тренироваться регулярно.",
      level: "Новички",
      gender: "Универсальная",
      frequency: "3 трен/нед",
      weeksCount: 4,
      coverImage: "crossfit-amber",
      authorName: "Тестов Тест Тестович",
      authorRole: "Тренер Fit Dew",
      authorAvatar: null,
      weeks: [
        {
          index: 1,
          title: "Неделя 1",
          workouts: [
            {
              id: "w1-1",
              index: 1,
              title: "Тренировка 1",
              description: "Круговая работа, 3 раунда.",
              exercises: [
                { order: 1, label: "1a", title: "Бёрпи", details: "30 сек" },
                { order: 2, label: "1b", title: "Приседания с собственным весом", details: "20 повторов" },
                { order: 3, label: "2a", title: "Отжимания", details: "12 повторов" },
                { order: 4, label: "2b", title: "Планка", details: "40 сек" },
                { order: 5, label: "3a", title: "Махи гирей", details: "15 повторов" },
                { order: 6, label: "3b", title: "Скручивания", details: "15 повторов" },
                { order: 7, label: "4", title: "Бег на месте с высоким подъемом колен", details: "60 сек" }
              ]
            },
            {
              id: "w1-2",
              index: 2,
              title: "Тренировка 2",
              description: "Силовая + кардио.",
              exercises: [
                { order: 1, label: "1a", title: "Тяга гантели в наклоне", details: "12 повторов" },
                { order: 2, label: "1b", title: "Прыжки на тумбу", details: "10 повторов" },
                { order: 3, label: "2a", title: "Выпады назад", details: "12 повторов" },
                { order: 4, label: "2b", title: "Русские скручивания", details: "20 повторов" },
                { order: 5, label: "3a", title: "Тяга резинки к поясу", details: "15 повторов" },
                { order: 6, label: "3b", title: "Планка боковая", details: "30 сек на сторону" },
                { order: 7, label: "4", title: "Фермерская ходьба", details: "40 сек" }
              ]
            }
          ]
        },
        {
          index: 2,
          title: "Неделя 2",
          workouts: [
            {
              id: "w2-1",
              index: 1,
              title: "Тренировка 1",
              description: "Интервалы 20/10.",
              exercises: [
                { order: 1, label: "1a", title: "Джампинг-джек", details: "60 сек" },
                { order: 2, label: "1b", title: "Приседания сумо", details: "18 повторов" },
                { order: 3, label: "2a", title: "Отжимания с колен", details: "12 повторов" },
                { order: 4, label: "2b", title: "Сит-ап", details: "15 повторов" },
                { order: 5, label: "3a", title: "Гребля (или имитация)", details: "1 мин" },
                { order: 6, label: "3b", title: "Планка", details: "45 сек" },
                { order: 7, label: "4", title: "Бёрпи", details: "10 повторов" }
              ]
            },
            {
              id: "w2-2",
              index: 2,
              title: "Тренировка 2",
              description: "Выносливость + сила.",
              exercises: [
                { order: 1, label: "1a", title: "Тяга гантели в опоре", details: "12 повторов" },
                { order: 2, label: "1b", title: "Махи гирей", details: "20 повторов" },
                { order: 3, label: "2a", title: "Приседания плие", details: "15 повторов" },
                { order: 4, label: "2b", title: "Подъемы колен в упоре", details: "15 повторов" },
                { order: 5, label: "3a", title: "Прыжки через линию", details: "40 сек" },
                { order: 6, label: "3b", title: "Отжимания узким хватом", details: "10 повторов" },
                { order: 7, label: "4", title: "Бег 400 м (или 2 мин)", details: "" }
              ]
            }
          ]
        },
        {
          index: 3,
          title: "Неделя 3",
          workouts: [
            {
              id: "w3-1",
              index: 1,
              title: "Тренировка 1",
              description: "Силовой фокус + кор.",
              exercises: [
                { order: 1, label: "1a", title: "Приседания с паузой", details: "12 повторов" },
                { order: 2, label: "1b", title: "Тяга сумо с гирей", details: "12 повторов" },
                { order: 3, label: "2a", title: "Отжимания", details: "14 повторов" },
                { order: 4, label: "2b", title: "Планка на локтях", details: "50 сек" },
                { order: 5, label: "3a", title: "Выпады в стороны", details: "12 повторов" },
                { order: 6, label: "3b", title: "Скручивания велосипед", details: "20 повторов" },
                { order: 7, label: "4", title: "Бёрпи", details: "12 повторов" }
              ]
            },
            {
              id: "w3-2",
              index: 2,
              title: "Тренировка 2",
              description: "Смешанный формат.",
              exercises: [
                { order: 1, label: "1a", title: "Тяга гантели к поясу", details: "12 повторов" },
                { order: 2, label: "1b", title: "Прыжки на месте", details: "45 сек" },
                { order: 3, label: "2a", title: "Присед + жим", details: "12 повторов" },
                { order: 4, label: "2b", title: "Альпинист", details: "40 сек" },
                { order: 5, label: "3a", title: "Румынская тяга с гантелями", details: "12 повторов" },
                { order: 6, label: "3b", title: "Планка боковая", details: "35 сек" },
                { order: 7, label: "4", title: "Скакалка", details: "2 мин" }
              ]
            }
          ]
        },
        {
          index: 4,
          title: "Неделя 4",
          workouts: [
            {
              id: "w4-1",
              index: 1,
              title: "Тренировка 1",
              description: "Итоговая неделя.",
              exercises: [
                { order: 1, label: "1a", title: "Тяга в наклоне", details: "14 повторов" },
                { order: 2, label: "1b", title: "Прыжки звездочкой", details: "50 сек" },
                { order: 3, label: "2a", title: "Приседания", details: "20 повторов" },
                { order: 4, label: "2b", title: "Скручивания", details: "20 повторов" },
                { order: 5, label: "3a", title: "Махи гирей", details: "20 повторов" },
                { order: 6, label: "3b", title: "Планка", details: "60 сек" },
                { order: 7, label: "4", title: "Бёрпи", details: "14 повторов" }
              ]
            },
            {
              id: "w4-2",
              index: 2,
              title: "Тренировка 2",
              description: "Кардио + тонус.",
              exercises: [
                { order: 1, label: "1a", title: "Выпады вперед", details: "12 повторов" },
                { order: 2, label: "1b", title: "Отжимания", details: "12 повторов" },
                { order: 3, label: "2a", title: "Тяга резинки", details: "15 повторов" },
                { order: 4, label: "2b", title: "Альпинист", details: "45 сек" },
                { order: 5, label: "3a", title: "Приседания сумо", details: "18 повторов" },
                { order: 6, label: "3b", title: "Русские скручивания", details: "25 повторов" },
                { order: 7, label: "4", title: "Бег 600 м (или 3 мин)", details: "" }
              ]
            }
          ]
        }
      ]
    }
  ];

  window.PROGRAMS_FALLBACK = PROGRAMS_FALLBACK;
})();
