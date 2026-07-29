(() => {
  "use strict";

  const isZh = () => document.documentElement.dataset.lang === "zh";
  const t = (en, zh) => isZh() ? zh : en;
  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character]);
  const when = value => {
    const timestamp = Number(value);
    if (!timestamp) return "";
    const date = new Date(timestamp > 10_000_000_000 ? timestamp : timestamp * 1000);
    const sameDay = date.toDateString() === new Date().toDateString();
    return new Intl.DateTimeFormat(isZh() ? "zh-CN" : "en", sameDay
      ? { hour: "2-digit", minute: "2-digit" }
      : { month: "short", day: "numeric" }).format(date);
  };

  function createMessagingController(options = {}) {
    const fetchImpl = options.fetch || window.fetch.bind(window);
    const pollInterval = Math.max(800, Number(options.pollInterval) || 2000);
    const listSubscribers = new Set();
    const conversationSubscribers = new Map();
    const conversationSignatures = new Map();
    let timer = 0;
    let polling = false;
    let lastList = [];

    async function request(path, requestOptions = {}) {
      const response = await fetchImpl(path, {
        credentials: "same-origin",
        ...requestOptions,
        headers: {
          "content-type": "application/json",
          ...(requestOptions.headers || {}),
        },
      });
      const data = await response.json().catch(() => ({
        message: t("Unreadable server response.", "服务器返回了无法读取的内容。"),
      }));
      if (!response.ok) {
        const error = new Error(data.message || t("Request failed.", "请求失败。"));
        error.status = response.status;
        error.code = data.error || "";
        throw error;
      }
      return data;
    }

    const conversationSignature = data => (data?.messages || []).map(message =>
      `${message.id || ""}:${message.sender_user_id || ""}:${message.created_at || ""}:${message.body || ""}`,
    ).join("|");

    const listSignature = conversations => (conversations || []).map(item =>
      `${item.id}:${item.updated_at || ""}:${item.unread_count || 0}:${item.last_message_at || ""}`,
    ).join("|");

    async function listConversations() {
      const data = await request("/api/messages/conversations");
      lastList = data.conversations || [];
      return lastList;
    }

    async function getConversation(id) {
      return request(`/api/messages/conversations/${encodeURIComponent(id)}`);
    }

    async function markRead(id) {
      return request(`/api/messages/conversations/${encodeURIComponent(id)}/read`, {
        method: "POST",
        body: "{}",
      });
    }

    async function send(id, body) {
      return request(`/api/messages/conversations/${encodeURIComponent(id)}/messages`, {
        method: "POST",
        body: JSON.stringify({ body }),
      });
    }

    async function startDirect(username, body) {
      return request("/api/messages/conversations", {
        method: "POST",
        body: JSON.stringify({ username, body }),
      });
    }

    function findDirectConversation(username, conversations = lastList) {
      const key = String(username || "").trim().toLowerCase();
      return (conversations || []).find(item =>
        item.kind === "direct" && String(item.peer_username || item.title || "").trim().toLowerCase() === key,
      ) || null;
    }

    function renderMessages(data) {
      return (data?.messages || []).map((message, index) => {
        const mine = message.sender_user_id === data.currentUserId;
        return `<article class="po-message ${mine ? "mine" : ""} ${escapeHtml(message.message_kind)}" style="--message-index:${index}">
          <div class="po-message-meta"><strong>${escapeHtml(message.sender_label)}</strong><time>${escapeHtml(when(message.created_at))}</time></div>
          <div class="po-message-body">${escapeHtml(message.body)}</div>
        </article>`;
      }).join("");
    }

    function hasSubscribers() {
      return listSubscribers.size > 0 || conversationSubscribers.size > 0;
    }

    function maintainTimer() {
      if (!hasSubscribers()) {
        clearInterval(timer);
        timer = 0;
        return;
      }
      if (!timer) timer = window.setInterval(poll, pollInterval);
    }

    async function poll(force = false) {
      if (polling || (!force && document.hidden) || !hasSubscribers()) return;
      polling = true;
      try {
        if (listSubscribers.size) {
          const previous = listSignature(lastList);
          const conversations = await listConversations();
          if (force || listSignature(conversations) !== previous) {
            listSubscribers.forEach(callback => callback(conversations));
          }
        }
        for (const [id, subscribers] of conversationSubscribers) {
          if (!subscribers.size) continue;
          const data = await getConversation(id);
          const signature = conversationSignature(data);
          if (force || signature !== conversationSignatures.get(id)) {
            conversationSignatures.set(id, signature);
            subscribers.forEach(callback => callback(data));
          }
        }
      } catch (error) {
        const callbacks = [
          ...listSubscribers,
          ...[...conversationSubscribers.values()].flatMap(subscribers => [...subscribers]),
        ];
        callbacks.forEach(callback => callback(null, error));
      } finally {
        polling = false;
      }
    }

    function watchConversations(callback) {
      listSubscribers.add(callback);
      maintainTimer();
      listConversations().then(callback).catch(error => callback(null, error));
      return () => {
        listSubscribers.delete(callback);
        maintainTimer();
      };
    }

    function watchConversation(id, callback) {
      if (!conversationSubscribers.has(id)) conversationSubscribers.set(id, new Set());
      conversationSubscribers.get(id).add(callback);
      maintainTimer();
      getConversation(id).then(data => {
        conversationSignatures.set(id, conversationSignature(data));
        callback(data);
      }).catch(error => callback(null, error));
      return () => {
        const subscribers = conversationSubscribers.get(id);
        if (!subscribers) return;
        subscribers.delete(callback);
        if (!subscribers.size) {
          conversationSubscribers.delete(id);
          conversationSignatures.delete(id);
        }
        maintainTimer();
      };
    }

    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) poll(true);
    });
    window.addEventListener("focus", () => poll(true));

    return {
      request,
      listConversations,
      getConversation,
      markRead,
      send,
      startDirect,
      findDirectConversation,
      watchConversations,
      watchConversation,
      poll,
      conversationSignature,
      renderMessages,
      escapeHtml,
      when,
    };
  }

  window.POMessagingFactory = createMessagingController;
  window.POMessaging = createMessagingController();
})();
