(function () {
  const tg = window.Telegram?.WebApp || null;
  const qs = new URLSearchParams(location.search);
  const API_BASE = window.ENV?.API_BASE || "https://fitdewros-rosfitnesdew-a720.twc1.net";
  const openChatOnLoad = qs.get("openChat") === "1";

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
  const nutritionLink = document.getElementById("nutritionLink");
  const nutritionHero = document.getElementById("nutritionHero");
  const metricWaterCard = document.getElementById("metricWaterCard");
  const metricMealsCard = document.getElementById("metricMealsCard");
  const modeToggleEl = document.getElementById("modeToggle");
  const themeToggleBtn = document.getElementById("themeToggle");
  const chatFab = document.getElementById("chatFab");
  const chatBadge = document.getElementById("chatBadge");
  const chatModal = document.getElementById("chatModal");
  const chatCloseBtn = document.getElementById("chatClose");
  const chatMessagesEl = document.getElementById("chatMessages");
  const chatInputEl = document.getElementById("chatInput");
  const chatSendBtn = document.getElementById("chatSend");
  const chatSubtitleEl = document.getElementById("chatSubtitle");
  const chatAttachBtn = document.getElementById("chatAttach");
  const chatFileInput = document.getElementById("chatFile");

  const profileBtn = document.getElementById("profileBtn");
  const profileModal = document.getElementById("profileModal");
  const closeProfile = document.getElementById("closeProfile");
  const notifyBtn = document.getElementById("openNotifications");
  const notifyBadge = document.getElementById("notifyBadge");
  const profileNameEl = document.getElementById("profileName");
  const profileUsernameEl = document.getElementById("profileUsername");
  const profileIdEl = document.getElementById("profileId");
  const profileTariffEl = document.getElementById("profileTariff");
  const profileTariffExpiresEl = document.getElementById("profileTariffExpires");
  const profileTariffExpiresWrap = document.getElementById("profileTariffExpiresWrap");
  const profileHeightEl = document.getElementById("profileHeight");
  const profileWeightEl = document.getElementById("profileWeight");
  const profileAgeEl = document.getElementById("profileAge");
  const profilePhotoEl = document.getElementById("profilePhoto");
  const editHeightEl = document.getElementById("editHeight");
  const editWeightEl = document.getElementById("editWeight");
  const editAgeEl = document.getElementById("editAge");
  const saveProfileBtn = document.getElementById("saveProfile");
  const profileSaveStatusEl = document.getElementById("profileSaveStatus");
  let nutritionLocked = false;
  let chatAllowed = false;
  let chatLastId = 0;
  let chatPollTimer = null;
  let chatUnreadTimer = null;
  let chatCounterpartName = "";
  let isStaffUser = false;

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

  const formatDateOnly = (value) => {
    if (!value) return "";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    return date.toLocaleDateString("ru-RU");
  };

  const isBasicTariff = (tariff) => {
    const value = String(tariff || "").toLowerCase();
    return value.includes("базов") || value.includes("без тарифа") || value.includes("не куплен");
  };

  const isChatTariff = (tariff) => {
    const value = String(tariff || "").toLowerCase();
    return value.includes("оптимал") || value.includes("максим");
  };

  const updateChatAccess = (profile) => {
    if (!chatFab) return;
    const role = profile?.role || "user";
    const isCurator = Boolean(profile?.isCurator);
    const hasCurator = Boolean(profile?.trainer?.id);
    chatAllowed = role === "user" && !isCurator && isChatTariff(profile?.tariffName) && hasCurator;
    chatFab.hidden = !chatAllowed;

    if (chatSubtitleEl) {
      chatCounterpartName = profile?.trainer?.name || profile?.trainer?.username || "";
      chatSubtitleEl.textContent = chatCounterpartName ? `Куратор: ${chatCounterpartName}` : "Онлайн консультация";
    }
  };

  const CHAT_STATUS_SINGLE_SVG = '<svg class="chat-tick" viewBox="0 0 16 12" aria-hidden="true" focusable="false"><path d="M1 6l4 4L15 1" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  const CHAT_STATUS_DOUBLE_SVG = '<svg class="chat-tick" viewBox="0 0 22 12" aria-hidden="true" focusable="false"><path d="M1 6l4 4L15 1" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="M7 6l4 4L21 1" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  const updateChatStatus = (bubble, message) => {
    if (!bubble) return;
    const shouldShow = Boolean(message?.isMine);
    let statusEl = bubble.querySelector(".chat-status");
    if (!shouldShow) {
      if (statusEl) statusEl.remove();
      return;
    }
    if (!statusEl) {
      statusEl = document.createElement("div");
      statusEl.className = "chat-status";
      bubble.appendChild(statusEl);
    }
    statusEl.innerHTML = message.readAt ? CHAT_STATUS_DOUBLE_SVG : CHAT_STATUS_SINGLE_SVG;
    statusEl.classList.toggle("is-read", Boolean(message.readAt));
  };

  const renderChatMessage = (message) => {
    if (!chatMessagesEl || !message) return;
    const existing = message.id ? chatMessagesEl.querySelector(`[data-id="${message.id}"]`) : null;
    if (existing) {
      updateChatStatus(existing, message);
      return;
    }
    const bubble = document.createElement("div");
    bubble.className = `chat-bubble${message.isMine ? " is-mine" : ""}`;
    if (message.id) bubble.dataset.id = String(message.id);
    if (message.media?.url) {
      const mediaType = message.media.type || "";
      if (mediaType.startsWith("image/")) {
        const image = document.createElement("img");
        image.src = message.media.url;
        image.alt = message.media.name || "Image";
        image.loading = "lazy";
        bubble.appendChild(image);
      } else {
        const video = document.createElement("video");
        video.src = message.media.url;
        video.controls = true;
        video.playsInline = true;
        video.preload = "metadata";
        bubble.appendChild(video);
      }
    }
    if (message.text) {
      const textEl = document.createElement("div");
      textEl.textContent = message.text;
      bubble.appendChild(textEl);
    }
    updateChatStatus(bubble, message);
    chatMessagesEl.appendChild(bubble);
  };

  const scrollChatToBottom = () => {
    if (!chatMessagesEl) return;
    chatMessagesEl.scrollTop = chatMessagesEl.scrollHeight;
  };

  const loadChatMessages = async (opts = {}) => {
    if (!API_BASE || !chatAllowed) return;
    const initData = buildInitData();
    if (!initData) return;

    const params = new URLSearchParams();
    params.set("initData", initData);
    if (opts.afterId && Number.isFinite(opts.afterId)) {
      params.set("afterId", String(opts.afterId));
    }
    if (opts.markRead === false) params.set("markRead", "0");
    if (opts.includeLast) params.set("includeLast", "1");

    try {
      const res = await fetch(`${API_BASE}/api/chat/messages?${params.toString()}`);
      const json = await res.json().catch(() => ({}));
      if (!json?.ok) return;

      if (json.counterpart?.name && chatSubtitleEl) {
        chatSubtitleEl.textContent = `Куратор: ${json.counterpart.name}`;
      }

      const items = Array.isArray(json.messages) ? json.messages : [];
      items.forEach((msg) => {
        renderChatMessage(msg);
        if (msg.id && msg.id > chatLastId) chatLastId = msg.id;
      });

      if (items.length) scrollChatToBottom();
    } catch (e) {
      console.warn("[chat] Ошибка загрузки сообщений", e);
    }
  };

  const startChatPolling = () => {
    if (chatPollTimer) return;
    chatPollTimer = setInterval(() => {
      loadChatMessages({ afterId: chatLastId, includeLast: true });
    }, 3000);
  };

  const stopChatPolling = () => {
    if (chatPollTimer) {
      clearInterval(chatPollTimer);
      chatPollTimer = null;
    }
  };

  const openChat = async () => {
    if (!chatModal || !chatAllowed) return;
    chatModal.classList.add("is-open");
    chatModal.setAttribute("aria-hidden", "false");
    if (chatMessagesEl) chatMessagesEl.innerHTML = "";
    chatLastId = 0;
    await loadChatMessages({ markRead: true });
    updateChatBadge(0);
    startChatPolling();
    scrollChatToBottom();
    if (chatInputEl) chatInputEl.focus();
  };

  const closeChat = () => {
    if (!chatModal) return;
    chatModal.classList.remove("is-open");
    chatModal.setAttribute("aria-hidden", "true");
    stopChatPolling();
  };

  const sendChatPayload = async ({ text, media } = {}) => {
    if (!API_BASE || !chatAllowed) return;
    const initData = buildInitData();
    if (!initData) return;
    if (!text && !media) return;
    if (chatSendBtn) chatSendBtn.disabled = true;
    if (chatAttachBtn) chatAttachBtn.disabled = true;
    try {
      const payload = { initData };
      if (text) payload.text = text;
      if (media) {
        payload.mediaKey = media.key;
        payload.mediaType = media.type;
        payload.mediaName = media.name;
        payload.mediaSize = media.size;
      }
      const res = await fetch(`${API_BASE}/api/chat/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const json = await res.json().catch(() => ({}));
      if (json?.ok && json.message) {
        renderChatMessage(json.message);
        if (json.message.id && json.message.id > chatLastId) chatLastId = json.message.id;
        scrollChatToBottom();
      }
    } catch (e) {
      console.warn("[chat] Ошибка отправки сообщения", e);
    } finally {
      if (chatSendBtn) chatSendBtn.disabled = false;
      if (chatAttachBtn) chatAttachBtn.disabled = false;
    }
  };

  const uploadChatMedia = async (file) => {
    if (!API_BASE || !chatAllowed || !file) return null;
    const initData = buildInitData();
    if (!initData) return null;
    const size = file.size || 0;
    if (size <= 0) return null;
    const fileType = file.type || "";
    if (!fileType) {
      showAlert("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u043f\u0440\u0435\u0434\u0435\u043b\u0438\u0442\u044c \u0442\u0438\u043f \u0444\u0430\u0439\u043b\u0430.");
      return null;
    }
    if (!fileType.startsWith("video/") && !fileType.startsWith("image/")) {
      showAlert("\u041c\u043e\u0436\u043d\u043e \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0444\u043e\u0442\u043e \u0438\u043b\u0438 \u0432\u0438\u0434\u0435\u043e.");
      return null;
    }
    if (size > 50 * 1024 * 1024) {
      showAlert("\u0424\u0430\u0439\u043b \u0431\u043e\u043b\u044c\u0448\u0435 50 \u041c\u0411. \u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0444\u0430\u0439\u043b \u043f\u043e\u043c\u0435\u043d\u044c\u0448\u0435.");
      return null;
    }
    const res = await fetch(`${API_BASE}/api/chat/upload-url`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        initData,
        fileName: file.name || "video.mp4",
        contentType: fileType,
        size
      })
    });
    const json = await res.json().catch(() => ({}));
    if (!json?.ok || !json.uploadUrl || !json.objectKey) {
      showAlert("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0444\u0430\u0439\u043b.");
      return null;
    }
    const uploadRes = await fetch(json.uploadUrl, {
      method: "PUT",
      headers: { "Content-Type": fileType },
      body: file
    });
    if (!uploadRes.ok) {
      showAlert("\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u0444\u0430\u0439\u043b\u0430.");
      return null;
    }
    return {
      key: json.objectKey,
      type: fileType,
      name: file.name || "video.mp4",
      size
    };
  };

  const sendChatMessage = async () => {
    if (!chatInputEl) return;
    const text = chatInputEl.value.trim();
    if (!text) return;
    chatInputEl.value = "";
    await sendChatPayload({ text });
  };

  const applyNutritionAccess = (tariff) => {
    nutritionLocked = isBasicTariff(tariff);
    if (nutritionLink) {
      nutritionLink.classList.toggle("is-locked", nutritionLocked);
      nutritionLink.setAttribute("aria-disabled", nutritionLocked ? "true" : "false");
    }
    if (nutritionHero) {
      nutritionHero.classList.toggle("fog-lock", nutritionLocked);
    }
    if (metricWaterCard) {
      metricWaterCard.classList.toggle("fog-lock", nutritionLocked);
    }
    if (metricMealsCard) {
      metricMealsCard.classList.toggle("fog-lock", nutritionLocked);
    }
    if (modeToggleEl) {
      modeToggleEl.classList.toggle("is-locked", nutritionLocked);
      modeToggleEl.setAttribute("aria-disabled", nutritionLocked ? "true" : "false");
    }
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

  const updateNotificationBadge = (count) => {
    if (!notifyBadge) return;
    const value = Number(count) || 0;
    notifyBadge.textContent = value > 99 ? "99+" : String(value);
    notifyBadge.hidden = value <= 0;
  };


  const updateChatBadge = (count) => {
    if (!chatBadge) return;
    const value = Number(count) || 0;
    chatBadge.textContent = value > 99 ? "99+" : String(value);
    chatBadge.hidden = value <= 0;
  };

  const fetchChatUnreadCount = async (initData) => {
    if (!API_BASE || !initData || !chatAllowed) return;
    try {
      const url = `${API_BASE}/api/chat/unread-count?initData=${encodeURIComponent(initData)}`;
      const res = await fetch(url);
      const json = await res.json().catch(() => ({}));
      if (json?.ok) updateChatBadge(json.unreadCount);
    } catch (e) {
      console.warn("[api/chat] ?????? unread", e);
    }
  };

  const startChatUnreadPolling = (initData) => {
    if (chatUnreadTimer || !initData) return;
    fetchChatUnreadCount(initData);
    chatUnreadTimer = setInterval(() => fetchChatUnreadCount(initData), 6000);
  };

  const stopChatUnreadPolling = () => {
    if (!chatUnreadTimer) return;
    clearInterval(chatUnreadTimer);
    chatUnreadTimer = null;
  };

  const fetchNotificationsCount = async (initData) => {
    if (!API_BASE || !initData) return;
    try {
      const url = `${API_BASE}/api/notifications?initData=${encodeURIComponent(initData)}&unreadOnly=1&limit=1`;
      const res = await fetch(url);
      const json = await res.json().catch(() => ({}));
      if (json?.ok) {
        updateNotificationBadge(json.unreadCount);
      }
    } catch (e) {
      console.warn("[api/notifications] ошибка загрузки", e);
    }
  };

  const setupModeToggle = () => {
    const toggle = document.getElementById("modeToggle");
    if (!toggle) return;

    const savedMode = localStorage.getItem("training_mode") || "gym";
    toggle.dataset.mode = savedMode;

    toggle.querySelectorAll(".toggle-option").forEach((opt) => {
      opt.addEventListener("click", async () => {
        if (toggle.classList.contains("is-locked")) {
          showAlert("Переключение доступно на тарифах Оптимальный и Максимум.");
          return;
        }
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
      const tariff = json.profile?.tariffName || "\u0411\u0435\u0437 \u0442\u0430\u0440\u0438\u0444\u0430";
      const tariffExpiresAt = json.profile?.tariffExpiresAt || null;
      const role = json.profile?.role || "user";
      const isCuratorRole = role === "curator" || Boolean(json.profile?.isCurator);
      const isStaff = role === "admin" || role === "sadmin" || isCuratorRole;
      isStaffUser = isStaff;
      const tariffPaidUntil = formatDateOnly(tariffExpiresAt);
      const showPaidUntil = Boolean(tariffPaidUntil) && !isStaff;
      const displayTariff = role === "sadmin"
        ? "\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446"
        : role === "admin"
          ? "\u0410\u0434\u043c\u0438\u043d"
          : isCuratorRole
            ? "\u041a\u0443\u0440\u0430\u0442\u043e\u0440"
            : tariff;
      const effectiveTariff = isStaff ? "" : tariff;
      const heightCm = json.profile?.heightCm ?? null;
      const weightKg = json.profile?.weightKg ?? null;
      const age = json.profile?.age ?? null;
      const trainingMode = json.profile?.trainingMode || null;
      const scope = json.profile?.trainerScope || "";
      const effectiveMode = isStaff && (scope === "gym" || scope === "crossfit") ? scope : trainingMode;
      const photoUrl = json.user?.photo_url || "";

      if (greetingEl) greetingEl.textContent = name;
      if (tariffEl) tariffEl.textContent = displayTariff;
      renderTilesByTariff(effectiveTariff);
      applyNutritionAccess(effectiveTariff);
      updateChatAccess(json.profile);
      if (chatAllowed) {
        startChatUnreadPolling(initData);
      } else {
        stopChatUnreadPolling();
        updateChatBadge(0);
      }
      applyTrainingMode(effectiveMode);
      if (openChatOnLoad && chatAllowed) {
        openChat();
      }

      if (profileNameEl) profileNameEl.textContent = name;
      if (profileUsernameEl) profileUsernameEl.textContent = username;
      if (profileIdEl) profileIdEl.textContent = id;
      if (profileTariffEl) profileTariffEl.textContent = displayTariff;
      if (profileTariffExpiresEl && profileTariffExpiresWrap) {
        if (showPaidUntil) {
          profileTariffExpiresEl.textContent = tariffPaidUntil;
          profileTariffExpiresWrap.hidden = false;
        } else {
          profileTariffExpiresEl.textContent = "";
          profileTariffExpiresWrap.hidden = true;
        }
      }
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
        label: "Упражнения",
        desc: "База упражнений: зал и кроссфит."
      },
      {
        key: "programs",
        label: "Программы",
        desc: "Готовые планы и расписания."
      },
      {
        key: "useful",
        label: "Полезная информация",
        desc: "Гайды, подсказки и ответы на вопросы."
      }
    ];

    tiles.classList.toggle("is-triangle", actions.length === 3);

    actions.forEach((action, idx) => {
      const tile = document.createElement("button");
      tile.className = "action-card tile";
      tile.dataset.action = action.key;
      tile.classList.add("tile--reveal");
      if (action.key === "useful") tile.classList.add("tile--split");
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
        } else if (action.key === "programs") {
          const mode = localStorage.getItem("training_mode") || "gym";
          window.location.href = `programs.html?type=${encodeURIComponent(mode)}`;
        } else {
          window.location.href = "useful_info.html";
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

  if (tariffEl) {
    tariffEl.addEventListener("click", () => {
      if (!isStaffUser) return;
      showAlert("\u041f\u043e\u043a\u0443\u043f\u043a\u0430 \u0442\u0430\u0440\u0438\u0444\u0430 \u043d\u0435 \u0442\u0440\u0435\u0431\u0443\u0435\u0442\u0441\u044f.");
    });
  }
  const waitReady = () => { try { tg?.ready?.(); } catch (_) {} };

  if (nutritionLink) {
    nutritionLink.addEventListener("click", (e) => {
      if (!nutritionLocked) return;
      e.preventDefault();
      e.stopPropagation();
      showAlert("Дневник питания недоступен на базовом тарифе.");
    });
  }
  if (nutritionHero) {
    nutritionHero.addEventListener("click", (e) => {
      if (!nutritionLocked) return;
      e.preventDefault();
      e.stopPropagation();
      showAlert("Дневник питания недоступен на базовом тарифе.");
    });
  }

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
  if (notifyBtn) {
    notifyBtn.addEventListener("click", () => {
      const initData = buildInitData();
      const url = initData ? `notifications.html?initData=${encodeURIComponent(initData)}` : "notifications.html";
      window.location.href = url;
    });
  }
  window.addEventListener("click", (e) => {
    if (e.target === profileModal) profileModal.classList.remove("show");
  });

  if (chatFab) chatFab.addEventListener("click", openChat);
  if (chatCloseBtn) chatCloseBtn.addEventListener("click", closeChat);
  if (chatModal) {
    chatModal.addEventListener("click", (e) => {
      if (e.target === chatModal) closeChat();
    });
  }
  if (chatSendBtn) chatSendBtn.addEventListener("click", sendChatMessage);
  if (chatInputEl) {
    chatInputEl.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        sendChatMessage();
      }
    });
  }
  if (chatAttachBtn && chatFileInput) {
    chatAttachBtn.addEventListener("click", () => chatFileInput.click());
    chatFileInput.addEventListener("change", async () => {
      const file = chatFileInput.files?.[0];
      chatFileInput.value = "";
      if (!file) return;
      const media = await uploadChatMedia(file);
      if (media) {
        await sendChatPayload({ media });
      }
    });
  }

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
          if (el) {
            el.scrollIntoView({ behavior: "smooth", block: "start" });
            el.classList.remove("section-flash");
            void el.offsetWidth;
            el.classList.add("section-flash");
            setTimeout(() => el.classList.remove("section-flash"), 900);
          }
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
      if (qpTariff) applyNutritionAccess(qpTariff);

      const initData = buildInitData();
      if (!initData && !qpTariff) {
        applyNutritionAccess("\u0411\u0435\u0437 \u0442\u0430\u0440\u0438\u0444\u0430");
      }
      if (API_BASE && tg && initData) {
        await fetch(`${API_BASE}/api/validate?initData=${encodeURIComponent(initData)}`).catch(() => ({}));
        await fetchUserAndRender(initData);
        await fetchNutrition(initData);
        await fetchNotificationsCount(initData);
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
