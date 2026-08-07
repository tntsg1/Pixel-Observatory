(() => {
  "use strict";

  const app = document.getElementById("study-app");
  const sessionStorageKey = "pixel-observatory:study-session:v1";
  const languageStorageKey = "so-lang";
  const origin = location.origin;
  let session = null;
  let serverState = null;
  let phaseStart = Date.now();
  let activeView = "home";
  let language = preferredLanguage();
  const answerDrafts = {};
  let miniTimer = 0;
  let miniLastTick = 0;
  let pendingActiveSeconds = 0;
  let miniState = null;
  let godotCompleted = false;
  let godotReportInFlight = false;
  let godotReportedSeconds = 0;

  const staticCopy = {
    sessionLabel: ["Research session", "研究流程"],
    progressLabel: ["Study progress", "研究进度"],
    progressBaseline: ["1. Baseline", "1. 前测"],
    progressRead: ["2. Read", "2. 阅读"],
    progressCheck: ["3. Check", "3. 检查"],
    progressObserve: ["4. Observe", "4. 观测"],
    progressReflect: ["5. Reflect", "5. 反馈"],
    privacyFooter: ["Anonymous research record. No game account or personal details are required.", "匿名研究记录，无需游戏账号或个人资料。"],
  };

  const questions = [
    {
      id: "workflow",
      text: ["Which step normally comes between naked-eye observation and looking through the main telescope?", "在肉眼观察和使用主望远镜之间，通常应先完成哪一步？"],
      options: [["finder", "Use a finder scope to narrow the target.", "使用寻星镜缩小目标范围。"], ["focus", "Adjust the focuser.", "调整调焦器。"], ["filter", "Add a colour filter.", "添加彩色滤镜。"], ["report", "Write an observation report.", "撰写观测报告。"]],
    },
    {
      id: "magnification",
      text: ["Which eyepiece change normally gives a higher magnification?", "通常更换哪种目镜会获得更高倍率？"],
      options: [["short", "Use a shorter focal-length eyepiece.", "使用焦距更短的目镜。"], ["long", "Use a longer focal-length eyepiece.", "使用焦距更长的目镜。"], ["aperture", "Close the telescope aperture.", "缩小望远镜口径。"], ["cloud", "Wait for cloud cover.", "等待云层出现。"]],
    },
    {
      id: "focus",
      text: ["A target is dim and soft even when it is centred. What should you adjust first?", "目标已经居中，但仍然模糊发虚，首先应该调整什么？"],
      options: [["focuser", "The focuser.", "调焦器。"], ["mount", "The tripod height.", "三脚架高度。"], ["finder", "The finder scope cap.", "寻星镜镜盖。"], ["credits", "The mission credits.", "任务积分。"]],
    },
    {
      id: "seeing",
      text: ["On a night with poor atmospheric seeing, what is usually the better choice?", "在大气视宁度较差的夜晚，通常哪种选择更合适？"],
      options: [["lower", "Use less magnification.", "使用较低倍率。"], ["higher", "Use as much magnification as possible.", "尽可能使用最高倍率。"], ["ignore", "Ignore the atmosphere.", "忽略大气影响。"], ["aperture", "Make the target larger with a bigger aperture only.", "只靠更大口径放大目标。"]],
    },
    {
      id: "tracking",
      text: ["Why does a telescope need tracking during a long observation?", "长时间观测时，望远镜为什么需要追踪？"],
      options: [["rotation", "Earth's rotation moves the sky across the field.", "地球自转会使天体移出视场。"], ["moon", "The Moon changes colour.", "月球会改变颜色。"], ["battery", "The eyepiece battery drains.", "目镜电池会耗尽。"], ["mirror", "The mirror becomes transparent.", "镜面会变透明。"]],
    },
    {
      id: "chromatic",
      text: ["What causes chromatic aberration in a simple refracting telescope?", "简单折射式望远镜中的色差由什么引起？"],
      options: [["refraction", "Different colours refract by different amounts.", "不同颜色的光折射程度不同。"], ["radio", "Radio signals have colour.", "无线电信号带有颜色。"], ["tracking", "The mount tracks too smoothly.", "支架追踪过于平稳。"], ["dust", "Dust changes focal length.", "灰尘改变了焦距。"]],
    },
    {
      id: "light",
      text: ["How does light pollution most directly affect a faint deep-sky observation?", "光污染对暗弱深空天体观测最直接的影响是什么？"],
      options: [["glow", "Sky glow reduces contrast.", "天空背景光会降低对比度。"], ["magnify", "It increases useful magnification.", "它会提高有效倍率。"], ["cool", "It cools the optics.", "它会冷却光学系统。"], ["track", "It improves tracking.", "它会改善追踪。"]],
    },
    {
      id: "infrared",
      text: ["Why are many space-infrared images shown in false colour?", "为什么许多太空红外图像使用假彩色显示？"],
      options: [["false_colour", "Infrared wavelengths are assigned visible colours to show structure.", "将红外波段映射为可见颜色，以显示结构。"], ["printer", "The printer cannot make black.", "打印机无法打印黑色。"], ["weather", "Clouds add colour in space.", "太空中的云层会添加颜色。"], ["mirror", "Mirrors only reflect coloured light.", "镜面只能反射彩色光。"]],
    },
    {
      id: "radio",
      text: ["What is a FAST radio observation mainly trying to recover?", "FAST 射电观测主要试图从数据中恢复什么？"],
      options: [["signal", "A weak patterned radio signal in noisy data.", "噪声数据中微弱但有规律的射电信号。"], ["photo", "A conventional colour photograph.", "普通彩色照片。"], ["temperature", "The surface temperature of a planet.", "行星表面温度。"], ["satellite", "A new optical lens.", "一枚新的光学镜片。"]],
    },
    {
      id: "dispersion",
      text: ["In a pulsar observation, dispersion correction aligns what?", "脉冲星观测中的色散校正会对齐什么？"],
      options: [["arrival", "Arrival times across frequency channels.", "不同频率通道中的到达时间。"], ["stars", "The shapes of visible stars.", "可见恒星的形状。"], ["mount", "The telescope legs.", "望远镜支腿。"], ["clouds", "Cloud layers.", "云层。"]],
    },
  ];

  function preferredLanguage() {
    const query = new URLSearchParams(location.search).get("lang");
    if (/^(en|zh)$/i.test(query || "")) return query.toLowerCase();
    try {
      const saved = localStorage.getItem(languageStorageKey);
      if (/^(en|zh)$/i.test(saved || "")) return saved.toLowerCase();
    } catch (_) {}
    return "en";
  }

  function t(en, zh) { return language === "zh" ? zh : en; }
  function localText(pair) { return pair[language === "zh" ? 1 : 0]; }
  function escapeHtml(value) { return String(value || "").replace(/[&<>'"]/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;","\"":"&quot;"})[character]); }
  function formatTime(total) { const seconds = Math.max(0, Math.floor(total)); return `${Math.floor(seconds / 60)}m ${String(seconds % 60).padStart(2, "0")}s`; }

  function applyLanguage(nextLanguage, remember = true) {
    language = nextLanguage === "zh" ? "zh" : "en";
    document.documentElement.dataset.lang = language;
    document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
    document.title = t("Pixel Observatory Research Study", "Pixel Observatory 研究测试");
    if (remember) {
      try { localStorage.setItem(languageStorageKey, language); } catch (_) {}
    }
    document.querySelectorAll("[data-language]").forEach(button => button.setAttribute("aria-pressed", String(button.dataset.language === language)));
    document.querySelectorAll("[data-copy]").forEach(node => {
      const value = staticCopy[node.dataset.copy];
      if (value) node.textContent = localText(value);
    });
    document.querySelectorAll("[data-copy-aria]").forEach(node => {
      const value = staticCopy[node.dataset.copyAria];
      if (value) node.setAttribute("aria-label", localText(value));
    });
    const frame = document.getElementById("study-godot-frame");
    if (frame) frame.src = studyGameUrl();
  }

  document.querySelectorAll("[data-language]").forEach(button => {
    button.addEventListener("click", () => {
      if (button.dataset.language === language) return;
      captureDraft();
      applyLanguage(button.dataset.language);
      renderCurrentView();
    });
  });

  function saveSession() { try { localStorage.setItem(sessionStorageKey, JSON.stringify(session)); } catch (_) {} }
  function loadSession() { try { session = JSON.parse(localStorage.getItem(sessionStorageKey) || "null"); } catch (_) { session = null; } }
  async function api(path, body) {
    const response = await fetch(`${origin}${path}`, {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body)});
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message || t("The study service could not finish that request.", "研究服务未能完成该请求。"));
    return data;
  }
  function authenticated(body = {}) { return {...body, participantId: session?.participantId, token: session?.token}; }

  function studyGameUrl(reset = false) {
    const params = new URLSearchParams({
      mode: "study",
      lang: language,
      participant: session?.participantId || "anonymous",
      study: session?.participantId || "",
      study_token: session?.token || "",
    });
    if (reset) params.set("study_reset", String(Date.now()));
    return `/game/?${params.toString()}`;
  }
  function updateProgress() {
    const current = serverState?.nextStage || "pretest";
    const order = ["pretest", "reading", "reading_posttest", "game", "posttest", "experience", "complete"];
    const index = order.indexOf(current);
    document.querySelectorAll("[data-step]").forEach(node => {
      const own = order.indexOf(node.dataset.step);
      node.classList.toggle("is-current", own === index || (current === "experience" && node.dataset.step === "posttest"));
      node.classList.toggle("is-done", own < index);
    });
  }
  function view(markup, name) {
    currentViewAbort?.abort();
    currentViewAbort = new AbortController();
    activeView = name;
    app.innerHTML = `<div class="study-view">${markup}</div>`;
    updateProgress();
  }
  function showError(message) { const node = app.querySelector(".error"); if (node) node.textContent = message; }
  function captureDraft() {
    const form = app.querySelector("form[data-phase]");
    if (!form) return;
    answerDrafts[form.dataset.phase] = Object.fromEntries(new FormData(form).entries());
  }

  function home() {
    stopMiniTimer(false);
    view(`<span class="eyebrow">${t("Pixel Observatory study", "Pixel Observatory 研究测试")}</span>
      <h1>${t("Learn the instrument. Then tell us what changed.", "亲手操作仪器，再告诉我们你理解了什么。")}</h1>
      <p class="lead">${t("This optional research flow records how a short reading and an instrument-based astronomy game affect conceptual understanding. It does not require a game account, name, or email address.", "这项自愿参加的研究将记录短篇阅读和仪器操作游戏如何影响天文概念理解。无需游戏账号、姓名或电子邮箱。")}</p>
      <div class="consent"><label><input id="consent" type="checkbox"> ${t("I am choosing to participate. I understand that an anonymous study code, my responses, and active game time will be recorded for research.", "我自愿参加，并理解系统会以匿名研究编号记录我的回答和有效游戏时长。")}</label></div>
      <p class="fine">${t("You may close this tab at any time. Do not use this page for formal data collection until your supervisor has approved the participant information and consent wording.", "你可以随时关闭本页面。在导师批准参与者说明和知情同意文字前，请勿将本页面用于正式数据收集。")}</p>
      <div class="actions"><button class="primary" id="begin" type="button">${t("Begin the study", "开始研究流程")}</button><button class="text-button" id="resume" type="button">${t("Resume a saved anonymous session", "继续已保存的匿名流程")}</button></div><p class="error" role="alert"></p>`, "home");
    document.getElementById("begin").onclick = async () => {
      if (!document.getElementById("consent").checked) return showError(t("Please confirm consent before beginning.", "请先确认知情同意。"));
      try {
        const data = await api("/api/study/enroll", {consent: true, language});
        session = {participantId: data.participantId, token: data.token};
        saveSession();
        serverState = data.state;
        miniState = null;
        render();
      } catch (error) { showError(error.message); }
    };
    document.getElementById("resume").onclick = () => session ? refresh() : showError(t("No anonymous study session is stored in this browser.", "此浏览器中没有已保存的匿名研究流程。"));
  }

  function questionMarkup(prefix) {
    const draft = answerDrafts[prefix] || {};
    return questions.map((question, index) => `<fieldset class="question"><strong>${index + 1}. ${escapeHtml(localText(question.text))}</strong><div class="options">${question.options.map(([value, en, zh]) => `<label class="option"><input required name="${prefix}-${question.id}" type="radio" value="${value}" ${draft[`${prefix}-${question.id}`] === value ? "checked" : ""}><span>${escapeHtml(t(en, zh))}</span></label>`).join("")}</div></fieldset>`).join("");
  }

  function test(phase, title, copy) {
    stopMiniTimer(false);
    phaseStart = Date.now();
    const eyebrow = phase === "pre" ? t("Before reading", "阅读前") : phase === "reading_post" ? t("After reading", "阅读后") : t("After observing", "观测后");
    view(`<span class="eyebrow">${eyebrow}</span><h2>${localText(title)}</h2><p>${localText(copy)}</p><form id="test-form" data-phase="${phase}" class="study-form">${questionMarkup(phase)}<div class="actions"><button class="primary" type="submit">${t("Continue", "继续")}</button>${phase === "pre" ? "" : `<button class="text-button" type="button" data-withdraw>${t("Withdraw this study record", "撤回这份研究记录")}</button>`}</div><p class="error" role="alert"></p></form>`, `test:${phase}`);
    const form = document.getElementById("test-form");
    form.addEventListener("change", captureDraft);
    form.onsubmit = async event => {
      event.preventDefault();
      const answers = Object.fromEntries(questions.map(question => [question.id, new FormData(form).get(`${phase}-${question.id}`)]));
      if (Object.values(answers).some(value => !value)) return showError(t("Please answer every question before continuing.", "请回答全部问题后再继续。"));
      try {
        const data = await api("/api/study/submit", authenticated({phase, answers, durationSeconds: Math.round((Date.now() - phaseStart) / 1000)}));
        delete answerDrafts[phase];
        serverState = data.state;
        render();
      } catch (error) { showError(error.message); }
    };
    form.querySelector("[data-withdraw]")?.addEventListener("click", withdraw);
  }

  function reading() {
    stopMiniTimer(false);
    view(`<span class="eyebrow">${t("Short reading", "短篇阅读")}</span><h2>${t("How an observation becomes evidence", "一次观测如何成为证据")}</h2><p>${t("Read the four notes before completing the knowledge check. They describe the causal model used by Pixel Observatory.", "请阅读以下四条说明，再完成知识检查。它们概括了 Pixel Observatory 使用的因果模型。")}</p>
      <div class="reading">
        <article><h3>${t("1. The instrument changes the result", "1. 仪器会改变结果")}</h3><p>${t("Assembly, focus, collimation, eyepiece focal length, and tracking are not cosmetic settings. They change clarity, stability, magnification, and field of view.", "组装、调焦、准直、目镜焦距和追踪并非装饰性设置，它们会改变清晰度、稳定性、倍率和视场。")}</p></article>
        <article><h3>${t("2. The atmosphere has a limit", "2. 大气会限制观测")}</h3><p>${t("Cloud cover and light pollution reduce contrast. Poor atmospheric seeing also limits useful magnification: using more magnification can make a target worse rather than better.", "云层和光污染会降低对比度。较差的视宁度还会限制有效倍率：继续提高倍率有时会让目标更糟，而不是更清楚。")}</p></article>
        <article><h3>${t("3. Different telescopes collect different evidence", "3. 不同望远镜收集不同证据")}</h3><p>${t("Optical telescopes show visible light. Infrared observations use false colour to represent invisible wavelength bands. FAST receives radio data and searches for faint structured signals, such as periodic pulsar pulses.", "光学望远镜呈现可见光；红外观测用假彩色表示不可见波段；FAST 接收射电数据，并从噪声中寻找脉冲星等微弱而有规律的信号。")}</p></article>
        <article><h3>${t("4. A clear result is produced, not granted", "4. 清晰结果需要由操作产生")}</h3><p>${t("Finding a target begins with the naked eye and finder scope, then continues through the main telescope. Focus, tracking, environmental conditions, and a suitable configuration determine what becomes visible.", "寻找目标从肉眼和寻星镜开始，再进入主望远镜。调焦、追踪、环境条件和合适配置共同决定最终能够看见什么。")}</p></article>
      </div><div class="actions"><button class="primary" id="reading-done">${t("I have finished reading", "我已完成阅读")}</button><button class="text-button" data-withdraw>${t("Withdraw this study record", "撤回这份研究记录")}</button></div><p class="error" role="alert"></p>`, "reading");
    document.getElementById("reading-done").onclick = async () => {
      try { const data = await api("/api/study/advance", authenticated({action: "finish_reading"})); serverState = data.state; render(); } catch (error) { showError(error.message); }
    };
    app.querySelector("[data-withdraw]").onclick = withdraw;
  }

  function miniStorageKey() { return `${sessionStorageKey}:mini:${session?.participantId || "anonymous"}`; }
  function godotReportKey() { return `${sessionStorageKey}:godot-reported:${session?.participantId || "anonymous"}`; }
  function godotStartedKey() { return `${sessionStorageKey}:godot-started:${session?.participantId || "anonymous"}`; }
  function loadGodotReportState() {
    try { godotReportedSeconds = Math.max(0, Number(localStorage.getItem(godotReportKey()) || 0)); } catch (_) { godotReportedSeconds = 0; }
  }
  function saveGodotReportState() { try { localStorage.setItem(godotReportKey(), String(godotReportedSeconds)); } catch (_) {} }

  async function reportGodotSeconds(totalSeconds, event = "heartbeat") {
    if (!session || godotReportInFlight || serverState?.nextStage !== "game") return;
    const target = Math.max(0, Math.floor(Number(totalSeconds || 0)));
    const delta = Math.min(90, target - godotReportedSeconds);
    if (delta <= 0) return;
    godotReportInFlight = true;
    try {
      const data = await api("/api/study/game-event", authenticated({event, activeSeconds: delta}));
      godotReportedSeconds += delta;
      saveGodotReportState();
      serverState.gameActiveSeconds = Number(data.activeSeconds || serverState.gameActiveSeconds || 0);
      updateGodotStudyStatus();
      if (target > godotReportedSeconds) window.setTimeout(() => reportGodotSeconds(target, "heartbeat"), 50);
    } catch (_) {
      window.setTimeout(() => reportGodotSeconds(target, event), 3000);
    } finally { godotReportInFlight = false; }
  }

  function updateGodotStudyStatus() {
    const elapsed = Number(serverState?.gameActiveSeconds || 0);
    const minimum = Number(serverState?.minimumGameSeconds || 300);
    const timer = document.querySelector("[data-godot-time]");
    const status = document.querySelector("[data-godot-status]");
    const finish = document.getElementById("finish-godot-game");
    if (timer) timer.textContent = formatTime(elapsed);
    if (status) status.textContent = elapsed >= minimum ? t("Minimum active time reached", "已达到最低有效时长") : t(`${formatTime(minimum - elapsed)} remaining`, `还需 ${formatTime(minimum - elapsed)}`);
    if (finish) finish.disabled = !(godotCompleted && elapsed >= minimum);
  }

  function godotGame() {
    stopMiniTimer(false);
    loadGodotReportState();
    let started = Number(serverState?.gameActiveSeconds || 0) > 0 || godotReportedSeconds > 0;
    try { started ||= localStorage.getItem(godotStartedKey()) === "1"; } catch (_) {}
    view(`<span class="eyebrow">${t("Extracted Pixel Observatory curriculum", "Pixel Observatory 原课程提取路线")}</span><h2>${t("Play the original levels, in a shorter research route.", "直接游玩原有关卡，以更短的研究路线推进。")}</h2>
      <p>${t("This route opens selected levels from the main Godot project with their original scenes, instruments, interactions, and results. Completing one lesson jumps directly to the next selected lesson. Only the participant save is separate; your normal campaign is never changed.", "本路线直接打开 Godot 本体中选定的原有关卡，保留原场景、仪器、互动和观测结果。完成一关后会直接跳到下一项选定课程。只有参与者存档是独立的，你的正式游戏进度不会被修改。")}</p>
      ${started ? `<div class="godot-study-frame"><iframe id="study-godot-frame" title="${t("Pixel Observatory research route", "像素天文台研究速通线")}" allow="autoplay; fullscreen" src="${studyGameUrl()}"></iframe></div>
      <div class="godot-study-footer"><div><strong data-godot-time>${formatTime(Number(serverState?.gameActiveSeconds || 0))}</strong><span data-godot-status></span></div><div class="actions"><button class="text-button" id="restart-godot-game">${t("Start route from the beginning", "从头开始研究路线")}</button><button class="primary" id="finish-godot-game" disabled>${t("Continue to final questions", "继续完成后测")}</button></div></div>` : `<div class="game-callout"><strong>${t("What you will practise", "你将练习")}</strong><span class="fine">${t("Naked eye → finder → main telescope · useful magnification · focus · tracking · false colour · pulsar dispersion", "肉眼 → 寻星镜 → 主望远镜 · 有效倍率 · 调焦 · 追踪 · 假彩色 · 脉冲星色散")}</span><div class="actions"><button class="primary" id="start-godot-game">${t("Launch the Godot observatory", "启动 Godot 观测台")}</button></div></div>`}
      <div class="actions"><button class="text-button" data-withdraw>${t("Withdraw this study record", "撤回这份研究记录")}</button></div><p class="error" role="alert"></p>`, "godot-game");
    if (!started) {
      document.getElementById("start-godot-game").onclick = async () => {
        try {
          const data = await api("/api/study/advance", authenticated({action: "start_game"}));
          serverState = data.state;
          await api("/api/study/game-event", authenticated({event: "opened", activeSeconds: 0})).catch(() => null);
          godotReportedSeconds = 0;
          saveGodotReportState();
          try { localStorage.setItem(godotStartedKey(), "1"); } catch (_) {}
          godotGame();
        } catch (error) { showError(error.message); }
      };
    } else {
      updateGodotStudyStatus();
      document.getElementById("restart-godot-game").onclick = () => {
        if (!window.confirm(t("Restart the selected Godot lessons from the first level? Your normal game save and questionnaire answers will not be changed.", "确定从第一关重新开始这组 Godot 课程吗？正式游戏存档和问卷答案不会改变。"))) return;
        godotCompleted = false;
        const frame = document.getElementById("study-godot-frame");
        if (frame) frame.src = studyGameUrl(true);
        updateGodotStudyStatus();
      };
      document.getElementById("finish-godot-game").onclick = async () => {
        try { const data = await api("/api/study/advance", authenticated({action: "finish_game"})); serverState = data.state; render(); } catch (error) { showError(error.message); }
      };
    }
    app.querySelector("[data-withdraw]").onclick = withdraw;
  }
  function defaultMiniState() {
    return {version: 1, started: false, stage: 0, mode: 0, locks: [false, false, false], offsetX: .48, offsetY: -.32, eyepiece: "10", focus: 35, tracking: false, stable: false, infrared: {r: "dust", g: "near", b: "mid"}, infraredDone: false, dm: 8, radioDone: false, complete: false};
  }
  function loadMiniState() {
    if (miniState) return miniState;
    try { miniState = JSON.parse(localStorage.getItem(miniStorageKey()) || "null"); } catch (_) { miniState = null; }
    if (!miniState || miniState.version !== 1) miniState = defaultMiniState();
    return miniState;
  }
  function saveMiniState() { try { localStorage.setItem(miniStorageKey(), JSON.stringify(miniState)); } catch (_) {} }

  async function sendGameTime(event = "heartbeat", force = false) {
    const wholeSeconds = Math.floor(pendingActiveSeconds);
    if (!session || (!force && wholeSeconds < 15) || wholeSeconds <= 0) return;
    pendingActiveSeconds -= wholeSeconds;
    try {
      const data = await api("/api/study/game-event", authenticated({event, activeSeconds: wholeSeconds}));
      if (serverState) serverState.gameActiveSeconds = Number(data.activeSeconds || serverState.gameActiveSeconds || 0);
      updateMiniTimerText();
    } catch (_) { pendingActiveSeconds += wholeSeconds; }
  }
  function startMiniTimer() {
    if (miniTimer || !miniState?.started) return;
    miniLastTick = performance.now();
    miniTimer = window.setInterval(() => {
      const now = performance.now();
      const elapsed = Math.min(2, Math.max(0, (now - miniLastTick) / 1000));
      miniLastTick = now;
      if (!document.hidden && document.hasFocus() && serverState?.nextStage === "game") pendingActiveSeconds += elapsed;
      if (pendingActiveSeconds >= 15) sendGameTime("heartbeat");
      updateMiniTimerText();
    }, 1000);
  }
  function stopMiniTimer(flush = true) { if (miniTimer) window.clearInterval(miniTimer); miniTimer = 0; if (flush) sendGameTime("hidden", true); }
  function observedSeconds() { return Number(serverState?.gameActiveSeconds || 0) + Math.floor(pendingActiveSeconds); }
  function updateMiniTimerText() {
    const timerNode = document.querySelector("[data-mini-time]");
    if (timerNode) timerNode.textContent = formatTime(observedSeconds());
    const remainingNode = document.querySelector("[data-mini-remaining]");
    const minimum = Number(serverState?.minimumGameSeconds || 300);
    if (remainingNode) remainingNode.textContent = observedSeconds() >= minimum ? t("Minimum active time reached", "已达到最低有效时长") : t(`${formatTime(minimum - observedSeconds())} remaining`, `还需 ${formatTime(minimum - observedSeconds())}`);
    const finish = document.getElementById("finish-mini-game");
    if (finish) finish.disabled = !(miniState?.complete && observedSeconds() >= minimum);
  }

  function miniHeader(stage) {
    const titles = [["Acquire", "寻星"], ["Resolve", "成像"], ["Decode", "解码"]];
    return `<div class="mini-game-toolbar"><strong>${t("Independent study observatory", "独立研究观测台")} · ${localText(titles[Math.min(stage, 2)])}</strong><div class="mini-stage-pips" aria-hidden="true">${[0,1,2].map(index => `<i class="${index < stage ? "is-done" : index === stage ? "is-current" : ""}"></i>`).join("")}</div><span class="timer" data-mini-time>${formatTime(observedSeconds())}</span></div>`;
  }

  function game() {
    loadMiniState();
    if (!miniState.started) {
      stopMiniTimer(false);
      view(`<span class="eyebrow">${t("Independent observation", "独立观测任务")}</span><h2>${t("One target. Three kinds of evidence.", "一个目标，三种证据。")}</h2>
        <p>${t("This compact activity is separate from Pixel Observatory itself. You will acquire a target, produce a stable optical image, and decode invisible infrared and radio evidence. It uses a study-only save and cannot change your game progress.", "这个紧凑任务与 Pixel Observatory 本体完全隔离。你将寻找目标、获得稳定的光学图像，再解码不可见的红外和射电证据。它使用独立的研究存档，不会改变游戏进度。")}</p>
        <div class="game-callout"><strong>${t("What you will practise", "你将练习")}</strong><span class="fine">${t("Naked eye → finder → main telescope · useful magnification · focus · tracking · false colour · pulsar dispersion", "肉眼 → 寻星镜 → 主望远镜 · 有效倍率 · 调焦 · 追踪 · 假彩色 · 脉冲星色散")}</span><div class="actions"><button class="primary" id="start-mini-game">${t("Enter the study observatory", "进入研究观测台")}</button></div></div>
        <div class="actions"><button class="text-button" data-withdraw>${t("Withdraw this study record", "撤回这份研究记录")}</button></div><p class="error" role="alert"></p>`, "game-intro");
      document.getElementById("start-mini-game").onclick = async () => {
        try {
          const data = await api("/api/study/advance", authenticated({action: "start_game"}));
          serverState = data.state;
          miniState.started = true;
          saveMiniState();
          await api("/api/study/game-event", authenticated({event: "opened", activeSeconds: 0})).catch(() => null);
          renderMiniGame();
        } catch (error) { showError(error.message); }
      };
      app.querySelector("[data-withdraw]").onclick = withdraw;
      return;
    }
    renderMiniGame();
  }

  function renderMiniGame() {
    startMiniTimer();
    if (miniState.complete) return renderMiniComplete();
    if (miniState.stage === 0) return renderAcquire();
    if (miniState.stage === 1) return renderResolve();
    return renderDecode();
  }

  function renderAcquire() {
    const modes = [["Naked eye", "肉眼"], ["Finder", "寻星镜"], ["Main scope", "主望远镜"]];
    view(`<span class="eyebrow">${t("Mini observation · 1 of 3", "迷你观测 · 1/3")}</span><h2>${t("Find M42 without losing the sky.", "在天空中逐级找到 M42。")}</h2>
      <p>${t("Drag the sky or use the direction controls. Centre the highlighted star field, lock it, then move to the narrower instrument.", "拖动星空或使用方向键，把高亮星区移到中心并锁定，再进入视场更窄的仪器。")}</p><div class="mini-game">${miniHeader(0)}
      <section class="mini-panel"><div class="mini-panel-head"><div><h3>${t("Target acquisition", "目标捕获")}</h3><p>${t("M42 · Orion Nebula · southeast sky", "M42 · 猎户座大星云 · 东南天空")}</p></div><span class="mini-status" id="acquire-status">${t("Slew to target", "转向目标")}</span></div>
      <div class="observatory-console"><div class="sky-viewport"><canvas id="acquire-canvas" aria-label="Interactive target acquisition sky"></canvas><div class="sky-hud"><span>${t("DRAG / WASD TO SLEW", "拖动 / WASD 转向")}</span><span id="offset-readout"></span></div></div>
      <aside class="mini-controls"><div class="control-block"><span class="control-label">${t("Observation mode", "观测模式")}</span><div class="segmented">${modes.map((pair, index) => `<button type="button" data-view-mode="${index}" class="${miniState.mode === index ? "is-selected" : ""}" ${index > miniState.mode ? "disabled" : ""}>${localText(pair)}</button>`).join("")}</div></div>
      <div class="slew-pad" aria-label="Slew controls"><button class="up" data-slew="0,-1" aria-label="Up">↑</button><button class="left" data-slew="-1,0" aria-label="Left">←</button><button class="right" data-slew="1,0" aria-label="Right">→</button><button class="down" data-slew="0,1" aria-label="Down">↓</button></div>
      <p class="mini-note">${t("Wide fields help you find the region. Narrow fields reveal detail, but only after the target is centred.", "宽视场用于寻找区域，窄视场用于观察细节，但前提是目标已经居中。")}</p><button class="primary" id="lock-target" type="button">${t("Lock current view", "锁定当前视场")}</button><p class="error" role="alert"></p></aside></div></section></div>`, "mini-acquire");
    setupAcquireCanvas();
  }

  function setupAcquireCanvas() {
    const canvas = document.getElementById("acquire-canvas");
    const context = canvas.getContext("2d");
    let dragging = false;
    let lastX = 0;
    let lastY = 0;
    const resize = () => { const box = canvas.getBoundingClientRect(); const ratio = Math.min(2, devicePixelRatio || 1); canvas.width = Math.max(1, Math.round(box.width * ratio)); canvas.height = Math.max(1, Math.round(box.height * ratio)); context.setTransform(ratio, 0, 0, ratio, 0, 0); draw(); };
    const modeScale = [0.55, 1.15, 2.15][miniState.mode];
    function draw() {
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;
      context.clearRect(0, 0, width, height);
      context.fillStyle = "#020710";
      context.fillRect(0, 0, width, height);
      for (let index = 0; index < 96; index += 1) {
        const x = ((index * 83 + 17) % 997) / 997 * width;
        const y = ((index * 47 + 31) % 991) / 991 * height;
        const size = index % 13 === 0 ? 1.7 : index % 5 === 0 ? 1.1 : .65;
        context.fillStyle = index % 11 === 0 ? "#f4d99b" : "#b8d9f2";
        context.globalAlpha = .35 + ((index * 19) % 60) / 100;
        context.fillRect(x, y, size, size);
      }
      context.globalAlpha = 1;
      const targetX = width / 2 + miniState.offsetX * width * modeScale;
      const targetY = height / 2 + miniState.offsetY * height * modeScale;
      const glow = context.createRadialGradient(targetX, targetY, 0, targetX, targetY, 24);
      glow.addColorStop(0, "rgba(222,244,255,.95)");
      glow.addColorStop(.12, "rgba(124,205,244,.62)");
      glow.addColorStop(1, "rgba(89,167,213,0)");
      context.fillStyle = glow;
      context.beginPath(); context.arc(targetX, targetY, 24, 0, Math.PI * 2); context.fill();
      context.strokeStyle = "rgba(121,224,255,.95)";
      context.lineWidth = 1.4;
      context.setLineDash([5, 5]);
      context.beginPath(); context.arc(targetX, targetY, 18, 0, Math.PI * 2); context.stroke();
      context.setLineDash([]);
      context.strokeStyle = "rgba(232,195,103,.88)";
      context.beginPath(); context.arc(width / 2, height / 2, 25, 0, Math.PI * 2); context.stroke();
      context.beginPath(); context.moveTo(width / 2 - 36, height / 2); context.lineTo(width / 2 + 36, height / 2); context.moveTo(width / 2, height / 2 - 36); context.lineTo(width / 2, height / 2 + 36); context.stroke();
      const distance = Math.hypot(miniState.offsetX, miniState.offsetY);
      document.getElementById("offset-readout").textContent = `${t("OFFSET", "偏差")} ${(distance * 10).toFixed(1)}°`;
      const ready = distance < [.12, .075, .045][miniState.mode];
      document.getElementById("acquire-status").textContent = ready ? t("Target in lock ring", "目标进入锁定环") : t("Slew to target", "转向目标");
      document.getElementById("lock-target").classList.toggle("is-ready", ready);
    }
    function slew(dx, dy) { const sensitivity = [.07, .035, .018][miniState.mode]; miniState.offsetX += dx * sensitivity; miniState.offsetY += dy * sensitivity; saveMiniState(); draw(); }
    canvas.addEventListener("pointerdown", event => { dragging = true; lastX = event.clientX; lastY = event.clientY; canvas.setPointerCapture(event.pointerId); });
    canvas.addEventListener("pointermove", event => { if (!dragging) return; const dx = event.clientX - lastX; const dy = event.clientY - lastY; lastX = event.clientX; lastY = event.clientY; miniState.offsetX -= dx / canvas.clientWidth / modeScale; miniState.offsetY -= dy / canvas.clientHeight / modeScale; saveMiniState(); draw(); });
    canvas.addEventListener("pointerup", () => { dragging = false; });
    document.querySelectorAll("[data-slew]").forEach(button => button.addEventListener("click", () => { const [x, y] = button.dataset.slew.split(",").map(Number); slew(x, y); }));
    document.querySelectorAll("[data-view-mode]").forEach(button => button.addEventListener("click", () => { miniState.mode = Number(button.dataset.viewMode); saveMiniState(); renderAcquire(); }));
    const keyboard = event => { const key = event.key.toLowerCase(); const map = {a:[-1,0], arrowleft:[-1,0], d:[1,0], arrowright:[1,0], w:[0,-1], arrowup:[0,-1], s:[0,1], arrowdown:[0,1]}; if (!map[key]) return; event.preventDefault(); slew(...map[key]); };
    window.addEventListener("keydown", keyboard, {signal: viewAbortSignal()});
    document.getElementById("lock-target").onclick = () => {
      const threshold = [.12, .075, .045][miniState.mode];
      if (Math.hypot(miniState.offsetX, miniState.offsetY) >= threshold) return showError(t("Bring the target inside the gold lock ring first.", "请先把目标移入金色锁定环。"));
      miniState.locks[miniState.mode] = true;
      if (miniState.mode < 2) {
        miniState.mode += 1;
        miniState.offsetX = .075 * (miniState.mode === 1 ? 1 : -1);
        miniState.offsetY = -.05;
      } else miniState.stage = 1;
      saveMiniState();
      renderMiniGame();
    };
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    viewAbortSignal().addEventListener("abort", () => observer.disconnect(), {once: true});
    resize();
  }

  let currentViewAbort = null;
  function viewAbortSignal() {
    if (!currentViewAbort) currentViewAbort = new AbortController();
    return currentViewAbort.signal;
  }

  function resolveQuality() {
    const focusScore = Math.max(0, 100 - Math.abs(Number(miniState.focus) - 67) * 2.45);
    const seeingCap = miniState.eyepiece === "10" ? 58 : 94;
    const trackingPenalty = miniState.tracking ? 0 : 26;
    return Math.max(0, Math.min(100, Math.min(focusScore, seeingCap) - trackingPenalty));
  }

  function renderResolve() {
    const quality = resolveQuality();
    view(`<span class="eyebrow">${t("Mini observation · 2 of 3", "迷你观测 · 2/3")}</span><h2>${t("Turn a centred target into a usable image.", "把居中的目标变成可用图像。")}</h2>
      <p>${t("Tonight's atmospheric seeing is poor. Choose a useful magnification, focus the image, and stop Earth's rotation from carrying it away.", "今晚的大气视宁度较差。请选择有效倍率、完成调焦，并阻止地球自转让目标漂出视场。")}</p><div class="mini-game">${miniHeader(1)}
      <section class="mini-panel"><div class="mini-panel-head"><div><h3>${t("Optical image control", "光学成像控制")}</h3><p>${t("M42 · refractor · bright suburban sky", "M42 · 折射式望远镜 · 城郊亮天空")}</p></div><span class="mini-status">${t("Seeing cap: 110×", "视宁度上限：110×")}</span></div>
      <div class="observatory-console"><div class="sky-viewport"><canvas id="resolve-canvas" aria-label="Interactive focused telescope view"></canvas><div class="sky-hud"><span>${t("LIVE OPTICAL FEED", "实时光学画面")}</span><span>${t("SKY GLOW: MODERATE", "天空辉光：中等")}</span></div></div>
      <aside class="mini-controls"><div class="control-block"><span class="control-label">${t("Eyepiece", "目镜")}</span><div class="segmented"><button data-eyepiece="25" class="${miniState.eyepiece === "25" ? "is-selected" : ""}">25 mm<br><small>48×</small></button><button data-eyepiece="10" class="${miniState.eyepiece === "10" ? "is-selected" : ""}">10 mm<br><small>120×</small></button></div></div>
      <div class="control-block"><label for="focus-control">${t("Focus", "调焦")} <span class="control-value" id="focus-value">${miniState.focus}%</span></label><input class="range" id="focus-control" type="range" min="0" max="100" value="${miniState.focus}"></div>
      <div class="toggle-row"><span>${t("Sidereal tracking", "恒星时追踪")}</span><button class="toggle" id="tracking-toggle" type="button" aria-pressed="${miniState.tracking}" aria-label="${t("Toggle tracking", "切换追踪")}"></button></div>
      <div class="control-block"><div class="quality-readout"><span>${t("Observation quality", "观测质量")}</span><strong id="quality-label">${Math.round(quality)}%</strong></div><div class="quality-meter"><i id="quality-bar" style="--quality:${quality}%"></i></div></div>
      <p class="mini-note" id="resolve-hint">${resolveHint(quality)}</p><button class="primary" id="hold-exposure" type="button">${t("Press and hold to record 3 s", "按住以记录 3 秒")}</button><p class="error" role="alert"></p></aside></div></section></div>`, "mini-resolve");
    setupResolveCanvas();
  }

  function resolveHint(quality) {
    if (miniState.eyepiece === "10") return t("120× exceeds tonight's useful seeing limit. More magnification is producing a larger blur.", "120× 超过了今晚的有效视宁度上限。更高倍率只会产生更大的模糊。 ");
    if (Math.abs(miniState.focus - 67) > 8) return t("Move the focuser until the two coloured edges converge into one structure.", "调整调焦器，让两侧彩色边缘汇聚成一个结构。 ");
    if (!miniState.tracking) return t("The image is sharp, but it is drifting. Enable sidereal tracking before recording.", "图像已经清晰，但仍在漂移。记录前请开启恒星时追踪。 ");
    if (quality >= 82) return t("Configuration stable. Hold the exposure control without letting go.", "配置已稳定。请持续按住曝光控制，不要松开。 ");
    return t("Keep refining the configuration.", "继续微调配置。 ");
  }

  function setupResolveCanvas() {
    const canvas = document.getElementById("resolve-canvas");
    const context = canvas.getContext("2d");
    let frame = 0;
    let animation = 0;
    function resize() { const box = canvas.getBoundingClientRect(); const ratio = Math.min(2, devicePixelRatio || 1); canvas.width = Math.max(1, Math.round(box.width * ratio)); canvas.height = Math.max(1, Math.round(box.height * ratio)); context.setTransform(ratio, 0, 0, ratio, 0, 0); }
    function draw() {
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;
      context.clearRect(0, 0, width, height);
      context.fillStyle = "#06101b"; context.fillRect(0, 0, width, height);
      for (let index = 0; index < 70; index += 1) { context.fillStyle = `rgba(184,215,236,${.18 + (index % 7) / 20})`; context.fillRect(((index * 79) % 971) / 971 * width, ((index * 53) % 967) / 967 * height, 1, 1); }
      const drift = miniState.tracking ? 0 : Math.sin(frame / 70) * 34;
      const x = width / 2 + drift;
      const y = height / 2;
      const blur = Math.abs(miniState.focus - 67) / 7 + (miniState.eyepiece === "10" ? 3.5 : 0);
      context.save();
      context.filter = `blur(${Math.min(12, blur)}px)`;
      context.globalAlpha = .58;
      context.fillStyle = "#d05d54"; context.beginPath(); context.ellipse(x - blur * 1.5, y, 62, 42, -.18, 0, Math.PI * 2); context.fill();
      context.fillStyle = "#5e9bd7"; context.beginPath(); context.ellipse(x + blur * 1.5, y, 62, 42, -.18, 0, Math.PI * 2); context.fill();
      context.globalAlpha = .8;
      context.strokeStyle = "#dbe8e4"; context.lineWidth = 5; context.beginPath(); context.ellipse(x, y, 65, 43, -.18, 0, Math.PI * 2); context.stroke();
      context.strokeStyle = "rgba(215,235,242,.72)"; context.lineWidth = 2; for (let ring = 0; ring < 4; ring += 1) { context.beginPath(); context.ellipse(x, y, 28 + ring * 12, 10 + ring * 8, -.18, 0, Math.PI * 2); context.stroke(); }
      context.restore();
      context.strokeStyle = "rgba(232,194,98,.72)"; context.lineWidth = 1; context.beginPath(); context.arc(width / 2, height / 2, 84, 0, Math.PI * 2); context.stroke();
      frame += 1;
      animation = requestAnimationFrame(draw);
    }
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    resize();
    draw();
    const signal = viewAbortSignal();
    signal.addEventListener("abort", () => {
      cancelAnimationFrame(animation);
      observer.disconnect();
    }, {once: true});
    document.querySelectorAll("[data-eyepiece]").forEach(button => button.addEventListener("click", () => { miniState.eyepiece = button.dataset.eyepiece; saveMiniState(); renderResolve(); }));
    const focus = document.getElementById("focus-control");
    focus.oninput = () => { miniState.focus = Number(focus.value); saveMiniState(); document.getElementById("focus-value").textContent = `${miniState.focus}%`; const quality = resolveQuality(); document.getElementById("quality-label").textContent = `${Math.round(quality)}%`; document.getElementById("quality-bar").style.setProperty("--quality", `${quality}%`); document.getElementById("resolve-hint").textContent = resolveHint(quality); };
    document.getElementById("tracking-toggle").onclick = event => { miniState.tracking = !miniState.tracking; event.currentTarget.setAttribute("aria-pressed", String(miniState.tracking)); saveMiniState(); const quality = resolveQuality(); document.getElementById("quality-label").textContent = `${Math.round(quality)}%`; document.getElementById("quality-bar").style.setProperty("--quality", `${quality}%`); document.getElementById("resolve-hint").textContent = resolveHint(quality); };
    const hold = document.getElementById("hold-exposure");
    let holdStart = 0;
    let holdFrame = 0;
    function stopHold() { holdStart = 0; cancelAnimationFrame(holdFrame); hold.style.removeProperty("background"); }
    function updateHold(now) {
      if (!holdStart) return;
      if (resolveQuality() < 82) { stopHold(); return showError(t("The image is not stable enough to record yet.", "图像还不够稳定，暂时无法记录。")); }
      const progress = Math.min(1, (now - holdStart) / 3000);
      hold.style.background = `linear-gradient(90deg, #92dfb2 ${progress * 100}%, #d9b04f ${progress * 100}%)`;
      hold.textContent = progress >= 1 ? t("Exposure recorded", "曝光已记录") : t(`Hold… ${(3 - progress * 3).toFixed(1)} s`, `保持… ${(3 - progress * 3).toFixed(1)} 秒`);
      if (progress >= 1) { miniState.stable = true; miniState.stage = 2; saveMiniState(); return window.setTimeout(renderMiniGame, 260); }
      holdFrame = requestAnimationFrame(updateHold);
    }
    hold.addEventListener("pointerdown", event => { event.preventDefault(); if (resolveQuality() < 82) return showError(t("First reach at least 82% quality.", "请先让观测质量达到 82%。")); hold.setPointerCapture(event.pointerId); holdStart = performance.now(); holdFrame = requestAnimationFrame(updateHold); });
    hold.addEventListener("pointerup", stopHold); hold.addEventListener("pointercancel", stopHold);
  }

  function renderDecode() {
    const ir = miniState.infrared;
    const dispersion = Math.abs(Number(miniState.dm) - 27);
    view(`<span class="eyebrow">${t("Mini observation · 3 of 3", "迷你观测 · 3/3")}</span><h2>${t("Make invisible evidence readable.", "让不可见的证据变得可读。")}</h2>
      <p>${t("Infrared and radio observations are not ordinary photographs. Build a false-colour image, then remove the frequency-dependent delay from a pulsar signal.", "红外和射电观测并不是普通照片。请先构建假彩色图像，再消除脉冲星信号随频率变化的到达延迟。")}</p><div class="mini-game">${miniHeader(2)}
      <section class="mini-panel"><div class="mini-panel-head"><div><h3>${t("Evidence laboratory", "证据处理实验室")}</h3><p>${t("Complete both data products", "完成两份数据产品")}</p></div><span class="mini-status">${Number(miniState.infraredDone) + Number(miniState.radioDone)} / 2</span></div>
      <div class="evidence-grid"><article class="evidence-card ${miniState.infraredDone ? "is-complete" : ""}"><h3>${t("Infrared false colour", "红外假彩色")}</h3><p class="fine">${t("Assign three invisible wavelength bands to visible RGB channels.", "把三个不可见波段映射到可见的 RGB 通道。")}</p><div class="evidence-visual"><div class="infrared-object" id="infrared-object"></div></div>
      <div class="channel-map">${["r","g","b"].map(channel => `<label>${channel.toUpperCase()}<select data-channel="${channel}">${[["near", "Near IR", "近红外"], ["mid", "Mid IR", "中红外"], ["dust", "Dust", "尘埃"]].map(([value,en,zh]) => `<option value="${value}" ${ir[channel] === value ? "selected" : ""}>${t(en,zh)}</option>`).join("")}</select></label>`).join("")}</div><button class="secondary" id="confirm-infrared" ${miniState.infraredDone ? "disabled" : ""}>${miniState.infraredDone ? t("Image mapped", "图像已映射") : t("Confirm colour mapping", "确认颜色映射")}</button><p class="error" id="infrared-error" role="alert"></p></article>
      <article class="evidence-card ${miniState.radioDone ? "is-complete" : ""}"><h3>${t("Pulsar dispersion", "脉冲星色散")}</h3><p class="fine">${t("Correct the delay until the pulse arrives together in every frequency channel.", "校正延迟，让脉冲在所有频率通道中同时到达。")}</p><div class="evidence-visual"><div class="radio-traces" id="radio-traces" style="--dispersion:${dispersion}"><i style="--row:0;--shift:-2"></i><i style="--row:1;--shift:0"></i><i style="--row:2;--shift:2"></i></div></div>
      <div class="control-block"><label for="dm-control">DM <span class="control-value" id="dm-value">${miniState.dm} pc/cm³</span></label><input class="range" id="dm-control" type="range" min="0" max="54" step="1" value="${miniState.dm}"></div><button class="secondary" id="confirm-radio" ${miniState.radioDone ? "disabled" : ""}>${miniState.radioDone ? t("Pulse aligned", "脉冲已对齐") : t("Apply dispersion correction", "应用色散校正")}</button><p class="error" id="radio-error" role="alert"></p></article></div></section></div>`, "mini-decode");
    updateInfraredVisual();
    document.querySelectorAll("[data-channel]").forEach(select => select.addEventListener("change", () => { miniState.infrared[select.dataset.channel] = select.value; saveMiniState(); updateInfraredVisual(); }));
    document.getElementById("confirm-infrared").onclick = () => {
      const correct = miniState.infrared.r === "near" && miniState.infrared.g === "mid" && miniState.infrared.b === "dust";
      if (!correct) return document.getElementById("infrared-error").textContent = t("Use a different band for each channel: shorter wavelength → R, middle → G, dust emission → B.", "每个通道应使用不同波段：短波段 → R，中波段 → G，尘埃辐射 → B。 ");
      miniState.infraredDone = true; saveMiniState(); checkDecodeComplete();
    };
    const dm = document.getElementById("dm-control");
    dm.oninput = () => { miniState.dm = Number(dm.value); saveMiniState(); document.getElementById("dm-value").textContent = `${miniState.dm} pc/cm³`; document.getElementById("radio-traces").style.setProperty("--dispersion", Math.abs(miniState.dm - 27)); };
    document.getElementById("confirm-radio").onclick = () => {
      if (Math.abs(miniState.dm - 27) > 1) return document.getElementById("radio-error").textContent = t("The pulse still arrives at different times. Bring the three traces into one vertical arrival window.", "脉冲仍在不同时间到达。请让三条轨迹进入同一个垂直到达窗口。 ");
      miniState.radioDone = true; saveMiniState(); checkDecodeComplete();
    };
  }

  function updateInfraredVisual() {
    const object = document.getElementById("infrared-object");
    if (!object) return;
    const strength = {near: 210, mid: 145, dust: 82};
    object.style.setProperty("--ir-r", strength[miniState.infrared.r]);
    object.style.setProperty("--ir-g", strength[miniState.infrared.g]);
    object.style.setProperty("--ir-b", strength[miniState.infrared.b]);
  }
  function checkDecodeComplete() { if (miniState.infraredDone && miniState.radioDone) { miniState.complete = true; saveMiniState(); window.setTimeout(renderMiniComplete, 220); } else renderDecode(); }

  function renderMiniComplete() {
    const minimum = Number(serverState?.minimumGameSeconds || 300);
    const enoughTime = observedSeconds() >= minimum;
    view(`<span class="eyebrow">${t("Observation products complete", "观测产品已完成")}</span><div class="mini-game">${miniHeader(2)}<section class="mini-panel mini-complete"><div class="mini-complete-mark">✓</div><h2>${t("You produced the evidence yourself.", "你亲手完成了观测证据。")}</h2>
      <p>${t("You narrowed the field before magnifying, worked below the atmospheric limit, focused and tracked the optical image, mapped infrared bands into visible colour, and aligned a dispersed radio pulse.", "你先缩小寻星范围再提高倍率，在大气上限以内完成调焦与追踪，把红外波段映射为可见颜色，并对齐了发生色散的射电脉冲。")}</p>
      <p class="score"><strong data-mini-remaining>${enoughTime ? t("Minimum active time reached", "已达到最低有效时长") : t(`${formatTime(minimum - observedSeconds())} remaining`, `还需 ${formatTime(minimum - observedSeconds())}`)}</strong><br>${t("Active study time counts only while this tab is visible and focused.", "只有本标签页可见并处于焦点时，才计入有效研究时长。")}</p>
      <div class="actions"><button class="primary" id="finish-mini-game" ${enoughTime ? "" : "disabled"}>${t("Continue to final questions", "继续完成后测")}</button><button class="secondary" id="explore-mini-game">${t("Explore the controls again", "再次探索控制台")}</button></div><p class="error" role="alert"></p></section></div>`, "mini-complete");
    updateMiniTimerText();
    document.getElementById("explore-mini-game").onclick = () => { miniState.stage = 1; miniState.complete = false; miniState.infraredDone = false; miniState.radioDone = false; saveMiniState(); renderResolve(); };
    document.getElementById("finish-mini-game").onclick = async () => {
      try { await sendGameTime("heartbeat", true); const data = await api("/api/study/advance", authenticated({action: "finish_game"})); serverState = data.state; stopMiniTimer(false); render(); } catch (error) { showError(error.message); }
    };
  }

  function experience() {
    stopMiniTimer(true);
    phaseStart = Date.now();
    const items = [
      ["interest", ["The activity increased my interest in astronomical observation.", "这项活动提高了我对天文观测的兴趣。"]],
      ["causality", ["The game made the relationship between my actions and the observation result clear.", "游戏清楚呈现了我的操作与观测结果之间的关系。"]],
      ["guidance", ["The guidance made it clear what I should do next.", "引导让我清楚知道下一步应该做什么。"]],
      ["difficulty", ["The difficulty felt manageable.", "任务难度在可接受范围内。"]],
      ["achievement", ["I felt a sense of accomplishment after completing the observation.", "完成观测后，我感到了成就感。"]],
    ];
    const draft = answerDrafts.experience || {};
    view(`<span class="eyebrow">${t("Experience", "体验反馈")}</span><h2>${t("One last field note.", "最后一份观测记录。")}</h2><p>${t("There are no right answers in this final part. Please select the response that best represents your experience.", "这一部分没有正确答案，请选择最符合你真实体验的选项。")}</p><form id="experience-form" data-phase="experience" class="study-form">${items.map(([id, label]) => `<fieldset class="question"><strong>${localText(label)}</strong><div class="likert">${[1,2,3,4,5].map(value => `<label title="${value}"><input required type="radio" name="experience-${id}" value="${value}" ${draft[`experience-${id}`] === String(value) ? "checked" : ""}><span>${value}</span></label>`).join("")}</div></fieldset>`).join("")}<fieldset class="question"><strong>${t("What was the most useful or confusing part of the activity? (optional)", "活动中最有帮助或最令人困惑的部分是什么？（可选）")}</strong><textarea name="experience-note" maxlength="1200" placeholder="${t("Write a short field note…", "写下一段简短记录……")}">${escapeHtml(draft["experience-note"] || "")}</textarea></fieldset><div class="actions"><button class="primary" type="submit">${t("Submit study record", "提交研究记录")}</button><button class="text-button" type="button" data-withdraw>${t("Withdraw this study record", "撤回这份研究记录")}</button></div><p class="error" role="alert"></p></form>`, "experience");
    const form = document.getElementById("experience-form");
    form.addEventListener("change", captureDraft);
    form.querySelector("textarea").addEventListener("input", captureDraft);
    form.onsubmit = async event => {
      event.preventDefault();
      const answers = Object.fromEntries([...new FormData(form).entries()].map(([key, value]) => [key.replace("experience-", ""), value]));
      if (items.some(([id]) => !answers[id])) return showError(t("Please answer all five rating questions.", "请完成全部五项评分。"));
      try { const data = await api("/api/study/submit", authenticated({phase: "experience", answers, durationSeconds: Math.round((Date.now() - phaseStart) / 1000)})); delete answerDrafts.experience; serverState = data.state; render(t("Your anonymous study record has been saved.", "你的匿名研究记录已保存。")); } catch (error) { showError(error.message); }
    };
    form.querySelector("[data-withdraw]").onclick = withdraw;
  }

  function completed(message = "") {
    stopMiniTimer(false);
    view(`<span class="eyebrow">${t("Study complete", "研究流程完成")}</span><h1>${t("Thank you for taking the time to observe carefully.", "感谢你认真完成这次观测。")}</h1><p class="lead">${t("Your responses were stored under an anonymous research code. They can help evaluate whether hands-on instrument operation makes astronomy concepts easier to understand.", "你的回答已通过匿名研究编号保存，它们将帮助评估亲手操作仪器是否能让天文概念更容易理解。")}</p>${message ? `<p class="score">${escapeHtml(message)}</p>` : ""}<div class="actions"><a class="primary" href="/">${t("Return to Pixel Observatory", "返回 Pixel Observatory")}</a><button class="text-button" id="forget">${t("Remove this study code from this browser", "从浏览器中移除此研究编号")}</button></div>`, "complete");
    document.getElementById("forget").onclick = () => { localStorage.removeItem(sessionStorageKey); localStorage.removeItem(miniStorageKey()); localStorage.removeItem(godotReportKey()); localStorage.removeItem(godotStartedKey()); session = null; miniState = null; serverState = null; home(); };
  }

  async function withdraw() {
    if (!confirm(t("Withdraw this anonymous study record? Stored answers will no longer be used in the study flow.", "确认撤回这份匿名研究记录吗？已保存的回答将不再用于研究流程。"))) return;
    try { await api("/api/study/withdraw", authenticated()); localStorage.removeItem(sessionStorageKey); localStorage.removeItem(miniStorageKey()); localStorage.removeItem(godotReportKey()); localStorage.removeItem(godotStartedKey()); session = null; miniState = null; serverState = null; stopMiniTimer(false); home(); } catch (error) { showError(error.message); }
  }

  function render(message = "") {
    if (!serverState) return home();
    if (serverState.nextStage === "pretest") return test("pre", ["A short baseline check", "简短的基线测试"], ["Answer from what you know now. This is not a graded exam.", "请根据你现在的理解作答，这不是计分考试。"]);
    if (serverState.nextStage === "reading") return reading();
    if (serverState.nextStage === "reading_posttest") return test("reading_post", ["What did the reading make clearer?", "阅读让哪些概念更清楚？"], ["Use the notes you just read. Your response will be compared with your first attempt.", "请根据刚才的阅读作答，系统会将结果与第一次回答进行比较。"]);
    if (serverState.nextStage === "game") return godotGame();
    if (serverState.nextStage === "posttest") return test("post", ["After operating the observatory", "完成观测操作后"], ["Answer the same concepts after your observation session. Do not look back at the reading notes.", "请在完成观测后再次回答相同概念，不要回看阅读材料。"]);
    if (serverState.nextStage === "experience") return experience();
    return completed(message);
  }
  function renderCurrentView() { applyLanguage(language, false); if (serverState) render(); else home(); }
  async function refresh() { try { const data = await api("/api/study/session", authenticated()); serverState = data.state; render(); } catch (_) { home(); } }

  window.addEventListener("pagehide", () => {
    if (!session || !miniState?.started || pendingActiveSeconds < 1 || serverState?.nextStage !== "game") return;
    const seconds = Math.floor(pendingActiveSeconds);
    pendingActiveSeconds -= seconds;
    const body = JSON.stringify(authenticated({event: "leave", activeSeconds: seconds}));
    navigator.sendBeacon?.(`${origin}/api/study/game-event`, new Blob([body], {type: "application/json"}));
  });
  window.addEventListener("message", event => {
    const frame = document.getElementById("study-godot-frame");
    const data = event.data;
    if (!frame || event.origin !== location.origin || event.source !== frame.contentWindow || !data || data.source !== "pixel-observatory-study-godot") return;
    if (data.event === "complete" || data.complete === true) {
      godotCompleted = true;
      api("/api/study/session", authenticated()).then(result => {
        serverState = result.state;
        godotReportedSeconds = Number(serverState?.gameActiveSeconds || godotReportedSeconds || 0);
        saveGodotReportState();
        updateGodotStudyStatus();
      }).catch(() => updateGodotStudyStatus());
      return;
    }
    reportGodotSeconds(data.activeSeconds, data.event);
    updateGodotStudyStatus();
  });
  document.addEventListener("visibilitychange", () => { if (document.hidden) sendGameTime("hidden", true); else miniLastTick = performance.now(); });

  applyLanguage(language, false);
  loadSession();
  if (session?.participantId && session?.token) refresh(); else home();
})();
