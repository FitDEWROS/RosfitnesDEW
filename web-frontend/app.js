(function () {
  const tg = window.Telegram?.WebApp || null;
  const qs = new URLSearchParams(location.search);
  const API_BASE = window.ENV?.API_BASE || "";

  const greetingEl  = document.getElementById('greeting');
  const tariffEl    = document.getElementById('tariff');
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
    if (u.query_id)      p.set('query_id', u.query_id);
    if (u.user)          p.set('user', JSON.stringify(u.user));
    if (u.auth_date)     p.set('auth_date', String(u.auth_date));
    if (u.start_param)   p.set('start_param', u.start_param);
    if (u.chat_type)     p.set('chat_type', u.chat_type);
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
      window.location.href = "exercises.html"; // 🔹 переход на страницу упражнений
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
  // Стили Telegram темы — отключены
  const setCSSFromTheme = (p = {}) => {
    if (!USE_TG_THEME) return; // ничего не делаем
    // Если когда-нибудь захочешь — убери return и раскоммить код ниже
    /*
    const r = document.documentElement;
    if (p.bg_color)            r.style.setProperty('--bg', p.bg_color);
    if (p.text_color)          r.style.setProperty('--text', p.text_color);
    if (p.secondary_bg_color)  r.style.setProperty('--card', p.secondary_bg_color);
    if (p.section_bg_color)    r.style.setProperty('--card-border', p.section_bg_color);
    // под свой акцент — по желанию:
    // if (p.link_color)       r.style.setProperty('--accent', p.link_color);
    */
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
    ['--bg','--text','--card','--card-border','--accent'].forEach(k => r.style.removeProperty(k));
  }

  const savedTheme = localStorage.getItem("theme");
  if (savedTheme) {
    isDark = savedTheme === "dark";
  }
  // никаких цветов из Telegram
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
