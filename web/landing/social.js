(() => {
  "use strict";

  const state = {
    user: null,
    tab: "community",
    activePostId: null,
    closeTimer: 0,
    presenceTimer: 0,
    pointerFrame: 0,
  };
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
      </div>
    </section>`);

  const modal = document.getElementById("social-modal");
  const shell = document.getElementById("social-shell");
  const main = document.getElementById("social-main");

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
    return `<span class="social-avatar ${size}" style="${avatarStyle(profile?.avatarId)}" role="img" aria-label="${esc(profile?.username || "Observer")}"></span>`;
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

  function setStatus(element, message, good = false) {
    if (!element) return;
    element.textContent = message;
    element.classList.toggle("good", good);
  }

  async function session() {
    const data = await api("/api/auth/session");
    state.user = data.user;
    return state.user;
  }

  function startPresence() {
    if (!state.user || state.presenceTimer) return;
    const ping = () => {
      if (!document.hidden) api("/api/social/presence", { method: "POST", body: "{}" }).catch(() => {});
    };
    ping();
    state.presenceTimer = setInterval(ping, 45_000);
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
  }

  async function render(tab = state.tab, detail = null) {
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
    modal.hidden = false;
    requestAnimationFrame(() => modal.classList.add("is-open"));
    document.body.style.overflow = "hidden";
    render(tab, detail);
    startPresence();
  }

  function close() {
    modal.classList.remove("is-open");
    clearInterval(state.presenceTimer);
    state.presenceTimer = 0;
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
    const identity = `<section class="social-card social-profile-identity">
      ${avatar(profile, "large")}
      <h2 class="social-profile-name">${esc(profile.username)}</h2>
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
        </div><p class="social-status" id="profile-status"></p>
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
        <div class="social-actions"><button class="social-button primary" type="submit">${t("Save profile", "保存个人主页")}</button></div>
        <p class="social-status" id="social-profile-status"></p>
      </form>
    </section></div>`;
    let chosenAvatar = profile.avatarId;
    main.querySelectorAll("[data-avatar]").forEach(button => button.onclick = () => {
      chosenAvatar = Number(button.dataset.avatar);
      main.querySelectorAll("[data-avatar]").forEach(item => item.setAttribute("aria-checked", String(item === button)));
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
          body: JSON.stringify({ bio: form.get("bio"), avatarId: chosenAvatar, selectedTitle: form.get("title") }),
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
    return `<article class="social-card friend-row">
      ${avatar(item, "small")}
      <div><div class="friend-name">${esc(item.username)}</div>
      <div class="friend-meta">${item.online ? t("Online", "在线") : t("Offline", "离线")} · ${esc(rankName(item.rank))}</div></div>
      <div class="friend-actions">${actions}</div>
    </article>`;
  }

  async function renderFriends() {
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

  async function renderLeaderboard() {
    const data = await api("/api/social/leaderboard");
    if (!data.entries.length) {
      main.innerHTML = `<div class="social-empty">${t("The first observing session will begin the ranking.", "完成第一次观测后，排行榜就会在这里出现。")}</div>`;
      return;
    }
    main.innerHTML = `<section class="social-card leaderboard">${data.entries.map(entry => `
      <button class="leader-row ${entry.isSelf ? "is-self" : ""}" type="button" data-profile="${esc(entry.username)}">
        <span class="leader-position">#${entry.position}</span>${avatar(entry, "small")}
        <span><span class="leader-name">${esc(entry.username)}</span><br><span class="leader-rank">${esc(rankName(entry.rank))}${entry.online ? ` · ${t("Online", "在线")}` : ""}</span></span>
        <span class="social-progress"><span style="width:${Math.round((entry.rank.progress || 0) * 100)}%"></span></span>
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
            <span class="community-post-meta">${esc(post.author.username)} · ${post.replyCount} ${t("replies", "条回复")} · ${formatWhen(post.updatedAt)}</span></span>
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
      <div class="community-replies">${data.replies.length ? data.replies.map(reply => `
        <article class="social-card community-reply">${avatar(reply.author, "tiny")}<div><button class="community-author" style="margin:0" type="button" data-profile="${esc(reply.author.username)}">${esc(reply.author.username)} · ${formatWhen(reply.createdAt)}</button><p>${esc(reply.body)}</p></div></article>`).join("") : `<div class="social-empty" style="min-height:90px">${t("No replies yet.", "还没有回复。")}</div>`}</div>
      ${state.user ? `<form class="community-reply-form" id="community-reply-form"><textarea name="body" maxlength="2000" required placeholder="${t("Write a reply…", "写下回复…")}"></textarea><button class="social-button primary" type="submit">${t("Reply", "回复")}</button></form><p class="social-status" id="reply-status"></p>` : `<p class="social-section-copy">${t("Sign in to reply.", "登录后即可回复。")}</p>`}
    </div>`;
    thread.querySelectorAll("[data-profile]").forEach(button => button.onclick = () => render("profile", button.dataset.profile));
    const form = document.getElementById("community-reply-form");
    if (form) form.onsubmit = async event => {
      event.preventDefault();
      const values = new FormData(event.currentTarget);
      const submit = event.currentTarget.querySelector("button");
      submit.disabled = true;
      try {
        await api(`/api/community/posts/${encodeURIComponent(id)}/replies`, { method: "POST", body: JSON.stringify({ body: values.get("body") }) });
        await renderCommunity();
      } catch (error) {
        setStatus(document.getElementById("reply-status"), error.message);
        submit.disabled = false;
      }
    };
  }

  modal.querySelectorAll("[data-social-tab]").forEach(button => button.onclick = () => render(button.dataset.socialTab));
  modal.querySelector(".social-close").onclick = close;
  modal.onclick = event => { if (event.target === modal) close(); };
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
    if (!modal.hidden) render(state.tab);
  });
  document.addEventListener("po:language-changed", () => {
    refreshChrome();
    if (!modal.hidden) render(state.tab);
  });
  document.addEventListener("po:open-social", event => open(event.detail?.tab || "community", event.detail?.username || null));
  document.getElementById("community-open")?.addEventListener("click", () => open("community"));
  document.getElementById("community-hero-open")?.addEventListener("click", () => open("community"));
  document.getElementById("profile-open")?.addEventListener("click", () => open("profile"));
  document.getElementById("friends-open")?.addEventListener("click", () => open("friends"));
})();
