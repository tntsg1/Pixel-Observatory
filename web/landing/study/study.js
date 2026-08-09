(() => {
  "use strict";

  import("./research-content.mjs").then(({ TEXT_ARCHIVE_MODULES }) => {
    const app = document.getElementById("study-app");
    const sessionStorageKey = "pixel-observatory:research-session:v2";
    const moduleNodeIds = Object.keys(TEXT_ARCHIVE_MODULES);
    const staticCopy = {
      sessionLabel: ["Research session", "研究会话"],
      privacyFooter: ["Anonymous research record. No game account or personal details are required.", "匿名研究记录，无需游戏账号或个人信息。"],
    };

    let session = loadSession() || createPrestudySession();
    let language = session.language;
    let serverState = null;
    let notice = "";
    let resumeError = "";
    let settingsOpen = false;
    let crossExposureNotice = false;
    let surveyNodeId = "";
    let surveyStartedAt = 0;

    persistSession();
    bindEvents();
    updateChrome();
    if (hasServerSession()) refreshSession();
    else render();

    function createPrestudySession() {
      return {
        participantId: createPrestudyId(),
        token: "",
        language: "en",
        noRemindSessionNodes: [],
      };
    }

    function createPrestudyId() {
      if (globalThis.crypto?.randomUUID) return `local-prestudy-${globalThis.crypto.randomUUID()}`;
      const values = new Uint32Array(2);
      globalThis.crypto?.getRandomValues?.(values);
      return `local-prestudy-${Date.now().toString(36)}-${values[0].toString(36)}${values[1].toString(36)}`;
    }

    function loadSession() {
      try {
        const parsed = JSON.parse(localStorage.getItem(sessionStorageKey) || "null");
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
        const noRemindSessionNodes = [...new Set(
          (Array.isArray(parsed.noRemindSessionNodes) ? parsed.noRemindSessionNodes : [])
            .filter(nodeId => moduleNodeIds.includes(nodeId)),
        )];
        const participantId = typeof parsed.participantId === "string" ? parsed.participantId : "";
        if (!participantId) return null;
        return {
          participantId,
          token: typeof parsed.token === "string" ? parsed.token : "",
          language: parsed.language === "zh" ? "zh" : "en",
          noRemindSessionNodes,
        };
      } catch (_) {
        return null;
      }
    }

    function persistSession() {
      const persisted = {
        participantId: session.participantId,
        token: session.token,
        language,
        noRemindSessionNodes: session.noRemindSessionNodes,
      };
      session = persisted;
      try {
        localStorage.setItem(sessionStorageKey, JSON.stringify(persisted));
      } catch (_) {}
    }

    function hasServerSession() {
      return Boolean(session.participantId && session.token);
    }

    function t(en, zh) {
      return language === "zh" ? zh : en;
    }

    function localText(value) {
      return value?.[language] || value?.en || "";
    }

    function escapeHtml(value) {
      return String(value ?? "").replace(/[&<>"']/g, character => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[character]);
    }

    function updateChrome() {
      document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
      document.documentElement.dataset.lang = language;
      document.title = t("Pixel Observatory Research Study", "像素观测站研究");
      document.querySelectorAll("[data-language]").forEach(button => {
        const selected = button.dataset.language === language;
        button.setAttribute("aria-pressed", String(selected));
        button.textContent = button.dataset.language === "zh" ? "中文" : "EN";
      });
      document.querySelectorAll("[data-copy]").forEach(node => {
        const value = staticCopy[node.dataset.copy];
        if (value) node.textContent = localText({ en: value[0], zh: value[1] });
      });
      const languageSwitch = document.querySelector(".language-switch");
      if (languageSwitch) languageSwitch.setAttribute("aria-label", t("Language", "语言"));
    }

    function setLanguage(nextLanguage) {
      language = nextLanguage === "zh" ? "zh" : "en";
      session.language = language;
      persistSession();
      updateChrome();
      render();
    }

    async function api(path, body) {
      const response = await fetch(path, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      let payload = {};
      try {
        payload = await response.json();
      } catch (_) {}
      if (!response.ok) throw new Error(payload.message || t("The research service could not complete that request.", "研究服务无法完成该请求。"));
      return payload;
    }

    function authenticated(body = {}) {
      return { ...body, participantId: session.participantId, token: session.token };
    }

    function gameUrl() {
      return `/game/?mode=study&research_intro=1&participant=${encodeURIComponent(session.participantId)}&study_reset=${Date.now()}`;
    }

    function view(markup, name) {
      app.dataset.view = name;
      app.setAttribute("aria-busy", "false");
      app.innerHTML = markup;
    }

    function noticeMarkup() {
      return notice ? `<p class="status-note" role="status">${escapeHtml(notice)}</p>` : "";
    }

    function errorMarkup() {
      return "<p class=\"error\" data-error role=\"alert\"></p>";
    }

    function showError(message) {
      const error = app.querySelector("[data-error]");
      if (error) error.textContent = message;
      else {
        notice = message;
        render();
      }
    }

    function render() {
      updateChrome();
      if (!hasServerSession()) return renderFreshEntry();
      if (resumeError) return renderResumeError();
      if (!serverState) return renderLoading();
      if (serverState.withdrawn) return renderWithdrawn();
      if (serverState.routeArm === "archive_text" && TEXT_ARCHIVE_MODULES[serverState.currentNode]) {
        return renderArchiveRoute(TEXT_ARCHIVE_MODULES[serverState.currentNode]);
      }
      if (serverState.completedNodes?.includes("E")) return renderCompleted();
      return renderGameReturn();
    }

    function renderFreshEntry() {
      view(`
        <section class="study-view fresh-entry" data-view="fresh-entry">
          <p class="eyebrow">${t("Optional research", "可选研究")}</p>
          <h1>${t("Start with the original observatory opening.", "从原始观测站开场开始。")}</h1>
          <p class="lead">${t(
            "This optional study follows your normal Pixel Observatory journey. Start from the opening and complete Level 1 in the original game; the next in-game step will guide any optional research activity.",
            "这项可选研究会跟随你正常的《像素观测站》旅程。请从原始开场开始，并在原游戏中完成第 1 关；下一步可选研究会在游戏内引导你继续。",
          )}</p>
          <div class="actions">
            <a class="primary" data-action="start-opening" href="${escapeHtml(gameUrl())}">${t("Start from the opening", "从开场开始")}</a>
          </div>
          <p class="fine">${t("Your game progress remains in an isolated study session.", "你的游戏进度会保留在独立的研究会话中。")}</p>
        </section>
      `, "fresh-entry");
    }

    function renderLoading() {
      view(`
        <section class="study-view loading-view" data-view="loading">
          <p class="eyebrow">${t("Research session", "研究会话")}</p>
          <h1>${t("Restoring your session", "正在恢复你的会话")}</h1>
          <p class="lead">${t("Checking the next available step.", "正在检查下一步。")}</p>
        </section>
      `, "loading");
      app.setAttribute("aria-busy", "true");
    }

    function renderResumeError() {
      view(`
        <section class="study-view resume-error" data-view="resume-error">
          <p class="eyebrow">${t("Research session", "研究会话")}</p>
          <h1>${t("We could not restore this session.", "无法恢复此会话。")}</h1>
          <p class="lead">${escapeHtml(resumeError)}</p>
          <div class="actions">
            <button class="secondary" type="button" data-action="retry-session">${t("Try again", "重试")}</button>
          </div>
        </section>
      `, "resume-error");
    }

    function renderArchiveRoute(module) {
      const nodeId = serverState.currentNode;
      const paused = session.noRemindSessionNodes.includes(nodeId);
      const questions = Array.isArray(serverState.questions) ? serverState.questions : [];
      const deferCount = Number(serverState.deferCounts?.[nodeId] || 0);
      const article = module.body[language]
        .split(/\n{2,}/)
        .map(paragraph => `<p>${escapeHtml(paragraph)}</p>`)
        .join("");
      const survey = paused
        ? pausedSurveyMarkup(nodeId)
        : questions.length === 3
          ? surveyMarkup(nodeId, questions, deferCount)
          : unavailableSurveyMarkup();

      if (!paused && questions.length === 3 && surveyNodeId !== nodeId) restartSurveyTimer(nodeId);

      view(`
        <section class="study-view archive-route" data-view="archive-text">
          <p class="eyebrow">${t("Text archive", "文字档案")}</p>
          <h1>${escapeHtml(localText(module.title))}</h1>
          ${noticeMarkup()}
          <article class="archive-reading" data-archive-node="${escapeHtml(nodeId)}">
            ${article}
          </article>
          ${survey}
          ${settingsMarkup()}
          ${crossExposureMarkup()}
          ${withdrawalControlMarkup()}
          ${withdrawalDialogMarkup()}
        </section>
      `, "archive-text");
    }

    function surveyMarkup(nodeId, questions, deferCount) {
      return `
        <section class="survey" aria-labelledby="survey-title">
          <div class="section-heading">
            <div>
              <p class="eyebrow">${t("Three questions", "三道问题")}</p>
              <h2 id="survey-title">${t("Check your understanding", "检查你的理解")}</h2>
            </div>
            <span class="reminder-count">${escapeHtml(t(`Reminders used: ${deferCount} of 2`, `已使用提醒：${deferCount}/2`))}</span>
          </div>
          <form class="study-form" data-research-survey data-node-id="${escapeHtml(nodeId)}">
            ${questions.map((question, index) => questionMarkup(question, index)).join("")}
            ${errorMarkup()}
            <div class="actions survey-actions">
              <button class="primary" type="submit">${t("Record answers", "记录答案")}</button>
              ${deferCount < 2 ? `<button class="secondary" type="button" data-action="defer" data-node-id="${escapeHtml(nodeId)}">${t("Remind me later", "稍后提醒我")}</button>` : ""}
              <button class="text-button" type="button" data-action="no-remind" data-node-id="${escapeHtml(nodeId)}">${t("No more reminders this session", "本次会话不再提醒")}</button>
            </div>
          </form>
        </section>
      `;
    }

    function questionMarkup(question, index) {
      const questionId = String(question.id || "");
      const fieldName = `answer-${questionId}`;
      return `
        <fieldset class="question" data-question="${escapeHtml(questionId)}">
          <legend>${index + 1}. ${escapeHtml(localText(question.prompt))}</legend>
          <div class="options">
            ${(Array.isArray(question.options) ? question.options : []).map(option => {
              const optionId = String(option.id || "");
              const inputId = `${fieldName}-${optionId}`.replace(/[^a-zA-Z0-9_-]/g, "-");
              return `<label class="option" for="${escapeHtml(inputId)}"><input id="${escapeHtml(inputId)}" type="radio" name="${escapeHtml(fieldName)}" value="${escapeHtml(optionId)}" required><span>${escapeHtml(localText(option))}</span></label>`;
            }).join("")}
          </div>
        </fieldset>
      `;
    }

    function pausedSurveyMarkup(nodeId) {
      return `
        <section class="survey survey-paused" aria-labelledby="paused-title">
          <p class="eyebrow">${t("Reminder setting", "提醒设置")}</p>
          <h2 id="paused-title">${t("Reminders are paused for this session.", "本次会话已暂停提醒。")}</h2>
          <p>${t("You can turn reminders back on from settings whenever you are ready.", "准备好后，你可以随时在设置中重新开启提醒。")}</p>
          <div class="actions">
            <button class="secondary" type="button" data-action="open-settings">${t("Open settings", "打开设置")}</button>
            <button class="text-button" type="button" data-action="enable-reminder" data-node-id="${escapeHtml(nodeId)}">${t("Turn reminders back on", "重新开启提醒")}</button>
          </div>
        </section>
      `;
    }

    function unavailableSurveyMarkup() {
      return `
        <section class="survey survey-paused" aria-labelledby="unavailable-title">
          <p class="eyebrow">${t("Research session", "研究会话")}</p>
          <h2 id="unavailable-title">${t("This step is not available yet.", "此步骤暂不可用。")}</h2>
          <p>${t("Return to the original game and continue the current study progress.", "请回到原游戏，继续当前研究进度。")}</p>
        </section>
      `;
    }

    function settingsMarkup() {
      if (!settingsOpen) {
        return `<div class="settings-trigger"><button class="text-button" type="button" data-action="open-settings">${t("Study settings", "研究设置")}</button></div>`;
      }
      const pausedNodes = session.noRemindSessionNodes;
      const pausedList = pausedNodes.length
        ? `<ul>${pausedNodes.map(nodeId => `<li><span>${escapeHtml(localText(TEXT_ARCHIVE_MODULES[nodeId]?.title) || nodeId)}</span><button class="secondary compact" type="button" data-action="enable-reminder" data-node-id="${escapeHtml(nodeId)}">${t("Enable", "启用")}</button></li>`).join("")}</ul>`
        : `<p>${t("All available reminders are enabled for this session.", "本次会话中所有可用提醒均已启用。")}</p>`;
      return `
        <section class="study-settings" aria-labelledby="settings-title">
          <div class="section-heading">
            <div>
              <p class="eyebrow">${t("Settings", "设置")}</p>
              <h2 id="settings-title">${t("Reminder settings", "提醒设置")}</h2>
            </div>
            <button class="icon-button" type="button" data-action="close-settings" aria-label="${t("Close settings", "关闭设置")}" title="${t("Close settings", "关闭设置")}">×</button>
          </div>
          ${pausedList}
        </section>
      `;
    }

    function crossExposureMarkup() {
      if (serverState.routeArm !== "archive_text" || serverState.completedNodes?.includes("E")) return "";
      if (serverState.crossExposed || crossExposureNotice) {
        return `
          <section class="cross-exposure" role="status">
            <p>${t("Your research record remains usable, but ordinary gameplay exposure excludes it from the primary comparison.", "你的研究记录仍可使用，但普通游戏接触会使其不纳入主要比较。")}</p>
            <a class="secondary" href="/game/">${t("Continue to ordinary game", "继续普通游戏")}</a>
          </section>
        `;
      }
      return `<div class="ordinary-game"><button class="text-button" type="button" data-action="ordinary-game">${t("Open ordinary gameplay", "打开普通游戏")}</button></div>`;
    }

    function withdrawalControlMarkup() {
      return `<div class="withdrawal-control"><button class="text-button" type="button" data-action="open-withdrawal">${t("Withdraw this anonymous record", "撤回此匿名记录")}</button></div>`;
    }

    function withdrawalDialogMarkup() {
      return `
        <dialog class="withdrawal-dialog" data-withdrawal-dialog aria-labelledby="withdrawal-title">
          <form method="dialog">
            <p class="eyebrow">${t("Confirm withdrawal", "确认撤回")}</p>
            <h2 id="withdrawal-title">${t("Withdraw this anonymous record?", "撤回此匿名记录？")}</h2>
            <p>${t("This asks the research service to mark this anonymous record as withdrawn.", "这会请求研究服务将此匿名记录标记为已撤回。")}</p>
            <div class="actions">
              <button class="secondary" value="cancel">${t("Keep record", "保留记录")}</button>
              <button class="primary danger" type="button" data-action="confirm-withdrawal">${t("Confirm withdrawal", "确认撤回")}</button>
            </div>
            ${errorMarkup()}
          </form>
        </dialog>
      `;
    }

    function renderGameReturn() {
      view(`
        <section class="study-view game-return" data-view="game-return">
          <p class="eyebrow">${t("Research session", "研究会话")}</p>
          <h1>${t("Continue in the original game.", "请在原游戏中继续。")}</h1>
          <p class="lead">${t("The next research step is available through your original Pixel Observatory progress.", "下一项研究步骤会随你在原始《像素观测站》中的进度开放。")}</p>
          ${noticeMarkup()}
          <div class="actions">
            <a class="primary" href="${escapeHtml(gameUrl())}">${t("Return to the observatory", "返回观测站")}</a>
          </div>
          ${withdrawalControlMarkup()}
          ${withdrawalDialogMarkup()}
        </section>
      `, "game-return");
    }

    function renderCompleted() {
      view(`
        <section class="study-view completion-view" data-view="completed">
          <p class="eyebrow">${t("Research session", "研究会话")}</p>
          <h1>${t("Research complete", "研究已完成")}</h1>
          <p class="lead">${t("All available text-route responses have been recorded.", "所有可用文字路线回答均已记录。")}</p>
          ${noticeMarkup()}
          ${settingsMarkup()}
          ${withdrawalControlMarkup()}
          ${withdrawalDialogMarkup()}
        </section>
      `, "completed");
    }

    function renderWithdrawn() {
      view(`
        <section class="study-view withdrawn-view" data-view="withdrawn">
          <p class="eyebrow">${t("Research session", "研究会话")}</p>
          <h1>${t("This anonymous record is withdrawn.", "此匿名记录已撤回。")}</h1>
          <p class="lead">${t("No further research responses will be recorded for this session.", "此会话不会再记录研究回答。")}</p>
        </section>
      `, "withdrawn");
    }

    async function refreshSession() {
      if (!hasServerSession()) return render();
      resumeError = "";
      serverState = null;
      render();
      try {
        const payload = await api("/api/research/session", authenticated());
        serverState = payload.state;
        render();
      } catch (error) {
        resumeError = error.message;
        render();
      }
    }

    async function submitSurvey(form) {
      const nodeId = form.dataset.nodeId;
      const questions = Array.isArray(serverState?.questions) ? serverState.questions : [];
      const formData = new FormData(form);
      const answers = Object.fromEntries(questions.map(question => [
        question.id,
        String(formData.get(`answer-${question.id}`) || ""),
      ]));
      if (questions.length !== 3 || Object.values(answers).some(answer => !answer)) {
        showError(t("Choose one answer for each question.", "请为每道问题选择一个答案。"));
        return;
      }
      setFormBusy(form, true);
      try {
        const payload = await api("/api/research/submit", authenticated({
          nodeId,
          answers,
          durationSeconds: Math.max(1, Math.round((Date.now() - surveyStartedAt) / 1_000)),
        }));
        serverState = payload.state;
        notice = t("Answers recorded.", "答案已记录。");
        surveyNodeId = "";
        dispatchRewardOffer(payload.rewardOffer);
        render();
      } catch (error) {
        setFormBusy(form, false);
        showError(error.message);
      }
    }

    function setFormBusy(form, busy) {
      form.querySelectorAll("button, input").forEach(control => {
        control.disabled = busy;
      });
    }

    async function deferCurrentNode(nodeId) {
      const button = app.querySelector(`[data-action="defer"][data-node-id="${CSS.escape(nodeId)}"]`);
      if (button) button.disabled = true;
      try {
        const payload = await api("/api/research/defer", authenticated({ nodeId }));
        serverState = payload.state;
        notice = t(`Reminder saved (${payload.deferCount} of 2).`, `已保存提醒（${payload.deferCount}/2）。`);
        render();
      } catch (error) {
        if (button) button.disabled = false;
        showError(error.message);
      }
    }

    function disableReminders(nodeId) {
      if (!session.noRemindSessionNodes.includes(nodeId)) {
        session.noRemindSessionNodes = [...session.noRemindSessionNodes, nodeId];
        persistSession();
      }
      notice = t("Reminders are paused for this session.", "本次会话已暂停提醒。");
      render();
    }

    function enableReminders(nodeId) {
      session.noRemindSessionNodes = session.noRemindSessionNodes.filter(savedNodeId => savedNodeId !== nodeId);
      persistSession();
      restartSurveyTimer(nodeId);
      notice = t("Reminders are enabled for this session.", "本次会话已启用提醒。");
      render();
    }

    function restartSurveyTimer(nodeId) {
      surveyNodeId = nodeId;
      surveyStartedAt = Date.now();
    }

    async function markOrdinaryGameExposure() {
      const button = app.querySelector('[data-action="ordinary-game"]');
      if (button) button.disabled = true;
      try {
        const payload = await api("/api/research/exposure", authenticated({ kind: "ordinary_game" }));
        serverState = payload.state;
        crossExposureNotice = true;
        render();
      } catch (error) {
        if (button) button.disabled = false;
        showError(error.message);
      }
    }

    function openWithdrawalDialog() {
      const dialog = app.querySelector("[data-withdrawal-dialog]");
      if (dialog?.showModal) dialog.showModal();
      else if (dialog) dialog.setAttribute("open", "");
    }

    async function withdraw() {
      const dialog = app.querySelector("[data-withdrawal-dialog]");
      const confirm = dialog?.querySelector('[data-action="confirm-withdrawal"]');
      if (confirm) confirm.disabled = true;
      try {
        const payload = await api("/api/research/withdraw", authenticated());
        serverState = payload.state;
        settingsOpen = false;
        notice = t("This anonymous record has been withdrawn.", "此匿名记录已撤回。");
        if (dialog?.open) dialog.close();
        render();
      } catch (error) {
        if (confirm) confirm.disabled = false;
        const errorNode = dialog?.querySelector("[data-error]");
        if (errorNode) errorNode.textContent = error.message;
        else showError(error.message);
      }
    }

    function dispatchRewardOffer(offer) {
      if (!offer || !offer.offerId || !offer.nodeId || !Array.isArray(offer.candidates)) return;
      window.dispatchEvent(new CustomEvent("po:research-reward-offer", {
        detail: { offerId: offer.offerId, nodeId: offer.nodeId, candidates: offer.candidates },
      }));
    }

    function bindEvents() {
      document.querySelectorAll("[data-language]").forEach(button => {
        button.addEventListener("click", () => setLanguage(button.dataset.language));
      });
      app.addEventListener("submit", event => {
        const form = event.target.closest("[data-research-survey]");
        if (!form) return;
        event.preventDefault();
        submitSurvey(form);
      });
      app.addEventListener("click", event => {
        const control = event.target.closest("[data-action]");
        if (!control || control.tagName === "A") return;
        const nodeId = control.dataset.nodeId;
        switch (control.dataset.action) {
          case "retry-session":
            refreshSession();
            break;
          case "defer":
            deferCurrentNode(nodeId);
            break;
          case "no-remind":
            disableReminders(nodeId);
            break;
          case "enable-reminder":
            enableReminders(nodeId);
            break;
          case "open-settings":
            settingsOpen = true;
            render();
            break;
          case "close-settings":
            settingsOpen = false;
            render();
            break;
          case "ordinary-game":
            markOrdinaryGameExposure();
            break;
          case "open-withdrawal":
            openWithdrawalDialog();
            break;
          case "confirm-withdrawal":
            withdraw();
            break;
          default:
            break;
        }
      });
    }
  }).catch(error => {
    const app = document.getElementById("study-app");
    if (app) app.textContent = error instanceof Error ? error.message : "Unable to load the research study.";
  });
})();
