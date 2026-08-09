(() => {
  "use strict";

  const SESSION_KEY = "pixel-observatory:research-session:v2";
  const API = "/api/research";
  const FALLBACK_QUESTIONS = [
    {
      id: "clarity",
      prompt: "The activity goals were clear. / 我清楚理解了活动目标。",
      options: ["Strongly disagree / 非常不同意", "Disagree / 不同意", "Neutral / 一般", "Agree / 同意", "Strongly agree / 非常同意"],
    },
    {
      id: "confidence",
      prompt: "I felt able to make progress. / 我觉得自己能够取得进展。",
      options: ["Strongly disagree / 非常不同意", "Disagree / 不同意", "Neutral / 一般", "Agree / 同意", "Strongly agree / 非常同意"],
    },
    {
      id: "return",
      prompt: "I would like to continue this activity. / 我愿意继续这个活动。",
      options: ["Strongly disagree / 非常不同意", "Disagree / 不同意", "Neutral / 一般", "Agree / 同意", "Strongly agree / 非常同意"],
    },
  ];

  let serverRefreshedSession = null;
  let activeCheckpoint = null;
  let activeFlow = null;
  let restoreFocusTo = null;

  function readStoredState() {
    try {
      return JSON.parse(window.localStorage.getItem(SESSION_KEY)) || {};
    } catch (_) {
      return {};
    }
  }

  let state = readStoredState();

  function saveState(patch) {
    state = { ...state, ...patch };
    try {
      window.localStorage.setItem(SESSION_KEY, JSON.stringify(state));
    } catch (_) {
      // The research service remains the source of truth if storage is unavailable.
    }
  }

  function canOfferBaseline() {
    return Boolean(
      activeCheckpoint &&
      String(activeCheckpoint.nodeId || activeCheckpoint.node || activeCheckpoint.id || "").toUpperCase() === "L1" &&
      !state.baselineComplete &&
      !state.declined &&
      !serverRefreshedSession?.baselineComplete
    );
  }

  function hasVerifiedGameplaySession() {
    return Boolean(
      serverRefreshedSession &&
      (serverRefreshedSession.hasVerifiedGameplaySession === true ||
        serverRefreshedSession.verifiedGameplaySession === true ||
        serverRefreshedSession.gameplaySessionVerified === true)
    );
  }

  async function request(path, method = "GET", body) {
    const response = await fetch(`${API}${path}`, {
      method,
      credentials: "same-origin",
      headers: body ? { "Content-Type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || payload.message || "Research service is unavailable.");
    }
    return payload;
  }

  async function refreshResearchSession() {
    const result = await request("/session");
    serverRefreshedSession = result.session || result;
    saveState({ serverSessionSeen: true });
    return serverRefreshedSession;
  }

  async function recordCheckpoint(checkpoint) {
    return request("/checkpoint", "POST", { checkpoint });
  }

  function removeOverlay() {
    document.querySelector(".po-research-overlay")?.remove();
    activeFlow = null;
    document.removeEventListener("keydown", trapFocus, true);
    if (restoreFocusTo && document.contains(restoreFocusTo)) {
      restoreFocusTo.focus();
    }
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
      const result = await request("/enroll", "POST", { consent: true, checkpoint: activeCheckpoint });
      serverRefreshedSession = result.session || result;
      saveState({ consented: true, declined: false });
      showBaseline(result.baselineQuestions || result.questions || FALLBACK_QUESTIONS);
    } catch (error) {
      showError(error, () => enroll());
    }
  }

  function showBaseline(questions) {
    showQuestionFlow("baseline", questions, async (answers) => {
      const result = await request("/submit", "POST", { nodeId: "L1", kind: "baseline", answers });
      serverRefreshedSession = result.session || result;
      saveState({ baselineComplete: true, pendingSubmission: null });
      showAssignment(result.assignment || serverRefreshedSession.assignment || serverRefreshedSession.routeArm);
      return { keepOpen: true };
    });
  }

  function showAssignment(assignment) {
    const route = assignment === "field_gameplay" ? "field_gameplay" : "archive_text";
    const content = document.createElement("div");
    content.className = "po-research-assignment";
    content.append(heading("Study route ready / 研究路线已准备", route === "archive_text" ? "Continue with the archive reading route. / 继续档案阅读路线。" : "Continue with the field gameplay route. / 继续实地游戏路线。"));
    content.append(makeButton(route === "archive_text" ? "Open archive / 打开档案" : "Continue gameplay / 继续游戏", "po-research-primary", () => {
      removeOverlay();
      if (route === "archive_text") {
        exitToArchive();
      } else {
        continueGodot(serverRefreshedSession?.seed || serverRefreshedSession?.l1Seed);
      }
    }));
    showOverlay(content, "assignment");
  }

  function showQuestionFlow(kind, receivedQuestions, submit) {
    const questions = (Array.isArray(receivedQuestions) && receivedQuestions.length >= 3 ? receivedQuestions : FALLBACK_QUESTIONS).slice(0, 3);
    const answers = { ...(state.pendingSubmission?.kind === kind ? state.pendingSubmission.answers : {}) };
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
      prompt.textContent = question.prompt || question.text || "Please choose an answer. / 请选择一个答案。";
      const choices = document.createElement("fieldset");
      choices.className = "po-research-options";
      const options = question.options || [];
      options.forEach((option, optionIndex) => {
        const label = document.createElement("label");
        label.className = "po-research-option";
        const input = document.createElement("input");
        input.type = "radio";
        input.name = `po-research-${question.id}`;
        input.value = option.id || option.value || String(optionIndex);
        input.checked = answers[question.id] === input.value;
        input.addEventListener("change", () => {
          answers[question.id] = input.value;
          next.disabled = false;
        });
        const text = document.createElement("span");
        text.textContent = option.label || option.text || option;
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
        saveState({ pendingSubmission: { kind, answers } });
        try {
          const outcome = await submit(answers);
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
    const questions = serverRefreshedSession?.questions || serverRefreshedSession?.checkpointQuestions || FALLBACK_QUESTIONS;
    showQuestionFlow("gameplay", questions, async (answers) => {
      await request("/submit", "POST", { nodeId: activeCheckpoint?.nodeId, kind: "gameplay", answers });
      saveState({ pendingSubmission: null });
    });
  }

  function showError(error, retry, retryClass = "") {
    const content = document.createElement("div");
    content.className = "po-research-error";
    content.append(heading("Could not save your answers / 无法保存您的答案", "Your selected answers are kept on this device. Please try again. / 您选择的答案已保留在此设备上，请重试。"));
    const message = document.createElement("p");
    message.className = "po-research-error-message";
    message.textContent = error?.message || "Connection error / 连接错误";
    content.append(message);
    const actions = document.createElement("div");
    actions.className = "po-research-actions";
    actions.append(makeButton("Retry / 重试", `po-research-primary ${retryClass}`.trim(), retry), makeButton("Later / 稍后", "po-research-secondary", deferResearch));
    content.append(actions);
    showOverlay(content, "error");
  }

  async function deferResearch() {
    try {
      const result = await request("/defer", "POST", { checkpoint: activeCheckpoint, flow: activeFlow });
      serverRefreshedSession = result.session || result;
      const deferrals = Number(serverRefreshedSession.deferralCount ?? serverRefreshedSession.deferrals ?? (state.deferrals || 0) + 1);
      const silence = deferrals >= 2 || serverRefreshedSession.sessionSilenced === true;
      saveState({ deferrals, sessionSilenced: silence });
    } catch (_) {
      // Deferral is optional; closing still must release the player back to Godot.
    }
    removeOverlay();
    continueGodot();
  }

  function completeResearch() {
    removeOverlay();
    continueGodot();
  }

  function continueGodot(seed) {
    if (typeof window.__poResearchContinue === "function") {
      window.__poResearchContinue(seed);
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
    content.append(heading("Research reminders / 研究提醒", "Reminders are paused after two Later choices. You can re-enable them here. / 两次选择稍后后，提醒将暂停；可在此重新开启。"));
    const actions = document.createElement("div");
    actions.className = "po-research-actions";
    actions.append(
      makeButton("Enable reminders / 开启提醒", "po-research-primary", async () => {
        try {
          const result = await request("/defer", "POST", { action: "resume_reminders" });
          serverRefreshedSession = result.session || result;
          saveState({ sessionSilenced: false, deferrals: 0 });
          removeOverlay();
          continueGodot();
        } catch (error) {
          showError(error, openSettings);
        }
      }),
      makeButton("Close / 关闭", "po-research-secondary", () => {
        removeOverlay();
        continueGodot();
      })
    );
    content.append(actions);
    showOverlay(content, "settings");
  }

  async function handleCheckpoint(event) {
    activeCheckpoint = event?.detail || {};
    try {
      await recordCheckpoint(activeCheckpoint);
      await refreshResearchSession();
    } catch (_) {
      // A research outage must never block the game session.
      continueGodot();
      return;
    }
    if (canOfferBaseline()) {
      showInvitation();
    } else if (!state.sessionSilenced && !serverRefreshedSession.sessionSilenced && hasVerifiedGameplaySession()) {
      showGameplayQuestions();
    } else {
      continueGodot();
    }
  }

  window.addEventListener("observatory:research-checkpoint", handleCheckpoint);
  window.PixelObservatoryResearch = Object.assign(window.PixelObservatoryResearch || {}, {
    openSettings,
    refreshResearchSession,
    handleCheckpoint,
    canOfferBaseline,
    hasVerifiedGameplaySession,
  });
})();
