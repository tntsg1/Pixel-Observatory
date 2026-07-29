(() => {
  "use strict";
  const messaging = window.POMessaging;
  const state = {
    user: null,
    conversations: [],
    activeId: null,
    activeSignature: "",
    activeUnsubscribe: null,
    badgeUnsubscribe: null,
    closeTimer: null,
    glassFrame: null,
    composeUsername: "",
  };
  const isZh = () => document.documentElement.dataset.lang === "zh";
  const t = (en, zh) => isZh() ? zh : en;
  const esc = messaging.escapeHtml;
  const when = messaging.when;
  function bindGlassPointer(element, xProperty, yProperty) {
    if (!element || element.dataset.glassPointer === "true") return;
    element.dataset.glassPointer = "true";
    let frame = 0;
    element.addEventListener("pointermove", event => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const bounds = element.getBoundingClientRect();
        const x = Math.max(0, Math.min(100, ((event.clientX - bounds.left) / Math.max(bounds.width, 1)) * 100));
        const y = Math.max(0, Math.min(100, ((event.clientY - bounds.top) / Math.max(bounds.height, 1)) * 100));
        element.style.setProperty(xProperty, `${x}%`);
        element.style.setProperty(yProperty, `${y}%`);
      });
    });
    element.addEventListener("pointerleave", () => {
      element.style.removeProperty(xProperty);
      element.style.removeProperty(yProperty);
    });
  }

  document.body.insertAdjacentHTML("beforeend", `
    <section class="po-modal" id="po-inbox-modal" hidden aria-modal="true" role="dialog" aria-label="Inbox">
      <div class="po-dialog po-inbox-dialog">
        <button class="po-close" type="button" aria-label="Close">&times;</button>
        <div id="po-inbox-content"></div>
      </div>
    </section>`);
  const modal = document.getElementById("po-inbox-modal");
  const content = document.getElementById("po-inbox-content");
  const badge = document.getElementById("inbox-badge");
  const dialog = modal.querySelector(".po-inbox-dialog");
  bindGlassPointer(document.getElementById("inbox-open"), "--nav-glass-x", "--nav-glass-y");
  bindGlassPointer(document.getElementById("feedback-open"), "--nav-glass-x", "--nav-glass-y");
  bindGlassPointer(modal.querySelector(".po-close"), "--close-glass-x", "--close-glass-y");

  const api = messaging.request;
  function setBadge(total) {
    if (!badge) return;
    const count = Number(total) || 0;
    badge.hidden = count < 1;
    badge.textContent = count > 99 ? "99+" : String(count);
  }
  async function refreshBadge() {
    try {
      const session = await api("/api/auth/session");
      state.user = session.user;
      if (!state.user) {
        state.badgeUnsubscribe?.();
        state.badgeUnsubscribe = null;
        return setBadge(0);
      }
      if (!state.badgeUnsubscribe) {
        state.badgeUnsubscribe = messaging.watchConversations((conversations, error) => {
          if (error || !conversations) return;
          state.conversations = conversations;
          setBadge(state.conversations.reduce((sum, item) => sum + Number(item.unread_count || 0), 0));
        });
      }
      state.conversations = await messaging.listConversations();
      setBadge(state.conversations.reduce((sum, item) => sum + Number(item.unread_count || 0), 0));
    } catch (_) {
      setBadge(0);
    }
  }
  function open(detail = {}) {
    const requestedUsername = String(detail?.username || "").trim();
    state.composeUsername = /^[a-zA-Z0-9_.-]{3,24}$/.test(requestedUsername) ? requestedUsername : "";
    clearTimeout(state.closeTimer);
    modal.classList.remove("po-inbox-closing");
    modal.hidden = false;
    document.getElementById("inbox-open")?.setAttribute("aria-expanded", "true");
    document.body.style.overflow = "hidden";
    render().then(() => {
      if (state.composeUsername) renderCompose();
    }).catch(showError);
  }
  function close() {
    if (modal.hidden || modal.classList.contains("po-inbox-closing")) return;
    modal.classList.add("po-inbox-closing");
    document.getElementById("inbox-open")?.setAttribute("aria-expanded", "false");
    state.activeUnsubscribe?.();
    state.activeUnsubscribe = null;
    clearTimeout(state.closeTimer);
    state.closeTimer = setTimeout(() => {
      modal.hidden = true;
      modal.classList.remove("po-inbox-closing");
      document.body.style.overflow = "";
      refreshBadge();
    }, 175);
  }
  function showError(error) {
    content.innerHTML = `<div class="po-thread-empty"><h2>${t("Inbox unavailable","信箱暂时不可用")}</h2><p>${esc(error.message)}</p></div>`;
  }
  async function render() {
    const session = await api("/api/auth/session");
    state.user = session.user;
    if (!state.user) {
      content.innerHTML = `<div class="po-thread-empty"><h2>${t("Observer inbox","观测员信箱")}</h2>
        <p>${t("Sign in through Account to send and receive messages.","请先通过“账号”登录，之后就能收发站内信。")}</p>
        <button class="po-primary" id="po-inbox-signin" type="button">${t("Open account","打开账号")}</button></div>`;
      document.getElementById("po-inbox-signin").onclick = () => {
        close();
        document.getElementById("account-open")?.click();
      };
      return;
    }
    content.innerHTML = `<div class="po-inbox-shell">
      <aside class="po-inbox-sidebar">
        <header class="po-inbox-head"><p class="po-inbox-kicker">${t("Observer network","观测员通信")}</p><h2>${t("Messages","信箱")}</h2><p>${esc(state.user.username)} · ${t("Online","在线")}</p></header>
        <button class="po-secondary po-compose" id="po-compose" type="button">${t("New message","写新消息")}</button>
        <div class="po-conversations" id="po-conversations"></div>
      </aside>
      <section class="po-thread" id="po-thread"><div class="po-thread-empty">${t("Choose a conversation, or start a new one.","选择一段会话，或者给另一位观测员写信。")}</div></section>
    </div>`;
    document.getElementById("po-compose").onclick = renderCompose;
    await loadConversations(true);
  }
  async function loadConversations(openActive) {
    state.conversations = await messaging.listConversations();
    const list = document.getElementById("po-conversations");
    if (!list) return;
    list.innerHTML = state.conversations.map((item, index) => `
      <button class="po-conversation" style="--conversation-index:${index}" type="button" data-id="${esc(item.id)}" aria-selected="${item.id === state.activeId}">
        <strong>${esc(item.kind === "feedback" ? t("Developer · Feedback","开发者 · 反馈") : item.title)}</strong>
        <small>${esc(when(item.last_message_at))}</small>
        <span class="preview">${esc(item.last_message)}</span>
        ${Number(item.unread_count) ? `<span class="po-unread">${Math.min(99, Number(item.unread_count))}</span>` : ""}
      </button>`).join("") || `<p class="po-thread-empty">${t("No messages yet.","还没有消息。")}</p>`;
    list.querySelectorAll("[data-id]").forEach(button => button.onclick = () => openConversation(button.dataset.id));
    setBadge(state.conversations.reduce((sum, item) => sum + Number(item.unread_count || 0), 0));
    if (openActive && state.activeId && state.conversations.some(item => item.id === state.activeId)) {
      await openConversation(state.activeId);
    }
  }

  function renderActiveConversationUpdate(data, error = null) {
    if (error || !data || modal.hidden || state.activeId !== data.conversation.id) return;
    const signature = messaging.conversationSignature(data);
    if (signature === state.activeSignature) return;
    const messages = document.getElementById("po-messages");
    if (!messages) return;
    const wasNearBottom = messages.scrollHeight - messages.scrollTop - messages.clientHeight < 44;
    messages.innerHTML = messaging.renderMessages(data);
    state.activeSignature = signature;
    if (wasNearBottom) messages.scrollTop = messages.scrollHeight;
    messaging.markRead(state.activeId).catch(() => {});
  }

  async function pollOpenInbox() {
    if (modal.hidden || document.hidden) return;
    await messaging.poll(true);
  }
  function renderCompose() {
    state.activeId = null;
    const thread = document.getElementById("po-thread");
    thread.hidden = false;
    thread.classList.add("is-open");
    thread.innerHTML = `<header class="po-thread-head"><button class="po-secondary po-inbox-mobile-back" type="button">←</button>
      <h3>${t("New message","写新消息")}</h3><p>${t("Text only. Enter the exact observer name.","仅支持文字，请输入对方准确的用户名。")}</p></header>
      <form class="po-new-form" id="po-new-message">
        <label class="po-field">${t("Observer name","观测员用户名")}<input name="username" minlength="3" maxlength="24" required autocomplete="off" value="${esc(state.composeUsername)}"></label>
        <label class="po-field">${t("Message","消息")}<textarea name="body" minlength="1" maxlength="4000" required></textarea></label>
        <button class="po-primary" type="submit">${t("Send message","发送消息")}</button>
        <p class="po-inbox-status" role="status"></p>
      </form>`;
    thread.querySelector(".po-inbox-mobile-back").onclick = () => { thread.classList.remove("is-open"); };
    thread.querySelector("form").onsubmit = async event => {
      event.preventDefault();
      const form = new FormData(event.currentTarget);
      const submit = event.currentTarget.querySelector("button[type=submit]");
      const status = event.currentTarget.querySelector(".po-inbox-status");
      submit.disabled = true;
      try {
        const data = await messaging.startDirect(form.get("username"), form.get("body"));
        await loadConversations(false);
        await openConversation(data.conversationId);
      } catch (error) {
        status.textContent = error.message;
      } finally {
        submit.disabled = false;
      }
    };
  }
  async function openConversation(id) {
    state.activeUnsubscribe?.();
    state.activeUnsubscribe = null;
    state.activeId = id;
    const data = await messaging.getConversation(id);
    const peers = (data.members || []).filter(member => member.id !== data.currentUserId).map(member => member.username);
    const title = data.conversation.kind === "feedback"
      ? t("Developer · Feedback","开发者 · 反馈")
      : (peers.join(", ") || t("Conversation","会话"));
    const thread = document.getElementById("po-thread");
    thread.hidden = false;
    thread.classList.add("is-open");
    thread.innerHTML = `<header class="po-thread-head"><button class="po-secondary po-inbox-mobile-back" type="button">←</button>
      <h3>${esc(title)}</h3><p>${data.conversation.feedback_id ? `${t("Feedback receipt","反馈回执")} ${esc(data.conversation.feedback_id)}` : t("Private text conversation","纯文字私信")}</p></header>
      <div class="po-messages" id="po-messages">${messaging.renderMessages(data)}</div>
      <form class="po-reply" id="po-reply"><textarea name="body" maxlength="4000" rows="1" required placeholder="${t("Message","输入消息")}"></textarea>
        <button class="po-send" type="submit" aria-label="${t("Send message","发送消息")}">${t("Send","发送")}</button><p class="po-inbox-status" role="status"></p></form>`;
    thread.querySelector(".po-inbox-mobile-back").onclick = () => { thread.classList.remove("is-open"); };
    const messages = document.getElementById("po-messages");
    state.activeSignature = messaging.conversationSignature(data);
    messages.scrollTop = messages.scrollHeight;
    const replyInput = thread.querySelector(".po-reply textarea");
    const sendButton = thread.querySelector(".po-send");
    bindGlassPointer(sendButton, "--send-glass-x", "--send-glass-y");
    const resizeReply = () => {
      replyInput.style.height = "auto";
      replyInput.style.height = `${Math.min(replyInput.scrollHeight, 124)}px`;
    };
    replyInput.addEventListener("input", resizeReply);
    replyInput.addEventListener("keydown", event => {
      if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
        event.preventDefault();
        event.currentTarget.form.requestSubmit();
      }
    });
    thread.querySelector("form").onsubmit = async event => {
      event.preventDefault();
      const form = new FormData(event.currentTarget);
      const submit = event.currentTarget.querySelector(".po-send");
      submit.classList.remove("is-sent", "is-error");
      submit.classList.add("is-sending");
      submit.disabled = true;
      try {
        await messaging.send(id, form.get("body"));
        submit.classList.remove("is-sending");
        submit.classList.add("is-sent");
        await new Promise(resolve => setTimeout(resolve, 320));
        await openConversation(id);
        await loadConversations(false);
      } catch (error) {
        submit.classList.remove("is-sending");
        submit.classList.add("is-error");
        event.currentTarget.querySelector(".po-inbox-status").textContent = error.message;
        setTimeout(() => submit.classList.remove("is-error"), 420);
      } finally {
        submit.disabled = false;
      }
    };
    await messaging.markRead(id);
    await loadConversations(false);
    state.activeUnsubscribe = messaging.watchConversation(id, renderActiveConversationUpdate);
  }

  modal.querySelector(".po-close").onclick = close;
  dialog.addEventListener("pointermove", event => {
    if (state.glassFrame) cancelAnimationFrame(state.glassFrame);
    state.glassFrame = requestAnimationFrame(() => {
      const bounds = dialog.getBoundingClientRect();
      const x = Math.max(0, Math.min(100, ((event.clientX - bounds.left) / bounds.width) * 100));
      const y = Math.max(0, Math.min(100, ((event.clientY - bounds.top) / bounds.height) * 100));
      dialog.style.setProperty("--glass-x", `${x}%`);
      dialog.style.setProperty("--glass-y", `${y}%`);
    });
  });
  dialog.addEventListener("pointerleave", () => {
    dialog.style.setProperty("--glass-x", "72%");
    dialog.style.setProperty("--glass-y", "14%");
  });
  modal.onclick = event => { if (event.target === modal) close(); };
  document.addEventListener("keydown", event => { if (event.key === "Escape" && !modal.hidden) close(); });
  document.getElementById("inbox-open")?.addEventListener("click", open);
  document.addEventListener("po:open-inbox", event => open(event.detail));
  document.addEventListener("po:session-changed", refreshBadge);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) {
      refreshBadge();
      pollOpenInbox();
    }
  });
  addEventListener("focus", () => {
    refreshBadge();
    pollOpenInbox();
  });
  refreshBadge();
})();
