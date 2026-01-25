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
  const openWeightModalBtn = document.getElementById("openWeightModal");
  const weightModal = document.getElementById("weightModal");
  const closeWeightBtn = document.getElementById("closeWeight");
  const weightInputEl = document.getElementById("weightInput");
  const weightSaveBtn = document.getElementById("weightSave");
  const weightSaveStatusEl = document.getElementById("weightSaveStatus");
  const weightWeekLabelEl = document.getElementById("weightWeekLabel");
  const weightHistoryEl = document.getElementById("weightHistory");
  const weightPhotosEl = document.getElementById("weightPhotos");
  const weightChartEl = document.getElementById("weightChart");
  const weightChartSvg = document.getElementById("weightChartSvg");
  const weightChartRangeEl = document.getElementById("weightChartRange");
  const weightChartEmptyEl = document.getElementById("weightChartEmpty");
  let nutritionLocked = false;
  let chatAllowed = false;
  let chatLastId = 0;
  let chatPollTimer = null;
  let chatUnreadTimer = null;
  let chatCounterpartName = "";
  let isStaffUser = false;
  let isGuestUser = false;
  let weightPhotoReady = false;

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

  const IMAGE_MAX_DIM = 1280;
  const IMAGE_QUALITY = 0.78;
  const IMAGE_MIN_BYTES = 280 * 1024;

  const loadImageElement = (file) => new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("load_failed"));
    };
    img.src = url;
  });

  const loadImageSource = async (file) => {
    if (window.createImageBitmap) {
      try {
        return await createImageBitmap(file, { imageOrientation: "from-image" });
      } catch (_) {
        try {
          return await createImageBitmap(file);
        } catch (err) {
          return loadImageElement(file);
        }
      }
    }
    return loadImageElement(file);
  };

  const compressImageFile = async (file) => {
    if (!file || !file.type || !file.type.startsWith("image/")) return file;
    if (file.type === "image/gif") return file;
    if (file.size <= IMAGE_MIN_BYTES) return file;

    try {
      const img = await loadImageSource(file);
      const width = img.width || img.naturalWidth || 0;
      const height = img.height || img.naturalHeight || 0;
      if (!width || !height) return file;

      const scale = Math.min(1, IMAGE_MAX_DIM / Math.max(width, height));
      const targetW = Math.round(width * scale);
      const targetH = Math.round(height * scale);
      const canvas = document.createElement("canvas");
      canvas.width = targetW;
      canvas.height = targetH;
      const ctx = canvas.getContext("2d", { alpha: false });
      if (!ctx) return file;
      ctx.drawImage(img, 0, 0, targetW, targetH);
      if (typeof img.close === "function") img.close();

      const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", IMAGE_QUALITY));
      if (!blob) return file;
      if (blob.size >= file.size) return file;

      const baseName = file.name ? file.name.replace(/\.[^.]+$/, "") : "image";
      return new File([blob], `${baseName}.jpg`, { type: "image/jpeg" });
    } catch (e) {
      return file;
    }
  };

  const monthsShort = ["янв","фев","мар","апр","май","июн","июл","авг","сен","окт","ноя","дек"];

  const toYMD = (date) => {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  };

  const parseYMD = (value) => new Date(`${value}T00:00:00`);

  const addDays = (date, offset) => {
    const d = new Date(date);
    d.setDate(d.getDate() + offset);
    return d;
  };

  const addMonths = (date, offset) => {
    const d = new Date(date);
    d.setMonth(d.getMonth() + offset);
    return d;
  };

  const startOfWeek = (date) => {
    const d = new Date(date);
    const day = (d.getDay() + 6) % 7;
    d.setDate(d.getDate() - day);
    return d;
  };

  const getWeekStartKey = (date) => toYMD(startOfWeek(date));

  const formatWeekRange = (weekStartKey) => {
    if (!weekStartKey) return "";
    const start = parseYMD(weekStartKey);
    const end = addDays(start, 6);
    return `${start.getDate()} ${monthsShort[start.getMonth()]} — ${end.getDate()} ${monthsShort[end.getMonth()]}`;
  };

  const startOfMonth = (date) => {
    const d = new Date(date);
    d.setDate(1);
    return d;
  };

  const getMonthStartKey = (date) => toYMD(startOfMonth(date));

  const formatMonthRange = (monthStartKey) => {
    if (!monthStartKey) return "";
    const start = parseYMD(monthStartKey);
    const end = new Date(start.getFullYear(), start.getMonth() + 1, 0);
    return `${start.getDate()} ${monthsShort[start.getMonth()]} вЂ” ${end.getDate()} ${monthsShort[end.getMonth()]}`;
  };

  const formatMonthRangeNumeric = (monthStartKey) => {
    if (!monthStartKey) return "";
    const start = parseYMD(monthStartKey);
    const end = new Date(start.getFullYear(), start.getMonth() + 1, 0);
    const pad = (value) => String(value).padStart(2, "0");
    const startLabel = `${pad(start.getDate())}.${pad(start.getMonth() + 1)}`;
    const endLabel = `${pad(end.getDate())}.${pad(end.getMonth() + 1)}`;
    return `${startLabel} - ${endLabel}`;
  };

  const formatDateShort = (date) => {
    const pad = (value) => String(value).padStart(2, "0");
    return `${pad(date.getDate())}.${pad(date.getMonth() + 1)}`;
  };

  const formatWeekRangeNumeric = (weekStartKey) => {
    if (!weekStartKey) return "";
    const start = parseYMD(weekStartKey);
    const end = addDays(start, 6);
    return `${formatDateShort(start)} - ${formatDateShort(end)}`;
  };

  const isBasicTariff = (tariff) => {
    const value = String(tariff || "").toLowerCase();
    return value.includes("базов");
  };

  const isGuestTariff = (tariff) => {
    const value = String(tariff || "").toLowerCase().trim();
    return !value || value.includes("без тарифа") || value.includes("гост");
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

  const formatChatTimestamp = (value) => {
    if (!value) return "";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    const pad = (n) => String(n).padStart(2, "0");
    return `${pad(date.getDate())}.${pad(date.getMonth() + 1)}.${date.getFullYear()} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  };

  const ensureChatMeta = (bubble, message) => {
    let meta = bubble.querySelector(".chat-meta");
    if (!meta) {
      meta = document.createElement("div");
      meta.className = "chat-meta";
      bubble.appendChild(meta);
    }
    let timeEl = meta.querySelector(".chat-time");
    if (!timeEl) {
      timeEl = document.createElement("span");
      timeEl.className = "chat-time";
      meta.appendChild(timeEl);
    }
    if (!timeEl.textContent && message?.createdAt) {
      timeEl.textContent = formatChatTimestamp(message.createdAt);
    }
    return meta;
  };

  const updateChatStatus = (bubble, message) => {
    if (!bubble) return;
    const meta = ensureChatMeta(bubble, message);
    const shouldShow = Boolean(message?.isMine);
    let statusEl = meta.querySelector(".chat-status");
    if (!shouldShow) {
      if (statusEl) statusEl.remove();
      return;
    }
    if (!statusEl) {
      statusEl = document.createElement("span");
      statusEl.className = "chat-status";
      meta.appendChild(statusEl);
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
    const fileType = file.type || "";
    if (!fileType) {
      showAlert("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u043f\u0440\u0435\u0434\u0435\u043b\u0438\u0442\u044c \u0442\u0438\u043f \u0444\u0430\u0439\u043b\u0430.");
      return null;
    }
    if (!fileType.startsWith("video/") && !fileType.startsWith("image/")) {
      showAlert("\u041c\u043e\u0436\u043d\u043e \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0444\u043e\u0442\u043e \u0438\u043b\u0438 \u0432\u0438\u0434\u0435\u043e.");
      return null;
    }

    let workingFile = file;
    if (fileType.startsWith("image/")) {
      workingFile = await compressImageFile(file);
    }
    const uploadType = workingFile.type || fileType;
    const uploadName = workingFile.name || file.name || (uploadType.startsWith("image/") ? "photo.jpg" : "video.mp4");
    const size = workingFile.size || 0;
    if (size <= 0) return null;
    if (size > 50 * 1024 * 1024) {
      showAlert("\u0424\u0430\u0439\u043b \u0431\u043e\u043b\u044c\u0448\u0435 50 \u041c\u0411. \u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0444\u0430\u0439\u043b \u043f\u043e\u043c\u0435\u043d\u044c\u0448\u0435.");
      return null;
    }
    const res = await fetch(`${API_BASE}/api/chat/upload-url`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        initData,
        fileName: uploadName,
        contentType: uploadType,
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
      headers: { "Content-Type": uploadType },
      body: workingFile
    });
    if (!uploadRes.ok) {
      showAlert("\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u0444\u0430\u0439\u043b\u0430.");
      return null;
    }
    return {
      key: json.objectKey,
      type: uploadType,
      name: uploadName,
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
    const isBasic = isBasicTariff(tariff);
    const isGuest = isGuestTariff(tariff);
    if (isStaffUser) {
      nutritionLocked = false;
    } else {
      nutritionLocked = isBasic || isGuest;
    }
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
      const lockMode = !isStaffUser && isBasic;
      modeToggleEl.classList.toggle("is-locked", lockMode);
      modeToggleEl.setAttribute("aria-disabled", lockMode ? "true" : "false");
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

  const setProfileEditable = (editable) => {
    const isEditable = Boolean(editable);
    if (editHeightEl) editHeightEl.disabled = !isEditable;
    if (editWeightEl) editWeightEl.disabled = !isEditable;
    if (editAgeEl) editAgeEl.disabled = !isEditable;
    if (saveProfileBtn) {
      saveProfileBtn.hidden = !isEditable;
      saveProfileBtn.disabled = !isEditable;
    }
    if (!isEditable && profileSaveStatusEl) {
      profileSaveStatusEl.textContent = "Редактирование профиля недоступно в гостевом доступе.";
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
      isGuestUser = !isStaff && isGuestTariff(tariff);
      const tariffPaidUntil = formatDateOnly(tariffExpiresAt);
      const showPaidUntil = Boolean(tariffPaidUntil) && !isStaff;
      const displayTariff = role === "sadmin"
        ? "\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446"
        : role === "admin"
          ? "\u0410\u0434\u043c\u0438\u043d"
          : isCuratorRole
            ? "\u041a\u0443\u0440\u0430\u0442\u043e\u0440"
            : (isGuestTariff(tariff) ? "\u0413\u043e\u0441\u0442\u0435\u0432\u043e\u0439" : tariff);
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
      setProfileEditable(!isGuestUser);
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
    if (isGuestUser) {
      showAlert("Редактирование профиля недоступно в гостевом доступе.");
      return false;
    }

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

  const getTimezoneOffsetMin = () => new Date().getTimezoneOffset();

  const setWeightStatus = (text, isError = false) => {
    if (!weightSaveStatusEl) return;
    weightSaveStatusEl.textContent = text;
    weightSaveStatusEl.style.color = isError ? "var(--danger, #ff6b6b)" : "";
    if (text) {
      setTimeout(() => {
        if (weightSaveStatusEl.textContent === text) weightSaveStatusEl.textContent = "";
      }, 2500);
    }
  };

  const updatePhotoSlot = (slot, url, locked = false) => {
    if (!slot) return;
    const img = slot.querySelector(".photo-img");
    const placeholder = slot.querySelector(".photo-placeholder");
    const deleteBtn = slot.querySelector(".photo-delete");
    const uploadBtn = slot.querySelector(".photo-upload");
    const isLocked = Boolean(locked);
    if (uploadBtn) uploadBtn.disabled = isLocked;
    if (img && url) {
      img.src = url;
      img.hidden = false;
      if (placeholder) placeholder.hidden = true;
      if (deleteBtn) deleteBtn.disabled = isLocked;
      slot.dataset.locked = isLocked ? "1" : "0";
      return;
    }
    if (img) {
      img.removeAttribute("src");
      img.hidden = true;
    }
    if (placeholder) placeholder.hidden = false;
    if (deleteBtn) deleteBtn.disabled = true;
    slot.dataset.locked = isLocked ? "1" : "0";
  };

  const renderWeightHistory = (weekKeys, weightMap, photoMap) => {
    if (!weightHistoryEl) return;
    weightHistoryEl.innerHTML = "";

    const hasAny = weekKeys.some((key) => {
      const log = weightMap.get(key);
      const photos = photoMap.get(key);
      return Boolean(log) || Boolean(photos?.frontUrl || photos?.sideUrl || photos?.backUrl);
    });

    if (!hasAny) {
      weightHistoryEl.innerHTML = '<div class="muted">Пока нет записей по весу и замерам.</div>';
      return;
    }

    weekKeys.forEach((key) => {
      const log = weightMap.get(key);
      const photos = photoMap.get(key) || {};
      if (!log && !photos.frontUrl && !photos.sideUrl && !photos.backUrl) return;

      const weightText = Number.isFinite(log?.weightKg) ? `${formatSimple(log.weightKg)} кг` : "—";

      const photoItems = [];
      if (photos.frontUrl) {
        photoItems.push(`<img class="weight-week-photo" src="${photos.frontUrl}" alt="Фото спереди">`);
      }
      if (photos.sideUrl) {
        photoItems.push(`<img class="weight-week-photo" src="${photos.sideUrl}" alt="Фото сбоку">`);
      }
      if (photos.backUrl) {
        photoItems.push(`<img class="weight-week-photo" src="${photos.backUrl}" alt="Фото сзади">`);
      }
      const photosHtml = photoItems.length
        ? photoItems.join("")
        : '<div class="weight-week-empty">Фото еще не загружено</div>';
      const card = document.createElement("div");
      card.className = "weight-week-card";
      card.innerHTML = `
        <div class="weight-week-meta">
          <span>${formatMonthRangeNumeric(key)}</span>
          <span>${weightText}</span>
        </div>
        <div class="weight-week-photos">${photosHtml}</div>
      `;
      weightHistoryEl.appendChild(card);
    });
  };

  const renderWeightTrend = (logs = []) => {
    if (!weightChartEl || !weightChartSvg) return;
    const weeksCount = 12;
    const start = startOfWeek(new Date());
    const weekKeys = Array.from({ length: weeksCount }).map((_, idx) => {
      const wk = addDays(start, -(weeksCount - 1 - idx) * 7);
      return toYMD(wk);
    });
    const logMap = new Map(logs.map((log) => [log.weekStart, log]));
    const values = weekKeys.map((key) => {
      const value = logMap.get(key)?.weightKg;
      return Number.isFinite(value) ? value : null;
    });
    const present = values.filter((value) => Number.isFinite(value));
    if (!present.length) {
      weightChartEl.classList.add("is-empty");
      if (weightChartEmptyEl) weightChartEmptyEl.hidden = false;
      if (weightChartRangeEl) weightChartRangeEl.textContent = "";
      weightChartSvg.innerHTML = "";
      return;
    }

    weightChartEl.classList.remove("is-empty");
    if (weightChartEmptyEl) weightChartEmptyEl.hidden = true;

    const min = Math.min(...present);
    const max = Math.max(...present);
    const range = max - min || 1;
    const denom = Math.max(1, weekKeys.length - 1);
    let d = "";
    let circles = "";
    let started = false;

    values.forEach((value, idx) => {
      if (!Number.isFinite(value)) {
        started = false;
        return;
      }
      const x = ((idx / denom) * 100).toFixed(2);
      const y = (100 - ((value - min) / range) * 100).toFixed(2);
      if (!started) {
        d += `M ${x} ${y}`;
        started = true;
      } else {
        d += ` L ${x} ${y}`;
      }
      circles += `<circle class="weight-chart-point" cx="${x}" cy="${y}" r="2.4" />`;
    });

    const grid = [25, 50, 75]
      .map((y) => `<line class="weight-chart-grid" x1="0" y1="${y}" x2="100" y2="${y}" />`)
      .join("");

    weightChartSvg.setAttribute("viewBox", "0 0 100 100");
    weightChartSvg.innerHTML = `
      ${grid}
      <path class="weight-chart-line" d="${d}" />
      ${circles}
    `;

    if (weightChartRangeEl) {
      const startLabel = formatDateShort(parseYMD(weekKeys[0]));
      const endLabel = formatDateShort(addDays(parseYMD(weekKeys[weekKeys.length - 1]), 6));
      weightChartRangeEl.textContent = `${startLabel} - ${endLabel}`;
    }
  };

  const loadWeightProgress = async () => {
    if (!API_BASE || !weightModal) return;
    const initData = buildInitData();
    if (!initData) return;
    const currentWeek = getWeekStartKey(new Date());
    const currentMonth = getMonthStartKey(new Date());
    if (weightWeekLabelEl) weightWeekLabelEl.textContent = formatWeekRangeNumeric(currentWeek);

    try {
      const [weightRes, photoRes] = await Promise.all([
        fetch(`${API_BASE}/api/weight/history?initData=${encodeURIComponent(initData)}&weeks=52`),
        fetch(`${API_BASE}/api/measurements/history?initData=${encodeURIComponent(initData)}&months=12`)
      ]);
      const weightJson = await weightRes.json().catch(() => ({}));
      const photoJson = await photoRes.json().catch(() => ({}));
      const logs = Array.isArray(weightJson.logs) ? weightJson.logs : [];
      const items = Array.isArray(photoJson.items) ? photoJson.items : [];
      const weekMap = new Map(logs.map((log) => [log.weekStart, log]));
      const weightMap = new Map();
      logs.forEach((log) => {
        const key = getMonthStartKey(parseYMD(log.weekStart));
        if (!weightMap.has(key)) weightMap.set(key, log);
      });
      const photoMap = new Map();
      items.forEach((item) => {
        const key = getMonthStartKey(parseYMD(item.weekStart));
        if (!photoMap.has(key)) photoMap.set(key, item);
      });

      const currentLog = weekMap.get(currentWeek);
      if (weightInputEl) {
        weightInputEl.value = currentLog && Number.isFinite(currentLog.weightKg) ? formatSimple(currentLog.weightKg) : "";
      }

      if (weightPhotosEl) {
        const currentPhotos = photoMap.get(currentMonth) || {};
        weightPhotosEl.querySelectorAll(".photo-slot").forEach((slot) => {
          const side = slot.dataset.side;
          const url = side === "front" ? currentPhotos.frontUrl : side === "side" ? currentPhotos.sideUrl : currentPhotos.backUrl;
          updatePhotoSlot(slot, url || "", currentPhotos.locked);
        });
      }

      renderWeightTrend(logs);

      const monthKeys = Array.from({ length: 12 }).map((_, idx) => {
        const start = startOfMonth(new Date());
        const month = addMonths(start, -idx);
        return toYMD(month);
      });
      renderWeightHistory(monthKeys, weightMap, photoMap);
    } catch (e) {
      console.warn("[weight] Ошибка загрузки прогресса", e);
    }
  };

  const saveWeeklyWeight = async () => {
    if (!API_BASE || !weightInputEl) return;
    const weightKg = readNumber(weightInputEl.value);
    if (weightKg === null) {
      showAlert("Введите вес.");
      return;
    }
    if (isGuestUser) {
      showAlert("Редактирование недоступно в гостевом доступе.");
      return;
    }
    const initData = buildInitData();
    if (!initData) return;

    setWeightStatus("Сохраняем...");
    try {
      const payload = {
        initData,
        weightKg,
        weekStart: getWeekStartKey(new Date()),
        timezoneOffsetMin: getTimezoneOffsetMin()
      };
      const res = await fetch(`${API_BASE}/api/weight`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const json = await res.json().catch(() => ({}));
      if (json?.error === "locked") {
        showAlert("Фото можно менять или удалять только в течение 3 дней после загрузки.");
        return;
      }
      if (!json?.ok) {
        setWeightStatus("Ошибка сохранения", true);
        return;
      }

      const newWeight = json.weightKg ?? weightKg;
      if (profileWeightEl) profileWeightEl.textContent = newWeight ?? "-";
      if (editWeightEl) editWeightEl.value = newWeight ?? "";
      if (metricWeightEl) {
        if (Number.isFinite(newWeight)) {
          metricWeightEl.textContent = formatSimple(newWeight, "-");
          if (metricWeightStatusEl) metricWeightStatusEl.textContent = "Профиль";
        }
      }
      setWeightStatus("Сохранено");
      await loadWeightProgress();
    } catch (e) {
      console.warn("[weight] Ошибка сохранения", e);
      setWeightStatus("Ошибка сохранения", true);
    }
  };

  const uploadMeasurement = async (side, file) => {
    if (!API_BASE || !file) return;
    const initData = buildInitData();
    if (!initData) return;
    if (isGuestUser) {
      showAlert("Редактирование недоступно в гостевом доступе.");
      return;
    }
    if (!file.type || !file.type.startsWith("image/")) {
      showAlert("Можно загружать только фото.");
      return;
    }
    const workingFile = await compressImageFile(file);
    const uploadType = workingFile.type || file.type;
    const uploadName = workingFile.name || file.name || "photo.jpg";
    const uploadSize = workingFile.size || 0;
    if (uploadSize <= 0) {
      showAlert("РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕРґРіРѕС‚РѕРІРёС‚СЊ С„РѕС‚Рѕ.");
      return;
    }
    const weekStart = getMonthStartKey(new Date());
    const timezoneOffsetMin = getTimezoneOffsetMin();

    try {
      const res = await fetch(`${API_BASE}/api/measurements/upload-url`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          initData,
          side,
          fileName: uploadName,
          contentType: uploadType,
          size: uploadSize,
          monthStart: weekStart,
          timezoneOffsetMin
        })
      });
      const json = await res.json().catch(() => ({}));
      if (json?.error === "locked") {
        showAlert("Фото можно менять или удалять только в течение 3 дней после загрузки.");
        return;
      }
      if (!json?.ok || !json?.uploadUrl || !json?.objectKey) {
        showAlert("Не удалось подготовить загрузку фото.");
        return;
      }
      const uploadRes = await fetch(json.uploadUrl, {
        method: "PUT",
        headers: { "Content-Type": uploadType },
        body: workingFile
      });
      if (!uploadRes.ok) {
        showAlert("Не удалось загрузить фото.");
        return;
      }

      const saveRes = await fetch(`${API_BASE}/api/measurements`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          initData,
          side,
          objectKey: json.objectKey,
          monthStart: weekStart
        })
      });
      const saveJson = await saveRes.json().catch(() => ({}));
      if (saveJson?.error === "locked") {
        showAlert("Фото можно менять или удалять только в течение 3 дней после загрузки.");
        return;
      }
      if (!saveJson?.ok) {
        showAlert("Не удалось сохранить фото.");
        return;
      }

      await loadWeightProgress();
    } catch (e) {
      console.warn("[measurements] upload error", e);
      showAlert("Ошибка загрузки фото.");
    }
  };

  const deleteMeasurement = async (side) => {
    if (!API_BASE) return;
    const initData = buildInitData();
    if (!initData) return;
    if (isGuestUser) {
      showAlert("Редактирование недоступно в гостевом доступе.");
      return;
    }
    const weekStart = getMonthStartKey(new Date());
    try {
      const res = await fetch(`${API_BASE}/api/measurements/delete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ initData, side, monthStart: weekStart })
      });
      const json = await res.json().catch(() => ({}));
      if (!json?.ok) {
        showAlert("Не удалось удалить фото.");
        return;
      }
      await loadWeightProgress();
    } catch (e) {
      console.warn("[measurements] delete error", e);
      showAlert("Ошибка удаления фото.");
    }
  };

  const initPhotoActions = () => {
    if (!weightPhotosEl) return;
    if (weightPhotoReady) return;
    weightPhotoReady = true;
    weightPhotosEl.querySelectorAll(".photo-slot").forEach((slot) => {
      const side = slot.dataset.side;
      const input = slot.querySelector(".photo-input");
      const uploadBtn = slot.querySelector(".photo-upload");
      const deleteBtn = slot.querySelector(".photo-delete");

      uploadBtn?.addEventListener("click", () => {
        if (slot.dataset.locked === "1") {
          showAlert("Фото можно менять или удалять только в течение 3 дней после загрузки.");
          return;
        }
        input?.click();
      });
      input?.addEventListener("change", async () => {
        if (slot.dataset.locked === "1") {
          showAlert("Фото можно менять или удалять только в течение 3 дней после загрузки.");
          input.value = "";
          return;
        }
        const file = input.files?.[0];
        input.value = "";
        if (!file) return;
        await uploadMeasurement(side, file);
      });
      deleteBtn?.addEventListener("click", () => {
        if (slot.dataset.locked === "1") {
          showAlert("Фото можно менять или удалять только в течение 3 дней после загрузки.");
          return;
        }
        deleteMeasurement(side);
      });
    });
  };

  const openWeightModal = async () => {
    if (!weightModal) return;
    weightModal.classList.add("show");
    weightModal.setAttribute("aria-hidden", "false");
    initPhotoActions();
    await loadWeightProgress();
  };

  const closeWeightModal = () => {
    if (!weightModal) return;
    weightModal.classList.remove("show");
    weightModal.setAttribute("aria-hidden", "true");
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
  const THEME_ICON_MOON = '<span class="icon-emoji" aria-hidden="true">🌙</span>';
  const THEME_ICON_SUN = '<span class="icon-emoji" aria-hidden="true">☀️</span>';

  const clearInlineVars = () => {
    const r = document.documentElement;
    ["--bg", "--text", "--card", "--card-border", "--accent"].forEach((k) => r.style.removeProperty(k));
  };

  const applyTheme = () => {
    clearInlineVars();
    if (isDark) {
      document.documentElement.classList.remove("light");
      if (themeToggleBtn) themeToggleBtn.innerHTML = THEME_ICON_MOON;
      localStorage.setItem("theme", "dark");
    } else {
      document.documentElement.classList.add("light");
      if (themeToggleBtn) themeToggleBtn.innerHTML = THEME_ICON_SUN;
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
  if (openWeightModalBtn) openWeightModalBtn.addEventListener("click", openWeightModal);
  if (closeWeightBtn) closeWeightBtn.addEventListener("click", closeWeightModal);
  if (weightSaveBtn) weightSaveBtn.addEventListener("click", saveWeeklyWeight);
  if (weightModal) {
    weightModal.addEventListener("click", (e) => {
      if (e.target === weightModal) closeWeightModal();
    });
  }
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
