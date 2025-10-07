(function () {
  const tg = window.Telegram?.WebApp || null;
  const qs = new URLSearchParams(location.search);
  const API_BASE = window.ENV?.API_BASE || "";

  const greetingEl = document.getElementById('greeting');
  const tariffEl = document.getElementById('tariff');
  const themeToggleBtn = document.getElementById("themeToggle");
  const USE_TG_THEME = false; // ← запрещаем любые цвета из Telegram

  // 🔹 Элементы профиля
  const profileBtn = document.getElementById("profileBtn");
  const profileModal = document.getElementById("profileModal");
  const closeProfile = document.getElementById("closeProfile");
  const profileNameEl = document.getElementById("profileName");
  const profileUsernameEl = document.getElementById("profileUsername");
  const profileIdEl = document.getElementById("profileId");
  const profileTariffEl = document.getElementById("profileTariff");
  const profilePhotoEl = document.getElementById("profilePhoto");

  // -------------------------------
  // Формируем initData для API
  // -------------------------------
  function buildInitData() {
    const raw = tg?.initData || '';
    if (raw && raw.length > 0) return raw;

    const u = tg?.initDataUnsafe || null;
    if (!u || !u.hash) return '';

    const p = new URLSearchParams();
    if (u.query_id) p.set('query_id', u.query_id);
    if (u.user) p.set('user', JSON.stringify(u.user));
    if (u.auth_date) p.set('auth_date', String(u.auth_date));
    if (u.start_param) p.set('start_param', u.start_param);
    if (u.chat_type) p.set('chat_type', u.chat_type);
    if (u.chat_instance) p.set('chat_instance', u.chat_instance);
    p.set('hash', u.hash);

    return p.toString();
  }

  // -------------------------------
  // Получение данных юзера и рендер
  // -------------------------------
  async function fetchUserAndRender(initData) {
    try {
      const url = `${API_BASE}/api/user?initData=${encodeURIComponent(initData)}`;
      console.log("[api/user] ➜", url);

      const res = await fetch(url);
      const json = await res.json().catch(() => ({}));

      console.log("[api/user] ⬅", json);

      if (!json?.ok) {
        console.warn("[api/user] ⚠ Неудача", json);
        return;
      }

      const name = json.profile?.fio || json.profile?.first_name || json.user?.first_name || "друг";
      const username = json.user?.username ? `@${json.user.username}` : "не указан";
      const id = json.user?.id || "-";
      const tariff = json.profile?.tariffName || "неизвестно";
      const photoUrl = json.user?.photo_url || "";

      // приветствие
      greetingEl.textContent = `Привет, ${name}!`;
      tariffEl.textContent = `Тариф: ${tariff}`;
      renderTilesByTariff(tariff);

      // профиль в модалке
      profileNameEl.textContent = name;
      profileUsernameEl.textContent = username;
      profileIdEl.textContent = id;
      profileTariffEl.textContent = tariff;
      if (profilePhotoEl) {
        profilePhotoEl.src = photoUrl || "default-avatar.png";
      }

    } catch (e) {
      console.error("[api/user] ❌ Ошибка запроса", e);
      tariffEl.textContent = "Тариф: ошибка";
    }
  }

  // -------------------------------
  // Плитки по тарифу
  // -------------------------------
  function renderTilesByTariff(tariff) {
    const tiles = document.getElementById("tiles");
    if (!tiles) return;

    tiles.innerHTML = "";
    let actions = [];

    if (tariff === "Базовый") {
      actions = ["Тренировки", "Дневник питания", "Упражнения"];
    } else if (tariff === "Выгодный" || tariff === "Максимальный") {
      actions = ["Тренировки", "Дневник питания", "Упражнения", "Связь с куратором"];
    } else {
      actions = ["Тренировки", "Дневник питания", "Упражнения"];
    }

    actions.forEach(label => {
      const tile = document.createElement("button");
      tile.className = "tile";
      tile.dataset.action = label;
      tile.innerHTML = `
        <div class="title">${label}</div>
        <div class="desc">${label === "Упражнения" ? "Выбор мышц и упражнений" : "Раздел в разработке"}</div>
      `;

      tile.addEventListener("click", () => {
        if (label === "Упражнения") {
          const mode = localStorage.getItem("training_mode") || "gym";
          if (mode === "crossfit") {
            window.location.href = "crossfit_exercises.html";
          } else {
            window.location.href = "exercises.html";
          }
        } else {
          showAlert(`«${label}» — раздел в разработке`);
        }
      });

      tiles.appendChild(tile);
    });
  }

  // -------------------------------
  // Стили Telegram темы
  // -------------------------------
  const setCSSFromTheme = (p = {}) => {
    if (!USE_TG_THEME) return;
  };

  const showAlert = (msg) => (tg?.showAlert ? tg.showAlert(msg) : alert(msg));
  const waitReady = () => { try { tg?.ready?.(); } catch (_) {} };

  // -------------------------------
  // Тема 🌙 / ☀️
  // -------------------------------
  let isDark = true;

  function applyTheme() {
    clearInlineVars();
    if (isDark) {
      document.documentElement.classList.remove("light");
      themeToggleBtn.textContent = "🌙";
      localStorage.setItem("theme", "dark");
    } else {
      document.documentElement.classList.add("light");
      themeToggleBtn.textContent = "☀️";
      localStorage.setItem("theme", "light");
    }
  }

  function clearInlineVars() {
    const r = document.documentElement;
    ['--bg', '--text', '--card', '--card-border', '--accent'].forEach(k => r.style.removeProperty(k));
  }

  const savedTheme = localStorage.getItem("theme");
  if (savedTheme) {
    isDark = savedTheme === "dark";
  }
  applyTheme();

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener("click", () => {
      isDark = !isDark;
      applyTheme();
    });
  }

  // -------------------------------
  // Модалка профиля
  // -------------------------------
  if (profileBtn) {
    profileBtn.addEventListener("click", () => profileModal.classList.remove("hidden"));
  }
  if (closeProfile) {
    closeProfile.addEventListener("click", () => profileModal.classList.add("hidden"));
  }
  window.addEventListener("click", (e) => {
    if (e.target === profileModal) profileModal.classList.add("hidden");
  });

  // -------------------------------
  // 🔀 Тумблер режима
  // -------------------------------
  document.addEventListener("DOMContentLoaded", async () => {
    const modeBtns = document.querySelectorAll(".mode-btn");
    const savedMode = localStorage.getItem("training_mode") || "gym";

    // активируем нужную кнопку
    modeBtns.forEach(btn => {
      btn.classList.toggle("active", btn.dataset.mode === savedMode);
    });

    // обработчик переключения
    modeBtns.forEach(btn => {
      btn.addEventListener("click", async () => {
        const newMode = btn.dataset.mode;
        localStorage.setItem("training_mode", newMode);

        modeBtns.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");

        const tgUser = window.Telegram?.WebApp?.initDataUnsafe?.user;
        if (tgUser?.id) {
          try {
            await fetch("/api/mode", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ tg_id: tgUser.id, mode: newMode })
            });
          } catch (err) {
            console.warn("⚠ Ошибка при обновлении режима:", err);
          }
        }

        // 🔁 перерисовка плиток под выбранный режим
        const tariff = document.getElementById("tariff").textContent.replace("Тариф: ", "") || "Базовый";
        renderTilesByTariff(tariff);
      });
    });
  });

  // -------------------------------
  // Инициализация
  // -------------------------------
  async function init() {
    try {
      console.log(">>> INIT: запуск WebApp");
      if (tg) {
        waitReady();
        tg.expand?.();

        const u = tg.initDataUnsafe?.user;
        if (u?.first_name) greetingEl.textContent = `Привет, ${u.first_name}!`;
      }

      const qpTariff = qs.get('tariff');
      if (qpTariff) tariffEl.textContent = `Тариф: ${qpTariff}`;

      if (API_BASE && tg) {
        const initData = buildInitData();
        await fetch(`${API_BASE}/api/validate?initData=${encodeURIComponent(initData)}`).catch(() => ({}));
        await fetchUserAndRender(initData);
      }
    } catch (e) {
      console.error("❌ Ошибка инициализации", e);
      showAlert("Ошибка инициализации приложения");
    }
  }

  window.API_BASE = API_BASE;
  window.tg = tg;
  window.buildInitData = buildInitData;

  init();
})();
