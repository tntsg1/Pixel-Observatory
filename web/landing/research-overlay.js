(() => {
  "use strict";

  const SESSION_KEY = "pixel-observatory:research-session:v2";
  const REWARD_RECEIPTS_KEY = "pixel-observatory:research-receipts:v1";
  const EQUIPPED_RESEARCH_KEY = "pixel-observatory:research-equipped:v1";
  const API = "/api/research";
  const RESEARCH_REWARDS = {
    R01: { name: "Solar Crown", zh: "日冕之冠", title: "Keeper of First Light", titleZh: "初光守望者", portrait: 0 },
    R02: { name: "Lunar Archive", zh: "月面档案", title: "Lunar Cartographer", titleZh: "月面制图师", portrait: 1 },
    R03: { name: "Nebula Weaver", zh: "星云织者", title: "Voice of the Nebula", titleZh: "星云之声", portrait: 2 },
    R04: { name: "Aurora Navigator", zh: "极光领航员", title: "Northern Sky Navigator", titleZh: "北天领航员", portrait: 3 },
    R05: { name: "Pulsar Herald", zh: "脉冲星信使", title: "Keeper of the Heartbeat", titleZh: "宇宙心跳守护者", portrait: 4 },
    R06: { name: "Event Horizon", zh: "事件视界", title: "Beyond the Last Photon", titleZh: "最后光子之外", portrait: 5 },
    R07: { name: "Deep Sky Cartographer", zh: "深空制图师", title: "Mapper of Faint Worlds", titleZh: "暗弱天体绘图者", portrait: 6 },
    R08: { name: "Infrared Alchemist", zh: "红外炼金师", title: "Interpreter of Hidden Light", titleZh: "隐光解译者", portrait: 7 },
    R09: { name: "Radio Sentinel", zh: "射电哨兵", title: "Listener Between Mountains", titleZh: "群山之间的聆听者", portrait: 3 },
    R10: { name: "Mirror Master", zh: "镜面大师", title: "Master of the Optical Path", titleZh: "光路大师", portrait: 1 },
    R11: { name: "Sidereal Voyager", zh: "恒星时远航者", title: "Traveller of the Turning Sky", titleZh: "旋转星空的旅者", portrait: 6 },
    R12: { name: "Observatory Laureate", zh: "天文台桂冠", title: "Laureate of Pixel Observatory", titleZh: "像素天文台桂冠", portrait: 0 },
  };
  const FALLBACK_QUESTIONS = [
    {
      id: "clarity",
      prompt: { en: "The activity goals were clear.", zh: "" },
      options: ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"].map((en, index) => ({ id: String(index + 1), en, zh: "" })),
    },
    {
      id: "confidence",
      prompt: { en: "I felt able to make progress.", zh: "" },
      options: ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"].map((en, index) => ({ id: String(index + 1), en, zh: "" })),
    },
    {
      id: "return",
      prompt: { en: "I would like to continue this activity.", zh: "" },
      options: ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"].map((en, index) => ({ id: String(index + 1), en, zh: "" })),
    },
  ];

  let serverRefreshedSession = null;
  let activeCheckpoint = null;
  let activeFlow = null;
  let restoreFocusTo = null;
  let sessionSilenced = false;

  function readStoredState() {
    try {
      const stored = JSON.parse(window.localStorage.getItem(SESSION_KEY)) || {};
      const state = {};
      if (typeof stored.participantId === "string" && stored.participantId) state.participantId = stored.participantId;
      if (typeof stored.token === "string" && stored.token) state.token = stored.token;
      if (stored.pendingSubmission && typeof stored.pendingSubmission === "object" && !Array.isArray(stored.pendingSubmission)) {
        const { nodeId, answers } = stored.pendingSubmission;
        if (typeof nodeId === "string" && answers && typeof answers === "object" && !Array.isArray(answers)) {
          state.pendingSubmission = { nodeId, answers: { ...answers } };
        }
      }
      return state;
    } catch (_) {
      return {};
    }
  }

  let state = readStoredState();

  function saveState(patch) {
    const next = { ...state, ...patch };
    state = {};
    if (typeof next.participantId === "string" && next.participantId) state.participantId = next.participantId;
    if (typeof next.token === "string" && next.token) state.token = next.token;
    if (next.pendingSubmission && typeof next.pendingSubmission === "object") {
      state.pendingSubmission = {
        nodeId: String(next.pendingSubmission.nodeId || ""),
        answers: { ...(next.pendingSubmission.answers || {}) },
      };
    }
    try {
      window.localStorage.setItem(SESSION_KEY, JSON.stringify(state));
    } catch (_) {
      // The research service remains authoritative when storage is unavailable.
    }
  }

  function hasCredentials() {
    return Boolean(state.participantId && state.token);
  }

  function authenticatedBody(body = {}) {
    return { participantId: state.participantId, token: state.token, ...body };
  }

  function readJsonStorage(key, fallback) {
    try {
      return JSON.parse(window.localStorage.getItem(key)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  function preserveResearchReward(result) {
    const bundleId = String(result?.bundleId || "");
    const receiptToken = String(result?.receiptToken || "");
    if (!RESEARCH_REWARDS[bundleId] || !receiptToken) throw new Error("Research reward receipt is invalid.");
    const storedReceipts = readJsonStorage(REWARD_RECEIPTS_KEY, []);
    const receipts = Array.isArray(storedReceipts)
      ? storedReceipts.filter(receipt => receipt?.receiptToken !== receiptToken)
      : [];
    receipts.push({ receiptToken, bundleId });
    const equipped = {
      bundleId,
      avatar: `${bundleId}-avatar`,
      frame: `${bundleId}-frame`,
      background: `${bundleId}-background`,
      nameGlow: `${bundleId}-name-glow`,
      chatBubble: `${bundleId}-chat-bubble`,
      badge: `${bundleId}-badge`,
      title: `${bundleId}-title`,
    };
    window.localStorage.setItem(REWARD_RECEIPTS_KEY, JSON.stringify(receipts));
    window.localStorage.setItem(EQUIPPED_RESEARCH_KEY, JSON.stringify(equipped));
    window.dispatchEvent(new CustomEvent("po:research-cosmetics-changed", { detail: equipped }));
  }

  function activeNodeId() {
    return String(activeCheckpoint?.nodeId || "");
  }

  function currentServerNode() {
    return typeof serverRefreshedSession?.currentNode === "string" ? serverRefreshedSession.currentNode : "";
  }

  function selectedLanguage() {
    return activeCheckpoint?.language === "zh" || serverRefreshedSession?.language === "zh" ? "zh" : "en";
  }

  function localize(value) {
    if (typeof value === "string") return value;
    if (!value || typeof value !== "object") return "";
    const language = selectedLanguage();
    return String(value[language] || value.en || value.zh || value.label || value.text || "");
  }

  function updateServerState(result) {
    const nextState = result?.state;
    if (!nextState || typeof nextState !== "object" || Array.isArray(nextState)) {
      throw new Error("Research service returned an invalid session state.");
    }
    serverRefreshedSession = nextState;
    return nextState;
  }

  function canOfferBaseline() {
    return activeNodeId() === "baseline" && !serverRefreshedSession;
  }

  function hasVerifiedGameplaySession() {
    return Boolean(
      serverRefreshedSession &&
      hasCredentials() &&
      serverRefreshedSession.participantId === state.participantId &&
      serverRefreshedSession.routeArm === "field_gameplay" &&
      Array.isArray(serverRefreshedSession.completedNodes) &&
      serverRefreshedSession.completedNodes.includes("baseline") &&
      serverRefreshedSession.withdrawn === false
    );
  }

  async function request(path, body = {}) {
    const response = await fetch(`${API}${path}`, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || payload.message || "Research service is unavailable.");
    return payload;
  }

  async function refreshResearchSession() {
    if (!hasCredentials()) throw new Error("No research session is available.");
    return updateServerState(await request("/session", authenticatedBody()));
  }

  async function recordCheckpoint(checkpoint) {
    const level = Number(checkpoint?.completedLevel);
    const result = await request("/checkpoint", authenticatedBody({ level }));
    return updateServerState(result);
  }

  function removeOverlay() {
    document.querySelector(".po-research-overlay")?.remove();
    activeFlow = null;
    document.removeEventListener("keydown", trapFocus, true);
    if (restoreFocusTo && document.contains(restoreFocusTo)) restoreFocusTo.focus();
    restoreFocusTo = null;
  }

  function makeButton(label, className, action) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = className;
    button.textContent = label;
    button.addEventListener("click", action);
    return button;
  }

  function showOverlay(content, flow) {
    removeOverlay();
    restoreFocusTo = document.activeElement;
    activeFlow = flow;
    const overlay = document.createElement("div");
    overlay.className = "po-research-overlay";
    overlay.setAttribute("role", "presentation");
    const dialog = document.createElement("section");
    dialog.className = "po-research-dialog";
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-label", "Optional research study / 可选研究问卷");
    dialog.tabIndex = -1;
    dialog.append(content);
    if (flow === "invitation") {
      const detail = dialog.querySelector(".po-research-detail");
      if (detail) {
        detail.textContent = selectedLanguage() === "zh"
          ? "，；。"
          : "A short optional study appears after selected milestones. Every completed questionnaire unlocks one community cosmetic bundle; answers and correctness never change the reward.";
      }
    }
    overlay.append(dialog);
    document.body.append(overlay);
    document.addEventListener("keydown", trapFocus, true);
    const firstFocusable = dialog.querySelector("button, input, select, textarea, [tabindex]:not([tabindex='-1'])");
    (firstFocusable || dialog).focus();
  }

  function trapFocus(event) {
    const dialog = document.querySelector(".po-research-dialog");
    if (!dialog) return;
    if (event.key === "Escape") {
      event.preventDefault();
      deferResearch();
      return;
    }
    if (event.key !== "Tab") return;
    const focusable = [...dialog.querySelectorAll("button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])")];
    if (!focusable.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function heading(title, detail) {
    const fragment = document.createDocumentFragment();
    const titleNode = document.createElement("h2");
    titleNode.className = "po-research-title";
    titleNode.textContent = title;
    const detailNode = document.createElement("p");
    detailNode.className = "po-research-detail";
    detailNode.textContent = detail;
    fragment.append(titleNode, detailNode);
    return fragment;
  }

  function showInvitation() {
    const content = document.createElement("div");
    content.className = "po-research-invitation";
    content.append(heading("Help improve Pixel Observatory / 帮助改进 Pixel Observatory", "A short optional study after your session. Your choices do not affect gameplay or rewards. / 简短自愿研究，不影响游戏或奖励。"));
    const privacy = document.createElement("p");
    privacy.className = "po-research-privacy";
    privacy.textContent = "You may stop at any time and withdraw in Research settings. / 您可以随时停止，并在研究设置中撤回。";
    const actions = document.createElement("div");
    actions.className = "po-research-actions";
    actions.append(
      makeButton("Join the study / 加入研究", "po-research-primary", enroll),
      makeButton("Not now / 稍后", "po-research-secondary", deferResearch),
      makeButton("Research settings / 研究设置", "po-research-link", openSettings)
    );
    content.append(privacy, actions);
    showOverlay(content, "invitation");
  }

  async function enroll() {
    try {
      const result = await request("/enroll", { consent: true, language: selectedLanguage() });
      if (typeof result?.participantId !== "string" || typeof result?.token !== "string") {
        throw new Error("Research service returned invalid credentials.");
      }
      saveState({ participantId: result.participantId, token: result.token, pendingSubmission: null });
      const enrolledState = updateServerState(result);
      showBaseline(enrolledState.questions || FALLBACK_QUESTIONS);
    } catch (error) {
      showError(error, enroll);
    }
  }

  function showBaseline(questions) {
    showQuestionFlow("baseline", questions, async (answers, durationSeconds) => {
      const nodeId = currentServerNode();
      const result = await request("/submit", authenticatedBody({ nodeId, answers, durationSeconds }));
      const nextState = updateServerState(result);
      saveState({ pendingSubmission: null });
      if (result?.rewardOffer) showRewardChoice(result.rewardOffer, () => showAssignment(nextState.routeArm));
      else showAssignment(nextState.routeArm);
      return { keepOpen: true };
    });
  }

  function rewardLabel(bundleId) {
    const reward = RESEARCH_REWARDS[bundleId];
    return reward ? `${reward.name} / ${reward.zh}` : bundleId;
  }

  function rewardPortrait(bundleId) {
    const reward = RESEARCH_REWARDS[bundleId];
    const portrait = document.createElement("span");
    portrait.className = `po-research-reward-portrait po-research-reward-portrait-${Number(reward?.portrait || 0)}`;
    portrait.setAttribute("aria-hidden", "true");
    return portrait;
  }

  function showRewardChoice(offer, afterReward) {
    const offerId = String(offer?.offerId || "");
    const isBaselineReward = String(offer?.nodeId || "") === "baseline";
    const candidates = Array.isArray(offer?.candidates) ? offer.candidates.map(String) : [];
    if (!offerId || candidates.length !== 3 || new Set(candidates).size !== 3 || !candidates.every(id => RESEARCH_REWARDS[id])) {
      afterReward();
      return;
    }
    const content = document.createElement("div");
    content.className = "po-research-reward-choice";
    content.append(heading(
      "Choose your observatory legacy / 选择你的天文台传承",
      "You earned this by completing the questionnaire. Choose one complete seven-piece community set. / 你完成了问卷，请从三套限定社区装扮中选择一套完整的七件套奖励。",
    ));
    const cards = document.createElement("div");
    cards.className = "po-research-reward-grid";
    let choosing = false;
    candidates.forEach(bundleId => {
      const reward = RESEARCH_REWARDS[bundleId];
      const card = makeButton(rewardLabel(bundleId), `po-research-reward-card po-research-reward-${bundleId}`, async () => {
        if (choosing) return;
        choosing = true;
        cards.querySelectorAll("button").forEach(button => { button.disabled = true; });
        card.className += " is-selected";
        try {
          const result = await request("/reward/choose", authenticatedBody({ offerId, bundleId }));
          preserveResearchReward(result);
          showRewardReveal(result, afterReward, isBaselineReward);
        } catch (error) {
          showError(error, () => showRewardChoice(offer, afterReward), "retry-reward");
        }
      });
      const text = document.createElement("span");
      text.className = "po-research-reward-copy";
      const name = document.createElement("strong");
      name.textContent = rewardLabel(bundleId);
      const title = document.createElement("small");
      title.textContent = `${reward.title} / ${reward.titleZh}`;
      const pieces = document.createElement("span");
      pieces.className = "po-research-reward-pieces";
      pieces.textContent = "Portrait  Frame  Background  Glow  Bubble  Badge  Title";
      text.append(name, title, pieces);
      card.textContent = "";
      card.append(rewardPortrait(bundleId), text);
      cards.append(card);
    });
    content.append(cards);
    showOverlay(content, "reward-choice");
  }

  function showRewardReveal(result, afterReward, isBaselineReward) {
    const bundleId = String(result?.bundleId || "");
    const reward = RESEARCH_REWARDS[bundleId];
    const prestige = Math.max(1, Number(result?.prestigeLevel || 1));
    const content = document.createElement("div");
    content.className = `po-research-reward-reveal po-research-reward-${bundleId}`;
    const sky = document.createElement("div");
    sky.className = "po-research-reward-sky";
    for (let index = 0; index < 18; index += 1) {
      const star = document.createElement("i");
      star.className = `po-research-reward-star po-research-reward-star-${index}`;
      sky.append(star);
    }
    const seal = document.createElement("div");
    seal.className = "po-research-reward-seal";
    seal.append(rewardPortrait(bundleId));
    const copy = document.createElement("div");
    copy.className = "po-research-reward-result";
    copy.append(heading(
      "Observatory legacy unlocked / 天文台传承已解锁",
      `${rewardLabel(bundleId)}  ${reward.title} / ${reward.titleZh}`,
    ));
    const level = document.createElement("p");
    level.className = "po-research-prestige";
    level.textContent = `Research Prestige ${prestige} / 研究声望 ${prestige}`;
    const slots = document.createElement("div");
    slots.className = "po-research-reward-slots";
    ["Portrait / 头像", "Frame / 边框", "Background / 背景", "Name glow / 名字辉光", "Chat bubble / 聊天气泡", "Badge / 徽章", "Title / 称号"].forEach(label => {
      const slot = document.createElement("span");
      slot.textContent = label;
      slots.append(slot);
    });
    const note = document.createElement("p");
    note.className = "po-research-reward-note";
    note.textContent = "Equipped on this device. Sign in later to preserve it across devices. / 奖励已在此设备装备，之后登录账号即可跨设备保存。";
    copy.append(
      level,
      slots,
      note,
      makeButton(isBaselineReward ? "Continue / 继续" : "Return to the stars / 返回星空", "po-research-primary po-research-reward-continue", afterReward),
    );
    content.append(sky, seal, copy);
    showOverlay(content, "reward-reveal");
  }

  function showAssignment(assignment) {
    const route = assignment === "field_gameplay" ? "field_gameplay" : "archive_text";
    const content = document.createElement("div");
    content.className = "po-research-assignment";
    content.append(heading("Study route ready / 研究路线已准备", route === "archive_text" ? "Continue with the archive reading route. / 继续档案阅读路线。" : "Continue with the field gameplay route. / 继续实地游戏路线。"));
    content.append(makeButton(route === "archive_text" ? "Open archive / 打开档案" : "Continue gameplay / 继续游戏", "po-research-primary", () => {
      removeOverlay();
      if (route === "archive_text") exitToArchive();
      else continueGodot();
    }));
    showOverlay(content, "assignment");
  }

  function showQuestionFlow(kind, receivedQuestions, submit) {
    const questions = (Array.isArray(receivedQuestions) && receivedQuestions.length ? receivedQuestions : FALLBACK_QUESTIONS).slice(0, 3);
    const submissionNode = currentServerNode();
    const answers = { ...(state.pendingSubmission?.nodeId === submissionNode ? state.pendingSubmission.answers : {}) };
    const startedAt = Date.now();
    let index = 0;

    const render = () => {
      const question = questions[index];
      const content = document.createElement("div");
      content.className = "po-research-question-card";
      content.dataset.researchProgress = `${index + 1} of ${questions.length}`;
      const progress = document.createElement("p");
      progress.className = "po-research-progress";
      progress.dataset.researchProgress = `${index + 1} of ${questions.length}`;
      progress.textContent = `${index + 1} of ${questions.length} / 第 ${index + 1} 题，共 ${questions.length} 题`;
      const prompt = document.createElement("h2");
      prompt.className = "po-research-question";
      prompt.textContent = localize(question?.prompt) || "Please choose an answer. / 请选择一个答案。";
      const choices = document.createElement("fieldset");
      choices.className = "po-research-options";
      (Array.isArray(question?.options) ? question.options : []).forEach((option, optionIndex) => {
        const label = document.createElement("label");
        label.className = "po-research-option";
        const input = document.createElement("input");
        input.type = "radio";
        input.name = `po-research-${question.id}`;
        input.value = String(option?.id || option?.value || optionIndex);
        input.checked = answers[question.id] === input.value;
        input.addEventListener("change", () => {
          answers[question.id] = input.value;
          next.disabled = false;
        });
        const text = document.createElement("span");
        text.textContent = localize(option) || "Option";
        label.append(input, text);
        choices.append(label);
      });
      const actions = document.createElement("div");
      actions.className = "po-research-actions";
      const next = makeButton(index === questions.length - 1 ? "Submit / 提交" : "Next / 下一题", "po-research-primary", async () => {
        if (!answers[question.id]) return;
        if (index < questions.length - 1) {
          index += 1;
          render();
          return;
        }
        saveState({ pendingSubmission: { nodeId: submissionNode, answers } });
        try {
          const outcome = await submit(answers, Math.max(0, Math.floor((Date.now() - startedAt) / 1000)));
          if (!outcome?.keepOpen) completeResearch();
        } catch (error) {
          showError(error, () => showQuestionFlow(kind, questions, submit), "retry-submission");
        }
      });
      next.disabled = !answers[question.id];
      actions.append(next, makeButton("Later / 稍后", "po-research-secondary", deferResearch));
      content.append(progress, prompt, choices, actions);
      showOverlay(content, kind);
    };
    render();
  }

  function showGameplayQuestions() {
    showQuestionFlow("gameplay", serverRefreshedSession?.questions || FALLBACK_QUESTIONS, async (answers, durationSeconds) => {
      const nodeId = currentServerNode();
      const result = await request("/submit", authenticatedBody({ nodeId, answers, durationSeconds }));
      updateServerState(result);
      saveState({ pendingSubmission: null });
      if (result?.rewardOffer) {
        showRewardChoice(result.rewardOffer, completeResearch);
        return { keepOpen: true };
      }
    });
  }

  function showError(error, retry, retryClass = "") {
    const content = document.createElement("div");
    content.className = "po-research-error";
    content.append(heading("Could not save your answers / 无法保存您的答案", "Your selected answers are kept on this device. Please try again. / 您选择的答案已保留在此设备上，请重试。"));
    const message = document.createElement("p");
    message.className = "po-research-error-message";
    message.textContent = error?.message || "Connection error / 连接错误";
    const actions = document.createElement("div");
    actions.className = "po-research-actions";
    actions.append(makeButton("Retry / 重试", `po-research-primary ${retryClass}`.trim(), retry), makeButton("Later / 稍后", "po-research-secondary", deferResearch));
    content.append(message, actions);
    showOverlay(content, "error");
  }

  function showSessionSilenceOffer() {
    const content = document.createElement("div");
    content.className = "po-research-settings";
    content.append(heading("Research reminders / 研究提醒", "You have deferred this questionnaire twice. / 您已两次选择稍后。"));
    const actions = document.createElement("div");
    actions.className = "po-research-actions";
    actions.append(
      makeButton("Stop reminders for this session / 本次会话不再提醒", "po-research-primary", () => {
        sessionSilenced = true;
        completeResearch();
      }),
      makeButton("Keep reminders / 保留提醒", "po-research-secondary", completeResearch)
    );
    content.append(actions);
    showOverlay(content, "session-silence");
  }

  async function deferResearch() {
    const nodeId = currentServerNode();
    if (!hasCredentials() || !nodeId) {
      completeResearch();
      return;
    }
    try {
      const result = await request("/defer", authenticatedBody({ nodeId }));
      const nextState = updateServerState(result);
      if (Number(result?.deferCount || nextState.deferCounts?.[nodeId] || 0) >= 2) {
        showSessionSilenceOffer();
        return;
      }
    } catch (_) {
      // Deferral is optional; an outage must not block the game.
    }
    completeResearch();
  }

  function completeResearch() {
    removeOverlay();
    continueGodot();
  }

  function continueGodot() {
    if (typeof window.__poResearchContinue === "function") {
      window.__poResearchContinue(JSON.stringify({ nodeId: activeNodeId() }));
    }
  }

  function exitToArchive() {
    if (typeof window.__poResearchExitToArchive === "function") {
      window.__poResearchExitToArchive();
      return;
    }
    window.location.assign("/study/");
  }

  function openSettings() {
    const content = document.createElement("div");
    content.className = "po-research-settings";
    content.append(heading("Research reminders / 研究提醒", "Reminder silence lasts only for this browser session. / 提醒静默仅限本次浏览器会话。"));
    const actions = document.createElement("div");
    actions.className = "po-research-actions";
    actions.append(
      makeButton("Enable reminders / 开启提醒", "po-research-primary", () => {
        sessionSilenced = false;
        completeResearch();
      }),
      makeButton("Close / 关闭", "po-research-secondary", completeResearch)
    );
    content.append(actions);
    showOverlay(content, "settings");
  }

  async function handleCheckpoint(event) {
    activeCheckpoint = event?.detail || {};
    if (activeNodeId() === "baseline") {
      if (!hasCredentials()) {
        showInvitation();
        return;
      }
      try {
        await refreshResearchSession();
      } catch (_) {
        serverRefreshedSession = null;
        completeResearch();
        return;
      }
      if (currentServerNode() === "baseline") showBaseline(serverRefreshedSession.questions || FALLBACK_QUESTIONS);
      else completeResearch();
      return;
    }
    if (!hasCredentials()) {
      completeResearch();
      return;
    }
    try {
      await refreshResearchSession();
      await recordCheckpoint(activeCheckpoint);
    } catch (_) {
      completeResearch();
      return;
    }
    if (!sessionSilenced && hasVerifiedGameplaySession()) showGameplayQuestions();
    else completeResearch();
  }

  function activeResearchContext() {
    return {
      participantId: serverRefreshedSession?.participantId || "",
      routeArm: serverRefreshedSession?.routeArm || "",
    };
  }

  window.addEventListener("observatory:research-checkpoint", handleCheckpoint);
  window.PixelObservatoryResearch = Object.assign(window.PixelObservatoryResearch || {}, {
    openSettings,
    refreshResearchSession,
    handleCheckpoint,
    canOfferBaseline,
    hasVerifiedGameplaySession,
    activeResearchContext,
  });
})();
