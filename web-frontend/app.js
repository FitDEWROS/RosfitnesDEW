(function () {
  const tg = window.Telegram?.WebApp || null;
  const qs = new URLSearchParams(location.search);
  const API_BASE = window.ENV?.API_BASE || "https://fitdewros-rosfitnesdew-a720.twc1.net";

  const greetingEl = document.getElementById("greeting");
  const tariffEl = document.getElementById("tariff");
  const heroKcalEl = document.getElementById("heroKcal");
  const macroProteinEl = document.getElementById("macroProtein");
  const macroFatEl = document.getElementById("macroFat");
  const macroCarbEl = document.getElementById("macroCarb");
  const metricWeightEl = document.getElementById("metricWeight");
  const metricWeightStatusEl = document.getElementById("metricWeightStatus");
  const metricWaterEl = document.getElementById("metricWater");
  const metricWaterStatusEl = document.getElementById("metricWaterStatus");
  const metricMealsEl = document.getElementById("metricMeals");
  const metricMealsStatusEl = document.getElementById("metricMealsStatus");
  const themeToggleBtn = document.getElementById("themeToggle");

  const profileBtn = document.getElementById("profileBtn");
  const profileModal = document.getElementById("profileModal");
  const closeProfile = document.getElementById("closeProfile");
  const profileNameEl = document.getElementById("profileName");
  const profileUsernameEl = document.getElementById("profileUsername");
  const profileIdEl = document.getElementById("profileId");
  const profileTariffEl = document.getElementById("profileTariff");
  const profileHeightEl = document.getElementById("profileHeight");
  const profileWeightEl = document.getElementById("profileWeight");
  const profileAgeEl = document.getElementById("profileAge");
  const profilePhotoEl = document.getElementById("profilePhoto");
  const editHeightEl = document.getElementById("editHeight");
  const editWeightEl = document.getElementById("editWeight");
  const editAgeEl = document.getElementById("editAge");
  const saveProfileBtn = document.getElementById("saveProfile");
  const profileSaveStatusEl = document.getElementById("profileSaveStatus");

  const buildInitData = () => {
    const raw = tg?.initData || "";
    if (raw && raw.length > 0) return raw;

    const u = tg?.initDataUnsafe || null;
    if (!u || !u.hash) return "";

    const p = new URLSearchParams();
    if (u.query_id) p.set("query_id", u.query_id);
    if (u.user) p.set("user", JSON.stringify(u.user));
    if (u.auth_date) p.set("auth_date", String(u.auth_date));
    if (u.start_param) p.set("start_param", u.start_param);
    if (u.chat_type) p.set("chat_type", u.chat_type);
    if (u.chat_instance) p.set("chat_instance", u.chat_instance);
    p.set("hash", u.hash);

    return p.toString();
  };

  const readNumber = (value) => {
    if (value === null || value === undefined || value === "") return null;
    const normalized = String(value).replace(",", ".");
    const num = Number(normalized);
    return Number.isFinite(num) ? num : null;
  };

  const formatWhole = (value, fallback = "0") => {
    if (!Number.isFinite(value)) return fallback;
    return Math.round(value).toLocaleString("ru-RU");
  };

  const formatSimple = (value, fallback = "0") => {
    if (!Number.isFinite(value)) return fallback;
    const rounded = Math.round(value * 10) / 10;
    return rounded % 1 === 0 ? String(rounded.toFixed(0)) : String(rounded.toFixed(1));
  };

  const applyNutritionEntry = (entry) => {
    const kcal = readNumber(entry?.kcal);
    const protein = readNumber(entry?.protein);
    const fat = readNumber(entry?.fat);
    const carb = readNumber(entry?.carb);
    const water = readNumber(entry?.waterLiters);
    const meals = readNumber(entry?.mealsCount);

    if (heroKcalEl) heroKcalEl.textContent = formatWhole(kcal);
    if (macroProteinEl) macroProteinEl.textContent = formatWhole(protein);
    if (macroFatEl) macroFatEl.textContent = formatWhole(fat);
    if (macroCarbEl) macroCarbEl.textContent = formatWhole(carb);

    if (metricWaterEl) {
      metricWaterEl.textContent = formatSimple(water, "0");
      if (metricWaterStatusEl) {
        metricWaterStatusEl.textContent = water && water > 0 ? "Заполнено" : "Нет данных";
      }
    }

    if (metricMealsEl) {
      metricMealsEl.textContent = formatWhole(meals, "0");
      if (metricMealsStatusEl) {
        metricMealsStatusEl.textContent = meals && meals > 0 ? "Заполнено" : "Нет данных";
      }
    }
  };

  const applyTrainingMode = (mode) => {
    if (!mode) return;
    localStorage.setItem("training_mode", mode);
    const toggle = document.getElementById("modeToggle");
    if (toggle) toggle.dataset.mode = mode;
  };

  const setupModeToggle = () => {
    const toggle = document.getElementById("modeToggle");
    if (!toggle) return;

    const savedMode = localStorage.getItem("training_mode") || "gym";
    toggle.dataset.mode = savedMode;

    toggle.querySelectorAll(".toggle-option").forEach((opt) => {
      opt.addEventListener("click", async () => {
        const newMode = opt.dataset.mode;
        if (!newMode) return;
        toggle.dataset.mode = newMode;
        localStorage.setItem("training_mode", newMode);

        const tgId = tg?.initDataUnsafe?.user?.id;
        if (API_BASE && tgId) {
          try {
            await fetch(`${API_BASE}/api/mode`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ tg_id: tgId, mode: newMode })
            });
          } catch (err) {
            console.warn("Ошибка при обновлении режима:", err);
          }
        }
      });
    });
  };

  const fetchUserAndRender = async (initData) => {
    try {
      const url = `${API_BASE}/api/user?initData=${encodeURIComponent(initData)}`;
      const res = await fetch(url);
      const json = await res.json().catch(() => ({}));

      if (!json?.ok) {
        console.warn("[api/user] Неудача", json);
        return;
      }

      const name = json.profile?.fio || json.profile?.first_name || json.user?.first_name || "Гость";
      const username = json.user?.username ? `@${json.user.username}` : "Нет никнейма";
      const id = json.user?.id || "-";
      const tariff = json.profile?.tariffName || "Без тарифа";
      const heightCm = json.profile?.heightCm ?? null;
      const weightKg = json.profile?.weightKg ?? null;
      const age = json.profile?.age ?? null;
      const trainingMode = json.profile?.trainingMode || null;
      const photoUrl = json.user?.photo_url || "";

      if (greetingEl) greetingEl.textContent = name;
      if (tariffEl) tariffEl.textContent = tariff;
      renderTilesByTariff(tariff);
      applyTrainingMode(trainingMode);

      if (profileNameEl) profileNameEl.textContent = name;
      if (profileUsernameEl) profileUsernameEl.textContent = username;
      if (profileIdEl) profileIdEl.textContent = id;
      if (profileTariffEl) profileTariffEl.textContent = tariff;
      if (profileHeightEl) profileHeightEl.textContent = heightCm ?? "-";
      if (profileWeightEl) profileWeightEl.textContent = weightKg ?? "-";
      if (profileAgeEl) profileAgeEl.textContent = age ?? "-";
      if (profilePhotoEl) profilePhotoEl.src = photoUrl || "default-avatar.png";
      if (editHeightEl) editHeightEl.value = heightCm ?? "";
      if (editWeightEl) editWeightEl.value = weightKg ?? "";
      if (editAgeEl) editAgeEl.value = age ?? "";

      const avatarThumb = document.getElementById("avatarThumb");
      if (avatarThumb) avatarThumb.src = photoUrl || "default-avatar.png";

      if (metricWeightEl) {
        if (typeof weightKg === "number" && Number.isFinite(weightKg)) {
          metricWeightEl.textContent = formatSimple(weightKg, "-");
          if (metricWeightStatusEl) metricWeightStatusEl.textContent = "Профиль";
        } else {
          metricWeightEl.textContent = "-";
          if (metricWeightStatusEl) metricWeightStatusEl.textContent = "Нет данных";
        }
      }
    } catch (e) {
      console.error("[api/user] Ошибка запроса", e);
      if (tariffEl) tariffEl.textContent = "Нет связи";
    }
  };

  const saveProfile = async () => {
    if (!API_BASE) return false;
    const initData = buildInitData();
    if (!initData) return false;

    const payload = {
      initData,
      heightCm: readNumber(editHeightEl?.value),
      weightKg: readNumber(editWeightEl?.value),
      age: readNumber(editAgeEl?.value)
    };

    try {
      const res = await fetch(`${API_BASE}/api/profile`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const json = await res.json().catch(() => ({}));
      if (!json?.ok) return false;

      const profile = json.profile || {};
      if (profileHeightEl) profileHeightEl.textContent = profile.heightCm ?? "-";
      if (profileWeightEl) profileWeightEl.textContent = profile.weightKg ?? "-";
      if (profileAgeEl) profileAgeEl.textContent = profile.age ?? "-";
      if (editHeightEl) editHeightEl.value = profile.heightCm ?? "";
      if (editWeightEl) editWeightEl.value = profile.weightKg ?? "";
      if (editAgeEl) editAgeEl.value = profile.age ?? "";

      if (metricWeightEl) {
        if (typeof profile.weightKg === "number" && Number.isFinite(profile.weightKg)) {
          metricWeightEl.textContent = formatSimple(profile.weightKg, "-");
          if (metricWeightStatusEl) metricWeightStatusEl.textContent = "Профиль";
        } else {
          metricWeightEl.textContent = "-";
          if (metricWeightStatusEl) metricWeightStatusEl.textContent = "Нет данных";
        }
      }

      return true;
    } catch (e) {
      console.error("[api/profile] Ошибка запроса", e);
      return false;
    }
  };

  const renderTilesByTariff = (tariff) => {
    const tiles = document.getElementById("tiles");
    if (!tiles) return;

    tiles.innerHTML = "";
    const actions = [
      {
        key: "workouts",
        label: "??????????",
        desc: "???????, ?????? ? ????????."
      },
      {
        key: "programs",
        label: "?????????",
        desc: "??????? ????? ? ??????????."
      }
    ];

    actions.forEach((action, idx) => {
      const tile = document.createElement("button");
      tile.className = "action-card tile";
      tile.dataset.action = action.key;
      tile.classList.add("tile--reveal");
      if (idx === 0) tile.classList.add("tile--accent");
      tile.style.animationDelay = `${idx * 80}ms`;

      tile.innerHTML = `
        <div class="title">${action.label}</div>
        <div class="desc">${action.desc}</div>
      `;

      tile.addEventListener("click", () => {
        if (action.key === "workouts") {
          const mode = localStorage.getItem("training_mode") || "gym";
          window.location.href = mode === "crossfit" ? "crossfit_exercises.html" : "exercises.html";
        } else {
          const mode = localStorage.getItem("training_mode") || "gym";
          window.location.href = `programs.html?type=${encodeURIComponent(mode)}`;
        }
      });

      tiles.appendChild(tile);
    });
  };

  const fetchNutrition = async (initData) => {
    if (!API_BASE || !initData) return;
    try {
      const url = `${API_BASE}/api/nutrition?initData=${encodeURIComponent(initData)}`;
      const res = await fetch(url);
      const json = await res.json().catch(() => ({}));
      if (json?.ok) {
        applyNutritionEntry(json.entry || {});
      }
    } catch (e) {
      console.error("[api/nutrition] Ошибка запроса", e);
    }
  };

  const showAlert = (msg) => (tg?.showAlert ? tg.showAlert(msg) : alert(msg));
  const waitReady = () => { try { tg?.ready?.(); } catch (_) {} };

  let isDark = true;

  const clearInlineVars = () => {
    const r = document.documentElement;
    ["--bg", "--text", "--card", "--card-border", "--accent"].forEach((k) => r.style.removeProperty(k));
  };

  const applyTheme = () => {
    clearInlineVars();
    if (isDark) {
      document.documentElement.classList.remove("light");
      if (themeToggleBtn) themeToggleBtn.textContent = "🌙";
      localStorage.setItem("theme", "dark");
    } else {
      document.documentElement.classList.add("light");
      if (themeToggleBtn) themeToggleBtn.textContent = "☀️";
      localStorage.setItem("theme", "light");
    }
  };

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

  if (profileBtn) profileBtn.addEventListener("click", () => profileModal?.classList.add("show"));
  if (closeProfile) closeProfile.addEventListener("click", () => profileModal?.classList.remove("show"));
  window.addEventListener("click", (e) => {
    if (e.target === profileModal) profileModal.classList.remove("show");
  });

  if (saveProfileBtn) {
    saveProfileBtn.addEventListener("click", async () => {
      if (profileSaveStatusEl) profileSaveStatusEl.textContent = "Сохранение...";
      const ok = await saveProfile();
      if (profileSaveStatusEl) {
        profileSaveStatusEl.textContent = ok ? "Сохранено" : "Ошибка сохранения";
        setTimeout(() => { profileSaveStatusEl.textContent = ""; }, 2000);
      }
    });
  }

  const navProfile = document.getElementById("navProfile");
  if (navProfile) {
    navProfile.addEventListener("click", () => {
      if (profileBtn) profileBtn.click();
    });
  }

  const navItems = document.querySelectorAll(".nav-item[data-scroll]");
  if (navItems.length) {
    navItems.forEach((btn) => {
      btn.addEventListener("click", () => {
        const target = btn.getAttribute("data-scroll");
        if (target === "body") {
          window.scrollTo({ top: 0, behavior: "smooth" });
        } else if (target) {
          const el = document.querySelector(target);
          if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
        }
        navItems.forEach((b) => b.classList.remove("is-active"));
        btn.classList.add("is-active");
      });
    });
  }

  setupModeToggle();

  async function init() {
    try {
      if (tg) {
        waitReady();
        tg.expand?.();

        const u = tg.initDataUnsafe?.user;
        if (u?.first_name && greetingEl) greetingEl.textContent = u.first_name;
      }

      const qpTariff = qs.get("tariff");
      if (qpTariff && tariffEl) tariffEl.textContent = qpTariff;

      if (API_BASE && tg) {
        const initData = buildInitData();
        if (initData) {
          await fetch(`${API_BASE}/api/validate?initData=${encodeURIComponent(initData)}`).catch(() => ({}));
          await fetchUserAndRender(initData);
          await fetchNutrition(initData);
        }
      }
    } catch (e) {
      console.error("Ошибка инициализации", e);
      showAlert("Ошибка инициализации приложения");
    }
  }

  window.API_BASE = API_BASE;
  window.tg = tg;
  window.buildInitData = buildInitData;
  window.renderTilesByTariff = renderTilesByTariff;

  init();
})();
