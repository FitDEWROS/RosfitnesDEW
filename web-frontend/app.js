(function () {
  const tg = window.Telegram?.WebApp || null;
  const qs = new URLSearchParams(location.search);
  const API_BASE = window.ENV?.API_BASE || "";

  const greetingEl  = document.getElementById('greeting');
  const tariffEl    = document.getElementById('tariff');
  const themeToggleBtn = document.getElementById("themeToggle"); // кнопка-лампочка

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

      const name = json.profile?.first_name || json.user?.first_name || 'друг';
      const tariff = json.profile?.tariffName || 'неизвестно';

      greetingEl.textContent = `Привет, ${name}!`;
      tariffEl.textContent = `Тариф: ${tariff}`;
      renderTilesByTariff(tariff);
    } catch (e) {
      console.error('[api/user] ❌ Ошибка запроса', e);
      tariffEl.textContent = "Тариф: ошибка";
    }
  }

  function renderTilesByTariff(tariff) {
    const tiles = document.getElementById("tiles");
    if (!tiles) return;

    tiles.innerHTML = "";
    let actions = [];

    if (tariff === "Базовый") {
      actions = ["Тренировки", "Дневник тренировок", "Дневник питания", "Упражнения"];
    } else if (tariff === "Выгодный") {
      actions = ["Тренировки", "Дневник тренировок", "Дневник питания", "Упражнения", "Связь с куратором"];
    } else if (tariff === "Максимальный") {
      actions = ["Тренировки", "Дневник тренировок", "Дневник питания", "Упражнения", "Связь с куратором"];
    } else {
      actions = ["Тренировки", "Дневник тренировок", "Дневник питания", "Упражнения"];
    }

    actions.forEach(label => {
      const tile = document.createElement("button");
      tile.className = "tile";
      tile.dataset.action = label;
      tile.innerHTML = `
        <div class="title">${label}</div>
        <div class="desc">Раздел в разработке</div>
      `;
      tile.addEventListener("click", () => showAlert(`«${label}» — раздел в разработке`));
      tiles.appendChild(tile);
    });
  }

  const setCSSFromTheme = (p = {}) => {
    const map = {
      '--bg':     p.bg_color,
      '--text':   p.text_color,
      '--card':   p.secondary_bg_color,
      '--card-2': p.section_bg_color,
    };
    for (const [k, v] of Object.entries(map)) {
      if (v) document.documentElement.style.setProperty(k, v);
    }
  };

  const showAlert = (msg) => (tg?.showAlert ? tg.showAlert(msg) : alert(msg));
  const waitReady = () => { try { tg?.ready?.(); } catch (_) {} };

  async function init() {
    try {
      console.log(">>> INIT: запуск WebApp");
      if (tg) {
        waitReady();
        tg.expand?.();
        setCSSFromTheme(tg.themeParams || {});
        const u = tg.initDataUnsafe?.user;
        if (u?.first_name) greetingEl.textContent = `Привет, ${u.first_name}!`;
      }

      const qpTariff = qs.get('tariff');
      if (qpTariff) {
        tariffEl.textContent = `Тариф: ${qpTariff}`;
      }

      if (API_BASE && tg) {
        console.log(">>> API_BASE:", API_BASE);
        const initData = buildInitData();
        console.log(">>> initData:", initData);

        await fetch(`${API_BASE}/api/validate?initData=${encodeURIComponent(initData)}`).catch(() => ({}));
        await fetchUserAndRender(initData);
      } else {
        console.warn("❌ API_BASE или Telegram WebApp не определены");
      }
    } catch (e) {
      console.error("❌ Ошибка инициализации", e);
      showAlert('Ошибка инициализации приложения');
    }
  }

  // -------------------------------
  // Переключатель темы 🌙 / ☀️
  // -------------------------------
  let isDark = true;

  function applyTheme() {
    if (isDark) {
      document.documentElement.style.setProperty("--bg", "#121212");
      document.documentElement.style.setProperty("--text", "#ffffff");
      document.documentElement.style.setProperty("--card", "#1e1e1e");
      themeToggleBtn.textContent = "🌙";
    } else {
      document.documentElement.style.setProperty("--bg", "#ffffff");
      document.documentElement.style.setProperty("--text", "#000000");
      document.documentElement.style.setProperty("--card", "#f5f5f5");
      themeToggleBtn.textContent = "☀️";
    }
  }

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener("click", () => {
      isDark = !isDark;
      applyTheme();
    });
  }

  // применяем тему сразу при загрузке
  applyTheme();

  // DEBUG EXPORTS
  window.API_BASE = API_BASE;
  window.tg = tg;
  window.buildInitData = buildInitData;

  console.log("tg.initData:", tg?.initData);
  console.log("tg.initDataUnsafe:", tg?.initDataUnsafe);

  init();
})();
