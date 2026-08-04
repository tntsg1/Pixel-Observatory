(() => {
  "use strict";

  const state = {
    user: null,
    tab: "community",
    activePostId: null,
    closeTimer: 0,
    presenceTimer: 0,
    friendPresenceTimer: 0,
    lastPresencePing: 0,
    pointerFrame: 0,
    friends: new Map(),
    chatFriend: null,
    chatConversationId: "",
    chatUnsubscribe: null,
    chatNearBottom: true,
  };
  const messaging = window.POMessaging;
  const isZh = () => document.documentElement.dataset.lang === "zh";
  const t = (en, zh) => isZh() ? zh : en;
  const esc = value => String(value ?? "").replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]);
  const rankZh = {
    "first-light": "初见星光",
    apprentice: "观测学徒",
    recorder: "星空记录员",
    optician: "光学技师",
    "deep-sky": "深空观测者",
    researcher: "天文台研究员",
    ephemeris: "星历专家",
    chief: "首席观测官",
  };

  document.body.insertAdjacentHTML("beforeend", `
    <section class="social-modal" id="social-modal" hidden role="dialog" aria-modal="true" aria-label="Observer community">
      <div class="social-shell" id="social-shell">
        <header class="social-topbar">
          <div class="social-brand"><small>Observer Network</small><strong>${t("Starlight Community", "星光社区")}</strong></div>
          <nav class="social-tabs" aria-label="Community sections">
            <button class="social-tab" data-social-tab="community" type="button">${t("Community", "社区")}</button>
            <button class="social-tab" data-social-tab="friends" type="button">${t("Friends", "好友")}</button>
            <button class="social-tab" data-social-tab="leaderboard" type="button">${t("Ranking", "排行榜")}</button>
            <button class="social-tab" data-social-tab="profile" type="button">${t("Profile", "个人")}</button>
          </nav>
        </header>
        <button class="social-icon-button social-close" type="button" aria-label="Close">&times;</button>
        <main class="social-main" id="social-main"></main>
        <aside class="friend-chat-drawer" id="friend-chat-drawer" hidden aria-label="Private conversation">
          <div class="friend-chat-content" id="friend-chat-content"></div>
        </aside>
      </div>
    </section>`);

  const modal = document.getElementById("social-modal");
  const shell = document.getElementById("social-shell");
  const main = document.getElementById("social-main");
  const chatDrawer = document.getElementById("friend-chat-drawer");
  const chatContent = document.getElementById("friend-chat-content");

  async function api(path, options = {}) {
    const response = await fetch(path, {
      credentials: "same-origin",
      ...options,
      headers: { "content-type": "application/json", ...(options.headers || {}) },
    });
    const data = await response.json().catch(() => ({ message: t("Unreadable server response.", "服务器返回了无法读取的内容。") }));
    if (!response.ok) throw new Error(data.message || t("Request failed.", "请求失败。"));
    return data;
  }

  function avatarStyle(id) {
    const index = Math.max(0, Math.min(7, Number(id || 1) - 1));
    const column = index % 4;
    const row = Math.floor(index / 4);
    return `--avatar-x:${column * 33.3333}%;--avatar-y:${row * 100}%`;
  }

  function avatar(profile, size = "") {
    const adminClass = profile?.role === "admin" ? " is-admin" : "";
    return `<span class="social-avatar ${size}${adminClass}" style="${avatarStyle(profile?.avatarId)}" role="img" aria-label="${esc(profile?.username || "Observer")}">${profile?.role === "admin" ? '<i class="social-admin-crown" aria-hidden="true">✦</i>' : ""}</span>`;
  }

  function honor(profile) {
    return profile?.role === "admin"
      ? `<span class="social-admin-honor"><i aria-hidden="true">✦</i>${t("Observatory Director", "天文台台长")}<i aria-hidden="true">✦</i></span>`
      : "";
  }

  function rankName(rank) {
    if (!rank) return t("First Light", "初见星光");
    return isZh() ? (rankZh[rank.id] || rank.name) : rank.name;
  }

  function formatDuration(seconds) {
    const value = Math.max(0, Number(seconds) || 0);
    const hours = Math.floor(value / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    if (hours) return isZh() ? `${hours} 小时 ${minutes} 分钟` : `${hours}h ${minutes}m`;
    return isZh() ? `${minutes} 分钟` : `${minutes}m`;
  }

  function formatWhen(timestamp) {
    const value = Number(timestamp) || 0;
    if (!value) return "";
    const date = new Date(value > 10_000_000_000 ? value : value * 1000);
    return new Intl.DateTimeFormat(isZh() ? "zh-CN" : "en", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }).format(date);
  }

  function replyTree(replies) {
    const byParent = new Map();
    const known = new Set(replies.map(reply => reply.id));
    replies.forEach(reply => {
      const parent = reply.parentReplyId && known.has(reply.parentReplyId) ? reply.parentReplyId : "";
      if (!byParent.has(parent)) byParent.set(parent, []);
      byParent.get(parent).push(reply);
    });
    const renderBranch = (parentId = "", depth = 0) => (byParent.get(parentId) || []).map(reply => `
      <div class="community-reply-branch" style="--reply-depth:${Math.min(depth, 4)}">
        <article class="social-card community-reply">
          ${avatar(reply.author, "tiny")}
          <div class="community-reply-copy">
            <div class="community-reply-head">
              <button class="community-author" type="button" data-profile="${esc(reply.author.username)}">${esc(reply.author.username)}${reply.author.role === "admin" ? ` · ${t("Director", "台长")}` : ""} · ${formatWhen(reply.createdAt)}</button>
              ${state.user ? `<button class="community-inline-reply" type="button" data-reply-to="${esc(reply.id)}" data-reply-user="${esc(reply.author.username)}">${t("Reply", "回复")}</button>` : ""}
            </div>
            ${reply.replyToUsername ? `<span class="community-replying-to">${t("Replying to", "回复")} @${esc(reply.replyToUsername)}</span>` : ""}
            <p>${esc(reply.body)}</p>
          </div>
        </article>
        ${renderBranch(reply.id, depth + 1)}
      </div>`).join("");
    return renderBranch();
  }

  function setStatus(element, message, good = false) {
    if (!element) return;
    element.textContent = message;
    element.classList.toggle("good", good);
  }

  function closeFriendChat() {
    state.chatUnsubscribe?.();
    state.chatUnsubscribe = null;
    state.chatFriend = null;
    state.chatConversationId = "";
    state.chatNearBottom = true;
    chatDrawer.classList.remove("is-open");
    shell.classList.remove("has-friend-chat");
    window.setTimeout(() => {
      if (!chatDrawer.classList.contains("is-open")) {
        chatDrawer.hidden = true;
        chatContent.innerHTML = "";
      }
    }, 260);
  }

  function chatHeader(friend) {
    return `<header class="friend-chat-head">
      ${avatar(friend, "small")}
      <div class="friend-chat-identity">
        <strong>${esc(friend.username)}</strong>
        <span class="friend-chat-presence ${friend.online ? "" : "offline"}" data-chat-presence>${friend.online ? t("Online now", "当前在线") : t("Offline", "离线")} · ${esc(rankName(friend.rank))}</span>
      </div>
      <button class="friend-chat-profile" type="button" data-chat-profile="${esc(friend.username)}">${t("Profile", "主页")}</button>
      <button class="friend-chat-close" type="button" aria-label="${t("Close conversation", "关闭对话")}">×</button>
    </header>`;
  }

  function chatComposer() {
    return `<form class="friend-chat-compose" id="friend-chat-compose">
      <textarea name="body" rows="1" maxlength="4000" required placeholder="${t("Write a message", "输入消息")}"></textarea>
      <button class="friend-chat-send" type="submit">${t("Send", "发送")}</button>
      <p class="friend-chat-status" role="status"></p>
    </form>`;
  }

  function renderEmptyFriendConversation(friend, draft = "") {
    chatContent.innerHTML = `${chatHeader(friend)}
      <div class="friend-chat-messages">
        <div class="friend-chat-empty">
          <strong>${t("Start an observing conversation here.", "从这里开始一段观测交流。")}</strong>
          <span>${t("A conversation is created only after you send the first message.", "发送第一条消息后才会建立会话。")}</span>
        </div>
      </div>
      <button class="friend-chat-new" type="button" hidden>${t("New messages", "有新消息")} ↓</button>
      ${chatComposer()}`;
    bindChatChrome(friend);
    const input = chatContent.querySelector("textarea");
    input.value = draft;
    input.focus();
  }

  function bindChatChrome(friend) {
    chatContent.querySelector(".friend-chat-close").onclick = closeFriendChat;
    chatContent.querySelector("[data-chat-profile]").onclick = () => {
      closeFriendChat();
      render("profile", friend.username);
    };
    const messages = chatContent.querySelector(".friend-chat-messages");
    const newMessageButton = chatContent.querySelector(".friend-chat-new");
    if (messages) {
      messages.addEventListener("scroll", () => {
        state.chatNearBottom = messages.scrollHeight - messages.scrollTop - messages.clientHeight < 56;
        if (state.chatNearBottom) newMessageButton.hidden = true;
      }, { passive: true });
      newMessageButton.onclick = () => {
        messages.scrollTop = messages.scrollHeight;
        state.chatNearBottom = true;
        newMessageButton.hidden = true;
      };
    }
    const form = chatContent.querySelector("#friend-chat-compose");
    const input = form.querySelector("textarea");
    input.addEventListener("input", () => {
      input.style.height = "auto";
      input.style.height = `${Math.min(input.scrollHeight, 112)}px`;
    });
    input.addEventListener("keydown", event => {
      if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
        event.preventDefault();
        form.requestSubmit();
      }
    });
    form.onsubmit = async event => {
      event.preventDefault();
      const body = input.value.trim();
      if (!body) return;
      const send = form.querySelector(".friend-chat-send");
      const status = form.querySelector(".friend-chat-status");
      send.disabled = true;
      send.classList.add("is-sending");
      status.textContent = "";
      try {
        if (!state.chatConversationId) {
          const result = await messaging.startDirect(friend.username, body);
          state.chatConversationId = result.conversationId;
          await attachFriendConversation(friend, state.chatConversationId, true);
        } else {
          await messaging.send(state.chatConversationId, body);
          input.value = "";
          input.style.height = "";
          state.chatNearBottom = true;
          await messaging.poll(true);
        }
        input.focus();
      } catch (error) {
        status.textContent = error.message;
        send.classList.add("is-error");
      } finally {
        send.disabled = false;
        send.classList.remove("is-sending");
        window.setTimeout(() => send.classList.remove("is-error"), 420);
      }
    };
  }

  function updateFriendConversation(data, error = null, materialize = false) {
    if (error || !data || data.conversation.id !== state.chatConversationId || !state.chatFriend) return;
    const messages = chatContent.querySelector(".friend-chat-messages");
    if (!messages) return;
    const previousSignature = messages.dataset.signature || "";
    const signature = messaging.conversationSignature(data);
    if (signature === previousSignature) return;
    const wasNearBottom = state.chatNearBottom;
    messages.innerHTML = messaging.renderMessages(data);
    messages.dataset.signature = signature;
    if (materialize) messages.lastElementChild?.classList.add("is-materializing");
    if (wasNearBottom) {
      messages.scrollTop = messages.scrollHeight;
    } else {
      chatContent.querySelector(".friend-chat-new").hidden = false;
    }
    messaging.markRead(state.chatConversationId).catch(() => {});
  }

  async function attachFriendConversation(friend, conversationId, materialize = false) {
    state.chatUnsubscribe?.();
    state.chatUnsubscribe = null;
    state.chatConversationId = conversationId;
    const data = await messaging.getConversation(conversationId);
    chatContent.innerHTML = `${chatHeader(friend)}
      <div class="friend-chat-messages" data-signature="${esc(messaging.conversationSignature(data))}">${messaging.renderMessages(data)}</div>
      <button class="friend-chat-new" type="button" hidden>${t("New messages", "有新消息")} ↓</button>
      ${chatComposer()}`;
    bindChatChrome(friend);
    const messages = chatContent.querySelector(".friend-chat-messages");
    messages.scrollTop = messages.scrollHeight;
    if (materialize) messages.lastElementChild?.classList.add("is-materializing");
    await messaging.markRead(conversationId);
    state.chatUnsubscribe = messaging.watchConversation(conversationId, updateFriendConversation);
  }

  async function openFriendChat(friend, originButton) {
    if (!state.user) {
      document.getElementById("account-open")?.click();
      return;
    }
    state.chatFriend = friend;
    state.chatConversationId = "";
    state.chatNearBottom = true;
    state.chatUnsubscribe?.();
    state.chatUnsubscribe = null;
    const shellBounds = shell.getBoundingClientRect();
    const originBounds = originButton.getBoundingClientRect();
    chatDrawer.style.setProperty("--chat-origin-x", `${originBounds.left + originBounds.width / 2 - shellBounds.left}px`);
    chatDrawer.style.setProperty("--chat-origin-y", `${originBounds.top + originBounds.height / 2 - shellBounds.top}px`);
    chatDrawer.hidden = false;
    shell.classList.add("has-friend-chat");
    chatContent.innerHTML = `${chatHeader(friend)}<div class="friend-chat-loading">${t("Opening the conversation…", "正在打开对话…")}</div>`;
    chatContent.querySelector(".friend-chat-close").onclick = closeFriendChat;
    chatContent.querySelector("[data-chat-profile]").onclick = () => {
      closeFriendChat();
      render("profile", friend.username);
    };
    requestAnimationFrame(() => chatDrawer.classList.add("is-open"));
    try {
      const conversations = await messaging.listConversations();
      const existing = messaging.findDirectConversation(friend.username, conversations);
      if (existing) {
        await attachFriendConversation(friend, existing.id);
      } else {
        renderEmptyFriendConversation(friend);
      }
    } catch (error) {
      chatContent.innerHTML = `${chatHeader(friend)}<div class="friend-chat-empty"><strong>${t("Conversation unavailable", "暂时无法打开对话")}</strong><span>${esc(error.message)}</span></div>`;
      chatContent.querySelector(".friend-chat-close").onclick = closeFriendChat;
      chatContent.querySelector("[data-chat-profile]").onclick = () => render("profile", friend.username);
    }
  }

  async function session() {
    const data = await api("/api/auth/session");
    state.user = data.user;
    return state.user;
  }

  function pingPresence() {
    if (!state.user || document.hidden) return;
    const now = Date.now();
    if (now - state.lastPresencePing < 5000) return;
    state.lastPresencePing = now;
    api("/api/social/presence", { method: "POST", body: "{}" }).catch(() => {});
  }

  function startPresence() {
    if (!state.user) return;
    pingPresence();
    if (state.presenceTimer) return;
    // Presence is a property of the signed-in observatory, not of the social
    // modal. A short, visibility-aware heartbeat keeps separate tabs honest
    // without burning through the worker's per-user rate limit.
    state.presenceTimer = setInterval(pingPresence, 25_000);
  }

  function stopPresence() {
    clearInterval(state.presenceTimer);
    state.presenceTimer = 0;
  }

  async function restorePresence() {
    try {
      await session();
      pingPresence();
      startPresence();
    } catch (_) {
      state.user = null;
      stopPresence();
    }
  }

  function authGate(section) {
    main.innerHTML = `<div class="social-card social-auth-gate"><div>
      <div class="social-title">${t("Observer identity required", "需要观测者身份")}</div>
      <h2>${t(`Sign in to open ${section}.`, `登录后即可打开${section}。`)}</h2>
      <p>${t("Your profile, friends, rank and community history stay with your cloud account.", "你的个人资料、好友、段位和社区记录都会跟随云端账号保存。")}</p>
      <button class="social-button primary" id="social-sign-in" type="button">${t("Open account", "打开账号")}</button>
    </div></div>`;
    document.getElementById("social-sign-in").onclick = () => {
      close();
      document.getElementById("account-open")?.click();
    };
  }

  function loading() {
    main.innerHTML = `<div class="social-loading">${t("Opening the observer network…", "正在连接观测者网络…")}</div>`;
  }

  function updateTabs() {
    modal.querySelectorAll("[data-social-tab]").forEach(button => {
      button.setAttribute("aria-selected", String(button.dataset.socialTab === state.tab));
    });
  }

  function refreshChrome() {
    const labels = {
      community: t("Community", "社区"),
      friends: t("Friends", "好友"),
      leaderboard: t("Ranking", "排行榜"),
      profile: t("Profile", "个人"),
    };
    modal.querySelector(".social-brand strong").textContent = t("Starlight Community", "星光社区");
    modal.querySelectorAll("[data-social-tab]").forEach(button => {
      button.textContent = labels[button.dataset.socialTab];
    });
    modal.querySelector(".social-close").setAttribute("aria-label", t("Close", "关闭"));
    modal.setAttribute("aria-label", t("Observer community", "观测者社区"));
    chatDrawer.setAttribute("aria-label", t("Private conversation", "私信对话"));
  }

  async function render(tab = state.tab, detail = null) {
    if (tab !== "friends") closeFriendChat();
    clearInterval(state.friendPresenceTimer);
    state.friendPresenceTimer = 0;
    state.tab = tab;
    updateTabs();
    loading();
    try {
      if (!state.user) await session();
      startPresence();
      if (tab === "community") await renderCommunity();
      else if (tab === "profile") await renderProfile(detail);
      else if (tab === "friends") await renderFriends();
      else if (tab === "leaderboard") await renderLeaderboard();
    } catch (error) {
      main.innerHTML = `<div class="social-empty"><strong>${t("The network could not open.", "暂时无法打开观测者网络。")}</strong><span>${esc(error.message)}</span></div>`;
    }
  }

  function open(tab = "community", detail = null) {
    clearTimeout(state.closeTimer);
    refreshChrome();
    modal.hidden = false;
    requestAnimationFrame(() => modal.classList.add("is-open"));
    document.body.style.overflow = "hidden";
    render(tab, detail);
    startPresence();
  }

  function close() {
    closeFriendChat();
    clearInterval(state.friendPresenceTimer);
    state.friendPresenceTimer = 0;
    modal.classList.remove("is-open");
    state.closeTimer = setTimeout(() => {
      modal.hidden = true;
      document.body.style.overflow = "";
    }, 300);
  }

  async function renderProfile(username = "") {
    if (!state.user && !username) return authGate(t("your profile", "个人主页"));
    const query = username ? `?username=${encodeURIComponent(username)}` : "";
    const data = await api(`/api/social/profile${query}`);
    const profile = data.profile;
    const percent = Math.round((profile.rank?.progress || 0) * 100);
    const identity = `<section class="social-card social-profile-identity theme-${esc(profile.profileTheme || "standard")} ${profile.role === "admin" ? "is-admin-profile" : ""}">
      ${avatar(profile, "large")}
      <h2 class="social-profile-name">${esc(profile.username)}</h2>
      ${honor(profile)}
      <div class="social-title">${esc(rankName(profile.rank))}</div>
      <div class="social-online ${profile.online ? "" : "offline"}">${profile.online ? t("Online now", "当前在线") : t("Offline", "离线")}</div>
      <div class="social-card social-rank-card">
        <div class="social-rank-row"><span class="social-rank-name">${esc(rankName(profile.rank))}</span><span class="social-rank-level">RANK ${profile.rank.level}/8</span></div>
        <div class="social-progress"><span style="width:${percent}%"></span></div>
        <div class="social-time">${t("Effective play time", "有效游玩时间")} · ${formatDuration(profile.playSeconds)}</div>
      </div>
    </section>`;

    if (!profile.isSelf) {
      main.innerHTML = `<div class="social-profile-grid">${identity}<section class="social-card social-profile-details">
        <div class="social-title">${t("Observer record", "观测者档案")}</div>
        <h2 class="social-section-title">${t("Personal introduction", "个人介绍")}</h2>
        <p class="social-bio">${esc(profile.bio || t("This observer has not written an introduction yet.", "这位观测者还没有填写个人介绍。"))}</p>
        <div class="social-actions" style="margin-top:24px">
          ${profile.friendship === "accepted"
            ? `<button class="social-button success" type="button" disabled>${t("Friends", "已是好友")}</button>`
            : `<button class="social-button primary" id="profile-add-friend" type="button">${t("Add friend", "添加好友")}</button>`}
          <button class="social-button" id="profile-back-community" type="button">${t("Back to community", "返回社区")}</button>
        </div>
        ${state.user?.role === "admin" && profile.role !== "admin" ? `
          <section class="social-moderation-panel">
            <div class="social-title">${t("Director controls", "台长管理权限")}</div>
            <h3>${profile.moderation?.muted ? t("Community voice paused", "当前处于禁言状态") : t("Community voice active", "当前可以正常发言")}</h3>
            <p>${profile.moderation?.muted
              ? `${t("Until", "截止")} ${formatWhen(profile.moderation.mutedUntil)}${profile.moderation.reason ? ` · ${esc(profile.moderation.reason)}` : ""}`
              : t("Posts, replies and private messages are available.", "帖子、回复和私信功能均可正常使用。")}</p>
            <label class="social-field">${t("Duration", "禁言时长")}<select id="moderation-duration">
              <option value="3600">${t("1 hour", "1 小时")}</option>
              <option value="86400">${t("24 hours", "24 小时")}</option>
              <option value="604800">${t("7 days", "7 天")}</option>
              <option value="-1">${t("Permanent", "永久")}</option>
            </select></label>
            <label class="social-field">${t("Reason", "原因")}<input id="moderation-reason" maxlength="500" placeholder="${t("A clear reason visible to the observer", "填写玩家可以看到的明确原因")}"></label>
            <div class="social-actions">
              <button class="social-button danger" id="moderation-mute" type="button">${t("Mute observer", "执行禁言")}</button>
              ${profile.moderation?.muted ? `<button class="social-button success" id="moderation-unmute" type="button">${t("Restore voice", "解除禁言")}</button>` : ""}
            </div>
            <p class="social-status" id="moderation-status"></p>
          </section>` : ""}
        <p class="social-status" id="profile-status"></p>
      </section></div>`;
      document.getElementById("profile-back-community").onclick = () => render("community");
      const add = document.getElementById("profile-add-friend");
      if (add) add.onclick = async () => {
        add.disabled = true;
        try {
          await api("/api/social/friends", { method: "POST", body: JSON.stringify({ username: profile.username }) });
          add.textContent = t("Request sent", "好友申请已发送");
          setStatus(document.getElementById("profile-status"), t("A friend request is on its way.", "好友申请已经送达。"), true);
        } catch (error) {
          setStatus(document.getElementById("profile-status"), error.message);
          add.disabled = false;
        }
      };
      const moderate = async action => {
        const status = document.getElementById("moderation-status");
        const muteButton = document.getElementById("moderation-mute");
        const unmuteButton = document.getElementById("moderation-unmute");
        if (muteButton) muteButton.disabled = true;
        if (unmuteButton) unmuteButton.disabled = true;
        try {
          const payload = action === "mute"
            ? {
                action,
                durationSeconds: Number(document.getElementById("moderation-duration").value),
                reason: document.getElementById("moderation-reason").value,
              }
            : { action };
          await api(`/api/admin/users/${encodeURIComponent(profile.id)}/moderation`, {
            method: "PATCH",
            body: JSON.stringify(payload),
          });
          setStatus(status, action === "mute"
            ? t("Voice paused. The action was written to the moderation log.", "禁言已生效，操作也已写入审计记录。")
            : t("Community voice restored.", "该玩家已经恢复发言权限。"), true);
          setTimeout(() => renderProfile(profile.username), 650);
        } catch (error) {
          setStatus(status, error.message);
          if (muteButton) muteButton.disabled = false;
          if (unmuteButton) unmuteButton.disabled = false;
        }
      };
      document.getElementById("moderation-mute")?.addEventListener("click", () => moderate("mute"));
      document.getElementById("moderation-unmute")?.addEventListener("click", () => moderate("unmute"));
      return;
    }

    const avatarChoices = Array.from({ length: 8 }, (_, index) => {
      const id = index + 1;
      return `<button class="social-avatar-choice" type="button" data-avatar="${id}" role="radio" aria-checked="${id === profile.avatarId}">
        ${avatar({ avatarId: id, username: `${t("Avatar", "头像")} ${id}` })}
      </button>`;
    }).join("");
    const titleOptions = data.ranks.slice(0, profile.rank.level).map(rank =>
      `<option value="${rank.id}" ${rank.id === profile.selectedTitle ? "selected" : ""}>${esc(isZh() ? (rankZh[rank.id] || rank.name) : rank.name)}</option>`
    ).join("");
    const adminThemes = profile.role === "admin" ? `<div class="social-field">${t("Director skin", "台长专属皮肤")}
      <div class="social-theme-picker" role="radiogroup">
        ${[
          ["command-gold", t("Command Gold", "指挥金")],
          ["aurora-glass", t("Aurora Glass", "极光玻璃")],
          ["deep-space", t("Deep Space", "深空")],
        ].map(([id, label]) => `<button class="social-theme-choice theme-${id}" type="button" data-theme="${id}" role="radio" aria-checked="${profile.profileTheme === id}"><i></i><span>${label}</span></button>`).join("")}
      </div>
      <small class="social-admin-note">${t("Reserved for the Observatory Director. Your portrait, profile and community signature receive the selected ceremonial material.", "仅限天文台台长使用。头像、个人主页与社区署名会采用所选荣誉材质。")}</small>
    </div>` : "";

    main.innerHTML = `<div class="social-profile-grid">${identity}<section class="social-card social-profile-details">
      <div class="social-title">${t("Your observatory identity", "你的天文台身份")}</div>
      <h2 class="social-section-title">${t("Shape your observer profile", "完善你的观测者档案")}</h2>
      <p class="social-section-copy">${t("Choose from the observatory's fixed portrait collection. No image upload or storage is required.", "从天文台内置头像中选择，不需要上传或占用个人图片空间。")}</p>
      <form id="social-profile-form">
        <label class="social-field">${t("Personal introduction", "个人介绍")}
          <textarea name="bio" maxlength="240" rows="4" placeholder="${t("What do you enjoy observing?", "你最喜欢观测什么？")}">${esc(profile.bio)}</textarea>
        </label>
        <div class="social-field">${t("Observatory portrait", "天文台头像")}<div class="social-avatar-picker" role="radiogroup">${avatarChoices}</div></div>
        <label class="social-field">${t("Displayed title", "展示称号")}<select name="title">${titleOptions}</select></label>
        ${adminThemes}
        <div class="social-actions"><button class="social-button primary" type="submit">${t("Save profile", "保存个人主页")}</button></div>
        <p class="social-status" id="social-profile-status"></p>
      </form>
    </section></div>`;
    let chosenAvatar = profile.avatarId;
    let chosenTheme = profile.profileTheme || "standard";
    main.querySelectorAll("[data-avatar]").forEach(button => button.onclick = () => {
      chosenAvatar = Number(button.dataset.avatar);
      main.querySelectorAll("[data-avatar]").forEach(item => item.setAttribute("aria-checked", String(item === button)));
    });
    main.querySelectorAll("[data-theme]").forEach(button => button.onclick = () => {
      chosenTheme = button.dataset.theme;
      main.querySelectorAll("[data-theme]").forEach(item => item.setAttribute("aria-checked", String(item === button)));
    });
    document.getElementById("social-profile-form").onsubmit = async event => {
      event.preventDefault();
      const form = new FormData(event.currentTarget);
      const submit = event.currentTarget.querySelector('[type="submit"]');
      const status = document.getElementById("social-profile-status");
      submit.disabled = true;
      try {
        await api("/api/social/profile", {
          method: "PATCH",
          body: JSON.stringify({ bio: form.get("bio"), avatarId: chosenAvatar, selectedTitle: form.get("title"), profileTheme: chosenTheme }),
        });
        setStatus(status, t("Profile saved. Your observer identity is now live.", "个人主页已保存，你的观测者身份已经更新。"), true);
        setTimeout(() => renderProfile(), 500);
      } catch (error) {
        setStatus(status, error.message);
        submit.disabled = false;
      }
    };
  }

  function friendRow(item, actions = "") {
    return `<article class="social-card friend-row" data-friend-user="${esc(item.username)}">
      ${avatar(item, "small")}
      <div><div class="friend-name">${esc(item.username)}</div>
      <div class="friend-meta" data-friend-presence>${item.online ? t("Online", "在线") : t("Offline", "离线")} · ${esc(rankName(item.rank))}</div></div>
      <div class="friend-actions">${actions}</div>
    </article>`;
  }

  async function renderFriendsLegacy() {
    if (!state.user) return authGate(t("your friends", "好友页面"));
    const data = await api("/api/social/friends");
    const buttons = (item, kind) => {
      if (kind === "incoming") return `<button class="social-button success" data-friend-action="accept" data-id="${esc(item.friendshipId)}">${t("Accept", "接受")}</button><button class="social-button danger" data-friend-action="decline" data-id="${esc(item.friendshipId)}">${t("Decline", "忽略")}</button>`;
      if (kind === "friends") return `<button class="social-button" data-profile="${esc(item.username)}">${t("Profile", "主页")}</button><button class="social-button danger" data-friend-remove="${esc(item.friendshipId)}">${t("Remove", "删除")}</button>`;
      return `<button class="social-button" disabled>${t("Pending", "等待接受")}</button>`;
    };
    const list = (items, kind) => items.length
      ? items.map(item => friendRow(item, buttons(item, kind))).join("")
      : `<div class="social-empty" style="min-height:110px">${kind === "friends" ? t("No friends here yet.", "这里还没有好友。") : t("Nothing waiting.", "目前没有待处理内容。")}</div>`;
    main.innerHTML = `<form class="friends-toolbar" id="friend-add-form">
      <label class="social-field" style="margin:0"><span class="sr-only">${t("Observer name", "观测者用户名")}</span><input name="username" required minlength="3" maxlength="24" placeholder="${t("Enter an observer name", "输入观测者用户名")}"></label>
      <button class="social-button primary" type="submit">${t("Add friend", "添加好友")}</button>
    </form><p class="social-status" id="friend-status"></p>
    <section class="friends-section"><div class="friends-heading"><h3>${t("Online and accepted", "我的好友")}</h3><span class="friends-count">${data.friends.length}</span></div><div class="friend-list">${list(data.friends, "friends")}</div></section>
    <section class="friends-section"><div class="friends-heading"><h3>${t("Requests for you", "收到的申请")}</h3><span class="friends-count">${data.incoming.length}</span></div><div class="friend-list">${list(data.incoming, "incoming")}</div></section>
    <section class="friends-section"><div class="friends-heading"><h3>${t("Requests sent", "已发送申请")}</h3><span class="friends-count">${data.outgoing.length}</span></div><div class="friend-list">${list(data.outgoing, "outgoing")}</div></section>`;

    document.getElementById("friend-add-form").onsubmit = async event => {
      event.preventDefault();
      const form = new FormData(event.currentTarget);
      const status = document.getElementById("friend-status");
      try {
        const result = await api("/api/social/friends", { method: "POST", body: JSON.stringify({ username: form.get("username") }) });
        setStatus(status, t(`Request sent to ${result.username}.`, `已向 ${result.username} 发送好友申请。`), true);
        event.currentTarget.reset();
        setTimeout(renderFriends, 450);
      } catch (error) { setStatus(status, error.message); }
    };
    main.querySelectorAll("[data-profile]").forEach(button => button.onclick = () => render("profile", button.dataset.profile));
    main.querySelectorAll("[data-friend-action]").forEach(button => button.onclick = async () => {
      button.disabled = true;
      try {
        await api(`/api/social/friends/${encodeURIComponent(button.dataset.id)}`, {
          method: "PATCH",
          body: JSON.stringify({ action: button.dataset.friendAction }),
        });
        await renderFriends();
      } catch (error) {
        button.disabled = false;
        setStatus(document.getElementById("friend-status"), error.message);
      }
    });
    main.querySelectorAll("[data-friend-remove]").forEach(button => button.onclick = async () => {
      button.disabled = true;
      try {
        await api(`/api/social/friends/${encodeURIComponent(button.dataset.friendRemove)}`, { method: "DELETE", body: "{}" });
        await renderFriends();
      } catch (error) {
        button.disabled = false;
        setStatus(document.getElementById("friend-status"), error.message);
      }
    });
  }

  async function renderFriends() {
    if (!state.user) return authGate(t("your friends", "好友页面"));
    const [data, discovery] = await Promise.all([
      api("/api/social/friends"),
      api("/api/social/users?q="),
    ]);
    state.friends = new Map(data.friends.map(item => [String(item.username).toLowerCase(), item]));
    const friendActions = (item, kind) => {
      if (kind === "incoming") return `<button class="social-button success" data-friend-action="accept" data-id="${esc(item.friendshipId)}">${t("Accept", "接受")}</button><button class="social-button danger" data-friend-action="decline" data-id="${esc(item.friendshipId)}">${t("Decline", "忽略")}</button>`;
      if (kind === "friends") return `<button class="social-button primary friend-message-button" data-message-friend="${esc(item.username)}" type="button">${t("Message", "消息")}</button>
        <button class="social-button" data-profile="${esc(item.username)}" type="button">${t("Profile", "主页")}</button>
        <details class="friend-more">
          <summary class="social-icon-button" aria-label="${t("More actions", "更多操作")}">•••</summary>
          <div class="friend-more-menu"><button class="social-button danger" data-friend-remove="${esc(item.friendshipId)}" type="button">${t("Remove friend", "删除好友")}</button></div>
        </details>`;
      return `<button class="social-button" disabled>${t("Sent", "已发送")}</button>`;
    };
    const friendList = (items, kind) => items.length
      ? items.map(item => friendRow(item, friendActions(item, kind))).join("")
      : `<div class="friend-empty">${kind === "friends" ? t("No friends yet. Search above to find your observing partners.", "还没有好友。可以从上方搜索你的观测伙伴。") : t("Nothing waiting.", "目前没有待处理内容。")}</div>`;
    const candidateActions = item => {
      if (item.relationship === "friends") return `<button class="social-button" data-profile="${esc(item.username)}">${t("View profile", "查看主页")}</button>`;
      if (item.relationship === "outgoing") return `<button class="social-button" disabled>${t("Request sent", "申请已发送")}</button>`;
      if (item.relationship === "incoming") return `<button class="social-button success" data-friend-action="accept" data-id="${esc(item.friendshipId)}">${t("Accept", "接受")}</button>`;
      if (item.relationship === "unavailable") return `<button class="social-button" disabled>${t("Unavailable", "暂不可用")}</button>`;
      return `<button class="social-button primary" data-add-observer="${esc(item.username)}">${t("Add", "添加")}</button>`;
    };
    const candidateList = items => items.length
      ? items.map(item => `<article class="observer-result">
          <button class="observer-profile-hit" type="button" data-profile="${esc(item.username)}">
            ${avatar(item, "small")}
            <span><strong>${esc(item.username)}</strong><small>${item.online ? t("Online now", "当前在线") : t("Offline", "离线")} · ${esc(rankName(item.rank))}</small></span>
          </button>
          <div class="observer-result-action">${candidateActions(item)}</div>
        </article>`).join("")
      : `<div class="friend-empty">${t("No matching observers found. Try another name.", "没有找到相关观测者，换一个名字试试。")}</div>`;

    main.innerHTML = `<div class="friends-page">
      <section class="social-card observer-discovery">
        <div class="observer-discovery-copy">
          <span>${t("Observer directory", "观测者名录")}</span>
          <h2>${t("Find your observing partners", "寻找你的观测伙伴")}</h2>
          <p>${t("Search by name, compare portraits and ranks, then choose the right person before sending a request.", "输入名字后会显示相关用户、头像、段位与在线状态，确认是正确的人再发送申请。")}</p>
        </div>
        <label class="observer-search">
          <span aria-hidden="true">⌕</span>
          <input id="observer-search-input" type="search" maxlength="24" autocomplete="off" placeholder="${t("Search observer names", "搜索观测者用户名")}">
          <kbd>${t("LIVE", "实时")}</kbd>
        </label>
        <p class="social-status" id="friend-status"></p>
        <div class="observer-results-head"><strong id="observer-results-title">${t("Suggested observers", "推荐观测者")}</strong><span id="observer-results-count">${discovery.observers.length}</span></div>
        <div class="observer-results" id="observer-results">${candidateList(discovery.observers)}</div>
      </section>
      ${data.incoming.length ? `<section class="friends-section priority"><div class="friends-heading"><h3>${t("Requests for you", "收到的申请")}</h3><span class="friends-count">${data.incoming.length}</span></div><div class="friend-list">${friendList(data.incoming, "incoming")}</div></section>` : ""}
      <section class="friends-section"><div class="friends-heading"><h3>${t("Your observing circle", "我的好友")}</h3><span class="friends-count">${data.friends.length}</span></div><div class="friend-list">${friendList(data.friends, "friends")}</div></section>
      ${data.outgoing.length ? `<details class="friends-sent"><summary>${t("Sent requests", "已发送的申请")} <span>${data.outgoing.length}</span></summary><div class="friend-list">${friendList(data.outgoing, "outgoing")}</div></details>` : ""}
    </div>`;

    const status = document.getElementById("friend-status");
    const results = document.getElementById("observer-results");
    const resultsTitle = document.getElementById("observer-results-title");
    const resultsCount = document.getElementById("observer-results-count");
    const searchInput = document.getElementById("observer-search-input");
    let searchTimer = 0;
    let searchSequence = 0;
    searchInput.addEventListener("input", () => {
      clearTimeout(searchTimer);
      const query = searchInput.value.trim();
      searchTimer = setTimeout(async () => {
        const sequence = ++searchSequence;
        results.classList.add("is-loading");
        try {
          const response = await api(`/api/social/users?q=${encodeURIComponent(query)}`);
          if (sequence !== searchSequence) return;
          resultsTitle.textContent = query ? t("Search results", "搜索结果") : t("Suggested observers", "推荐观测者");
          resultsCount.textContent = response.observers.length;
          results.innerHTML = candidateList(response.observers);
        } catch (error) {
          if (sequence === searchSequence) setStatus(status, error.message);
        } finally {
          if (sequence === searchSequence) results.classList.remove("is-loading");
        }
      }, 240);
    });

    main.onclick = async event => {
      const messageButton = event.target.closest("[data-message-friend]");
      if (messageButton) {
        const friend = state.friends.get(String(messageButton.dataset.messageFriend).toLowerCase());
        if (friend) await openFriendChat(friend, messageButton);
        return;
      }
      const profileButton = event.target.closest("[data-profile]");
      if (profileButton) return render("profile", profileButton.dataset.profile);
      const addButton = event.target.closest("[data-add-observer]");
      if (addButton) {
        addButton.disabled = true;
        try {
          const result = await api("/api/social/friends", { method: "POST", body: JSON.stringify({ username: addButton.dataset.addObserver }) });
          setStatus(status, t(`Request sent to ${result.username}.`, `已向 ${result.username} 发送好友申请。`), true);
          addButton.textContent = t("Request sent", "申请已发送");
          setTimeout(renderFriends, 500);
        } catch (error) {
          addButton.disabled = false;
          setStatus(status, error.message);
        }
        return;
      }
      const actionButton = event.target.closest("[data-friend-action]");
      if (actionButton) {
        actionButton.disabled = true;
        try {
          await api(`/api/social/friends/${encodeURIComponent(actionButton.dataset.id)}`, {
            method: "PATCH",
            body: JSON.stringify({ action: actionButton.dataset.friendAction }),
          });
          await renderFriends();
        } catch (error) {
          actionButton.disabled = false;
          setStatus(status, error.message);
        }
        return;
      }
      const removeButton = event.target.closest("[data-friend-remove]");
      if (removeButton) {
        removeButton.disabled = true;
        try {
          await api(`/api/social/friends/${encodeURIComponent(removeButton.dataset.friendRemove)}`, { method: "DELETE", body: "{}" });
          await renderFriends();
        } catch (error) {
          removeButton.disabled = false;
          setStatus(status, error.message);
        }
      }
    };

    async function refreshFriendPresence() {
      if (state.tab !== "friends" || document.hidden) return;
      try {
        const response = await api("/api/social/friends");
        state.friends = new Map(response.friends.map(item => [String(item.username).toLowerCase(), item]));
        for (const [username, friend] of state.friends) {
          const row = main.querySelector(`[data-friend-user="${CSS.escape(friend.username)}"]`);
          const presence = row?.querySelector("[data-friend-presence]");
          if (presence) presence.textContent = `${friend.online ? t("Online", "在线") : t("Offline", "离线")} · ${rankName(friend.rank)}`;
          if (state.chatFriend && String(state.chatFriend.username).toLowerCase() === username) {
            state.chatFriend = friend;
            const chatPresence = chatContent.querySelector("[data-chat-presence]");
            if (chatPresence) {
              chatPresence.classList.toggle("offline", !friend.online);
              chatPresence.textContent = `${friend.online ? t("Online now", "当前在线") : t("Offline", "离线")} · ${rankName(friend.rank)}`;
            }
          }
        }
      } catch (_) {
        // Keep the last server-backed presence state during a transient outage.
      }
    }
    state.friendPresenceTimer = window.setInterval(refreshFriendPresence, 5000);
  }

  async function renderLeaderboard() {
    const data = await api("/api/social/leaderboard");
    if (!data.entries.length) {
      main.innerHTML = `<div class="social-empty">${t("The first observing session will begin the ranking.", "完成第一次观测后，排行榜就会在这里出现。")}</div>`;
      return;
    }
    const leaderSeconds = Math.max(1, ...data.entries.map(entry => Math.max(0, Number(entry.playSeconds) || 0)));
    const leaderboardShare = entry => {
      const seconds = Math.max(0, Number(entry.playSeconds) || 0);
      return seconds > 0 ? Math.max(2, Math.min(100, Math.round((seconds / leaderSeconds) * 100))) : 0;
    };
    const leaderboardLabel = entry => isZh()
      ? `有效时长 ${formatDuration(entry.playSeconds)}；榜首 ${formatDuration(leaderSeconds)}`
      : `${formatDuration(entry.playSeconds)} effective time; leader ${formatDuration(leaderSeconds)}`;
    main.innerHTML = `<section class="social-card leaderboard">${data.entries.map(entry => `
      <button class="leader-row ${entry.isSelf ? "is-self" : ""}" type="button" data-profile="${esc(entry.username)}">
        <span class="leader-position">#${entry.position}</span>${avatar(entry, "small")}
        <span><span class="leader-name">${esc(entry.username)}${entry.role === "admin" ? ` <b class="leader-admin-mark">${t("DIRECTOR", "台长")}</b>` : ""}</span><br><span class="leader-rank">${esc(rankName(entry.rank))}${entry.online ? ` · ${t("Online", "在线")}` : ""}</span></span>
        <span class="social-progress" aria-label="${esc(leaderboardLabel(entry))}" title="${esc(leaderboardLabel(entry))}"><span style="width:${leaderboardShare(entry)}%"></span></span>
        <span class="leader-time">${formatDuration(entry.playSeconds)}</span>
      </button>`).join("")}</section>`;
    main.querySelectorAll("[data-profile]").forEach(button => button.onclick = () => render("profile", button.dataset.profile));
  }

  async function renderCommunity() {
    const data = await api("/api/community/posts");
    const posts = data.posts || [];
    main.innerHTML = `<div class="community-layout">
      <section class="social-card community-feed">
        <header class="community-feed-head"><h2>${t("Field notes", "观测广场")}</h2><button class="social-button primary" id="community-new" type="button">${t("New post", "发布帖子")}</button></header>
        <div class="community-posts" id="community-posts">${posts.length ? posts.map(post => `
          <button class="community-post" type="button" data-post="${esc(post.id)}">
            ${avatar(post.author, "small")}<span><h3>${esc(post.title)}</h3><p>${esc(post.body)}</p>
            <span class="community-post-meta">${esc(post.author.username)}${post.author.role === "admin" ? ` · ${t("Observatory Director", "天文台台长")}` : ""} · ${post.replyCount} ${t("replies", "条回复")} · ${formatWhen(post.updatedAt)}</span></span>
          </button>`).join("") : `<div class="social-empty" style="min-height:260px">${t("The community is quiet. Leave the first observing note.", "社区里很安静，来写下第一篇观测记录吧。")}</div>`}</div>
      </section>
      <section class="social-card community-thread" id="community-thread">
        <div class="social-empty">${t("Choose a post to join the conversation.", "选择一篇帖子，加入这场文字交流。")}</div>
      </section>
    </div>`;
    document.getElementById("community-new").onclick = renderComposer;
    main.querySelectorAll("[data-post]").forEach(button => button.onclick = () => openPost(button.dataset.post));
    if (posts.length) await openPost(state.activePostId && posts.some(post => post.id === state.activePostId) ? state.activePostId : posts[0].id);
  }

  function renderComposer() {
    const thread = document.getElementById("community-thread");
    if (!state.user) {
      thread.innerHTML = `<div class="social-auth-gate"><div><h2>${t("Sign in to publish.", "登录后即可发布帖子。")}</h2><p>${t("Community posts are text-only and stay connected to your observer profile.", "社区仅支持纯文字，帖子会显示你的观测者身份。")}</p><button class="social-button primary" id="compose-sign-in">${t("Open account", "打开账号")}</button></div></div>`;
      document.getElementById("compose-sign-in").onclick = () => { close(); document.getElementById("account-open")?.click(); };
      return;
    }
    thread.innerHTML = `<form class="community-compose" id="community-compose-form">
      <div class="social-title">${t("New field note", "新的观测帖子")}</div>
      <h2 class="social-section-title">${t("Share something worth looking at twice.", "分享一件值得再看一眼的事。")}</h2>
      <label class="social-field">${t("Title", "标题")}<input name="title" minlength="3" maxlength="90" required></label>
      <label class="social-field">${t("Post", "正文")}<textarea name="body" minlength="2" maxlength="3000" rows="10" required></textarea></label>
      <div class="social-actions"><button class="social-button primary" type="submit">${t("Publish", "发布")}</button><button class="social-button" id="compose-cancel" type="button">${t("Cancel", "取消")}</button></div>
      <p class="social-status" id="compose-status"></p>
    </form>`;
    document.getElementById("compose-cancel").onclick = () => renderCommunity();
    document.getElementById("community-compose-form").onsubmit = async event => {
      event.preventDefault();
      const form = new FormData(event.currentTarget);
      const submit = event.currentTarget.querySelector('[type="submit"]');
      submit.disabled = true;
      try {
        const result = await api("/api/community/posts", {
          method: "POST",
          body: JSON.stringify({ title: form.get("title"), body: form.get("body") }),
        });
        state.activePostId = result.postId;
        await renderCommunity();
      } catch (error) {
        setStatus(document.getElementById("compose-status"), error.message);
        submit.disabled = false;
      }
    };
  }

  async function openPost(id) {
    state.activePostId = id;
    main.querySelectorAll("[data-post]").forEach(button => button.classList.toggle("is-active", button.dataset.post === id));
    const thread = document.getElementById("community-thread");
    thread.innerHTML = `<div class="social-loading">${t("Opening field note…", "正在打开帖子…")}</div>`;
    const data = await api(`/api/community/posts/${encodeURIComponent(id)}`);
    thread.innerHTML = `<div class="community-thread-content">
      <h2 class="community-thread-title">${esc(data.post.title)}</h2>
      <button class="community-author" type="button" data-profile="${esc(data.post.author.username)}">${avatar(data.post.author, "tiny")}<span>${esc(data.post.author.username)} · ${esc(rankName(data.post.author.rank))} · ${formatWhen(data.post.createdAt)}</span></button>
      <div class="community-body">${esc(data.post.body)}</div>
      <div class="community-replies">${data.replies.length ? replyTree(data.replies) : `<div class="social-empty" style="min-height:90px">${t("No replies yet.", "还没有回复。")}</div>`}</div>
      ${state.user ? `<form class="community-reply-form" id="community-reply-form">
        <div class="community-reply-target" id="community-reply-target" hidden><span></span><button type="button" aria-label="${t("Cancel directed reply", "取消定向回复")}">&times;</button></div>
        <textarea name="body" maxlength="2000" required placeholder="${t("Write a reply…", "写下回复…")}"></textarea>
        <button class="social-button primary" type="submit">${t("Reply", "回复")}</button>
      </form><p class="social-status" id="reply-status"></p>` : `<p class="social-section-copy">${t("Sign in to reply.", "登录后即可回复。")}</p>`}
    </div>`;
    thread.querySelectorAll("[data-profile]").forEach(button => button.onclick = () => render("profile", button.dataset.profile));
    const form = document.getElementById("community-reply-form");
    const target = document.getElementById("community-reply-target");
    const textarea = form?.querySelector("textarea");
    const clearTarget = () => {
      if (!form || !target || !textarea) return;
      form.dataset.parentReplyId = "";
      target.hidden = true;
      target.querySelector("span").textContent = "";
      textarea.placeholder = t("Write a reply…", "写下回复…");
    };
    thread.querySelectorAll("[data-reply-to]").forEach(button => button.onclick = () => {
      form.dataset.parentReplyId = button.dataset.replyTo;
      target.hidden = false;
      target.querySelector("span").textContent = `${t("Replying to", "正在回复")} @${button.dataset.replyUser}`;
      textarea.placeholder = t(`Reply to @${button.dataset.replyUser}…`, `回复 @${button.dataset.replyUser}…`);
      textarea.focus({ preventScroll: true });
      form.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
    target?.querySelector("button").addEventListener("click", clearTarget);
    if (form) form.onsubmit = async event => {
      event.preventDefault();
      const values = new FormData(event.currentTarget);
      const submit = event.currentTarget.querySelector('[type="submit"]');
      submit.disabled = true;
      try {
        await api(`/api/community/posts/${encodeURIComponent(id)}/replies`, {
          method: "POST",
          body: JSON.stringify({ body: values.get("body"), parentReplyId: event.currentTarget.dataset.parentReplyId || null }),
        });
        await openPost(id);
      } catch (error) {
        setStatus(document.getElementById("reply-status"), error.message);
        submit.disabled = false;
      }
    };
  }

  modal.querySelectorAll("[data-social-tab]").forEach(button => button.onclick = () => render(button.dataset.socialTab));
  modal.querySelector(".social-close").onclick = close;
  // Community is a full task surface. Only an explicit close control or
  // Escape should dismiss it; backdrop clicks must not eject the visitor.
  shell.addEventListener("pointermove", event => {
    if (state.pointerFrame) return;
    state.pointerFrame = requestAnimationFrame(() => {
      state.pointerFrame = 0;
      const bounds = shell.getBoundingClientRect();
      shell.style.setProperty("--social-pointer-x", `${((event.clientX - bounds.left) / bounds.width) * 100}%`);
      shell.style.setProperty("--social-pointer-y", `${((event.clientY - bounds.top) / bounds.height) * 100}%`);
    });
  });
  document.addEventListener("keydown", event => { if (event.key === "Escape" && !modal.hidden) close(); });
  document.addEventListener("po:session-changed", () => {
    state.user = null;
    stopPresence();
    restorePresence();
    if (!modal.hidden) render(state.tab);
  });
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) restorePresence();
  });
  addEventListener("focus", restorePresence);
  document.addEventListener("po:language-changed", () => {
    refreshChrome();
    if (modal.hidden) return;
    const activeFriend = state.chatFriend;
    const activeConversation = state.chatConversationId;
    const draft = chatContent.querySelector("textarea")?.value || "";
    render(state.tab).then(async () => {
      if (!activeFriend || !chatDrawer.classList.contains("is-open")) return;
      chatDrawer.setAttribute("aria-label", t("Private conversation", "私信对话"));
      if (activeConversation) {
        await attachFriendConversation(activeFriend, activeConversation);
        chatContent.querySelector("textarea").value = draft;
      } else {
        renderEmptyFriendConversation(activeFriend, draft);
      }
    }).catch(() => {});
  });
  document.addEventListener("po:open-social", event => open(event.detail?.tab || "community", event.detail?.username || null));
  document.getElementById("community-open")?.addEventListener("click", () => open("community"));
  document.getElementById("community-hero-open")?.addEventListener("click", () => open("community"));
  document.getElementById("profile-open")?.addEventListener("click", () => open("profile"));
  document.getElementById("friends-open")?.addEventListener("click", () => open("friends"));
  // Start the heartbeat even when a player never opens the social modal.
  restorePresence();
})();
