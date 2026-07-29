(() => {
  "use strict";

  const overlay = document.getElementById("status");
  const progress = document.getElementById("status-progress");
  const phase = document.getElementById("loader-phase");
  const percent = document.getElementById("loader-percent");
  const orbitalPercent = document.getElementById("loader-orbital-percent");
  const loaded = document.getElementById("loader-loaded");
  const optical = document.getElementById("loader-optical");
  const catalogue = document.getElementById("loader-catalogue");
  const notice = document.getElementById("status-notice");
  const canvas = document.getElementById("loader-stars");
  if (!overlay || !progress || !phase || !percent) return;
  const context = canvas?.getContext("2d");
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

  const phases = [
    {until: .12, label: "Opening observatory archive"},
    {until: .38, label: "Loading instruments and optics"},
    {until: .7, label: "Plotting the stellar catalogue"},
    {until: .92, label: "Calibrating observation systems"},
    {until: 1.01, label: "Bringing the observatory online"},
  ];
  let lastPercent = -1;
  let stars = [];
  let dust = [];
  let constellation = [];
  let pointerFrame = 0;

  function formatBytes(value) {
    const bytes = Number(value) || 0;
    if (bytes < 1024 * 1024) return `${Math.max(0, Math.round(bytes / 1024))} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  function update() {
    if (!overlay.isConnected) return;
    const max = Number(progress.max) || 0;
    const value = Number(progress.value) || 0;
    const ratio = max > 0 ? Math.min(1, Math.max(0, value / max)) : 0;
    const nextPercent = Math.round(ratio * 100);

    if (nextPercent !== lastPercent) {
      lastPercent = nextPercent;
      percent.textContent = `${nextPercent}%`;
      if (orbitalPercent) orbitalPercent.textContent = `${nextPercent}%`;
      phase.textContent = phases.find(item => ratio < item.until)?.label || phases.at(-1).label;
      if (loaded) loaded.textContent = max > 0 ? `${formatBytes(value)} / ${formatBytes(max)}` : "Preparing stream";
      if (optical) optical.textContent = ratio > .43 ? "Optical path verified" : "Awaiting calibration";
      if (catalogue) catalogue.textContent = ratio > .72 ? "Star positions indexed" : "Loading coordinates";
    }
    requestAnimationFrame(update);
  }

  function resizeStars() {
    if (!canvas || !context) return;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    canvas.width = Math.round(innerWidth * ratio);
    canvas.height = Math.round(innerHeight * ratio);
    canvas.style.width = `${innerWidth}px`;
    canvas.style.height = `${innerHeight}px`;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    const count = Math.min(150, Math.max(65, Math.round(innerWidth * innerHeight / 11000)));
    stars = Array.from({length: count}, () => ({
      x: Math.random() * innerWidth,
      y: Math.random() * innerHeight,
      size: Math.random() * 1.15 + .25,
      alpha: Math.random() * .46 + .12,
      pulse: Math.random() * Math.PI * 2,
      speed: Math.random() * .0008 + .00035,
      warmth: Math.random(),
    }));
    const dustCount = Math.min(360, Math.max(120, Math.round(innerWidth * innerHeight / 4200)));
    dust = Array.from({length: dustCount}, () => {
      const x = Math.random() * innerWidth;
      const center = innerHeight * (.18 + .58 * (x / Math.max(innerWidth, 1)));
      return {
        x,
        y: center + (Math.random() - .5) * innerHeight * .32,
        size: Math.random() * .55 + .16,
        alpha: Math.random() * .12 + .018,
      };
    });
    constellation = [
      [.12, .30], [.20, .24], [.29, .34], [.38, .27], [.47, .38],
      [.56, .31], [.66, .40], [.77, .33], [.86, .43],
    ].map(([x, y]) => ({x: x * innerWidth, y: y * innerHeight}));
  }

  function drawStars(now) {
    if (!canvas || !context || !overlay.isConnected) return;
    context.clearRect(0, 0, innerWidth, innerHeight);
    context.lineWidth = .65;
    context.strokeStyle = "rgba(126, 190, 216, .09)";
    context.beginPath();
    constellation.forEach((point, index) => {
      if (index === 0) context.moveTo(point.x, point.y);
      else context.lineTo(point.x, point.y);
    });
    context.stroke();

    for (const mote of dust) {
      context.beginPath();
      context.fillStyle = `rgba(194, 215, 225, ${mote.alpha})`;
      context.arc(mote.x, mote.y, mote.size, 0, Math.PI * 2);
      context.fill();
    }

    for (const star of stars) {
      const alpha = reducedMotion ? star.alpha : star.alpha * (.64 + Math.sin(now * star.speed + star.pulse) * .36);
      const color = star.warmth > .86 ? "239, 202, 142" : star.warmth < .18 ? "151, 216, 240" : "210, 230, 239";
      context.beginPath();
      context.fillStyle = `rgba(${color}, ${Math.max(.04, alpha)})`;
      context.arc(star.x, star.y, star.size, 0, Math.PI * 2);
      context.fill();
    }
    requestAnimationFrame(drawStars);
  }

  if (notice) {
    const syncNotice = () => {
      overlay.classList.toggle("has-notice", notice.style.display === "block");
    };
    new MutationObserver(syncNotice).observe(notice, {attributes: true, attributeFilter: ["style"]});
    syncNotice();
  }

  overlay.addEventListener("pointermove", event => {
    if (pointerFrame || reducedMotion) return;
    pointerFrame = requestAnimationFrame(() => {
      pointerFrame = 0;
      const x = event.clientX / innerWidth;
      const y = event.clientY / innerHeight;
      document.documentElement.style.setProperty("--loader-pointer-x", ((x - .5) * 2).toFixed(3));
      document.documentElement.style.setProperty("--loader-pointer-y", ((y - .5) * 2).toFixed(3));
      document.documentElement.style.setProperty("--loader-glass-x", `${(x * 100).toFixed(1)}%`);
      document.documentElement.style.setProperty("--loader-glass-y", `${(y * 100).toFixed(1)}%`);
    });
  });
  overlay.addEventListener("pointerleave", () => {
    document.documentElement.style.setProperty("--loader-pointer-x", "0");
    document.documentElement.style.setProperty("--loader-pointer-y", "0");
    document.documentElement.style.setProperty("--loader-glass-x", "68%");
    document.documentElement.style.setProperty("--loader-glass-y", "18%");
  });
  addEventListener("resize", resizeStars);
  resizeStars();
  requestAnimationFrame(drawStars);
  requestAnimationFrame(update);
})();

(() => {
  "use strict";
  const rankKey = "pixel-observatory:last-rank-level";
  let audioContext = null;
  let heartbeatTimer = 0;

  addEventListener("pointerdown", () => {
    if (!audioContext) {
      const Context = window.AudioContext || window.webkitAudioContext;
      if (Context) audioContext = new Context();
    }
  }, { once: true, passive: true });

  function playRankSound() {
    if (!audioContext) return;
    const now = audioContext.currentTime;
    const master = audioContext.createGain();
    master.gain.setValueAtTime(.0001, now);
    master.gain.exponentialRampToValueAtTime(.18, now + .035);
    master.gain.exponentialRampToValueAtTime(.0001, now + 2.15);
    master.connect(audioContext.destination);
    [261.63, 329.63, 392, 523.25].forEach((frequency, index) => {
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.type = index === 3 ? "sine" : "triangle";
      oscillator.frequency.setValueAtTime(frequency, now + index * .13);
      oscillator.detune.setValueAtTime(index % 2 ? 4 : -3, now);
      gain.gain.setValueAtTime(.0001, now + index * .13);
      gain.gain.exponentialRampToValueAtTime(.25, now + index * .13 + .025);
      gain.gain.exponentialRampToValueAtTime(.0001, now + index * .13 + 1.35);
      oscillator.connect(gain).connect(master);
      oscillator.start(now + index * .13);
      oscillator.stop(now + index * .13 + 1.5);
    });
  }

  function celebrate(rank) {
    if (document.querySelector(".game-rank-celebration")) return;
    const layer = document.createElement("section");
    layer.className = "game-rank-celebration";
    layer.innerHTML = `
      <i class="game-rank-burst" style="--x:18%;--y:24%;--c:#8ddbf6;--d:0s"></i>
      <i class="game-rank-burst" style="--x:79%;--y:28%;--c:#edc46b;--d:.18s"></i>
      <i class="game-rank-burst" style="--x:28%;--y:73%;--c:#bf9cff;--d:.34s"></i>
      <i class="game-rank-burst" style="--x:72%;--y:76%;--c:#79e4ad;--d:.5s"></i>
      <div class="game-rank-card">
        <small>Observer rank advanced</small>
        <h2>${String(rank.name || "Observer").replace(/[&<>"']/g, "")}</h2>
        <p>Your patience has become experience. The observatory now recognizes a more accomplished observer.</p>
        <button class="game-rank-dismiss" type="button">Continue observing</button>
      </div>`;
    document.body.appendChild(layer);
    playRankSound();
    layer.querySelector("button").onclick = () => layer.remove();
    setTimeout(() => layer.remove(), 9_000);
  }

  async function heartbeat() {
    if (document.hidden) return;
    try {
      const response = await fetch("/api/social/playtime", {
        method: "POST",
        credentials: "same-origin",
        headers: { "content-type": "application/json" },
        body: "{}",
      });
      if (!response.ok) return;
      const data = await response.json();
      dispatchEvent(new CustomEvent("observatory:playtime", { detail: data }));
      const level = Number(data.rank?.level || 0);
      const previous = Number(localStorage.getItem(rankKey) || 0);
      if (previous > 0 && level > previous) celebrate(data.rank);
      if (level > 0) localStorage.setItem(rankKey, String(level));
    } catch (_) {
      // Playtime tracking is intentionally silent when the account service is unavailable.
    }
  }

  function schedule() {
    clearInterval(heartbeatTimer);
    heartbeat();
    heartbeatTimer = setInterval(heartbeat, 30_000);
  }
  addEventListener("visibilitychange", () => { if (!document.hidden) heartbeat(); });
  schedule();
})();

(() => {
  "use strict";

  const zh = /^zh\b/i.test(navigator.language || "");
  const t = (en, cn) => zh ? cn : en;
  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]);
  const state = {
    user: null,
    profile: null,
    friends: [],
    sessionStartedAt: Date.now(),
    totalSeconds: 0,
    refreshTimer: 0,
    clockTimer: 0,
    cooldowns: new Map(),
  };

  document.body.insertAdjacentHTML("beforeend", `
    <section class="game-social-rail game-session-rail" id="game-session-rail" hidden aria-label="${t("Current observing session", "当前观测班次")}">
      <div class="game-glass-panel game-session-panel">
        <div class="game-rail-kicker">${t("MY OBSERVING SHIFT", "我的观测班次")}</div>
        <div class="game-session-identity">
          <span class="game-side-avatar" id="game-self-avatar" aria-hidden="true"></span>
          <div><strong id="game-self-name"></strong><span class="game-live-label"><i></i>${t("Online", "在线")}</span></div>
        </div>
        <div class="game-session-orbit" aria-hidden="true"><i></i><b></b></div>
        <div class="game-session-time" id="game-session-time">00:00:00</div>
        <span class="game-session-caption">${t("THIS SESSION", "本次在线")}</span>
        <div class="game-session-stats">
          <div><span>${t("Total time", "累计时长")}</span><strong id="game-total-time">0h 00m</strong></div>
          <div><span>${t("Observer rank", "观测段位")}</span><strong id="game-rank-name">First Light</strong></div>
        </div>
      </div>
    </section>
    <aside class="game-social-rail game-friends-rail" id="game-friends-rail" hidden aria-label="${t("Friends at the observatory", "天文台好友")}">
      <div class="game-glass-panel game-friends-panel">
        <header class="game-friends-head">
          <div><span>${t("OBSERVATORY LINKS", "天文台连接")}</span><strong>${t("Friends nearby", "附近好友")}</strong></div>
          <i class="game-friends-pulse" aria-hidden="true"></i>
        </header>
        <div class="game-online-pets" id="game-online-pets"></div>
        <div class="game-offline-block">
          <button class="game-offline-toggle" id="game-offline-toggle" type="button" aria-expanded="false">
            <span>${t("Offline friends", "离线好友")}</span><b id="game-offline-count">0</b><i aria-hidden="true"></i>
          </button>
          <div class="game-offline-list" id="game-offline-list" hidden></div>
        </div>
        <p class="game-signal-status" id="game-signal-status" aria-live="polite"></p>
      </div>
    </aside>
    <div class="game-friend-toast" id="game-friend-toast" hidden role="status" aria-live="polite"></div>`);

  const sessionRail = document.getElementById("game-session-rail");
  const friendsRail = document.getElementById("game-friends-rail");
  const onlinePets = document.getElementById("game-online-pets");
  const offlineList = document.getElementById("game-offline-list");
  const offlineToggle = document.getElementById("game-offline-toggle");
  const signalStatus = document.getElementById("game-signal-status");
  const toast = document.getElementById("game-friend-toast");
  let toastTimer = 0;

  function avatarStyle(id) {
    const index = Math.max(0, Math.min(7, Number(id || 1) - 1));
    return `--avatar-x:${(index % 4) * 33.3333}%;--avatar-y:${Math.floor(index / 4) * 100}%`;
  }

  async function api(path, options = {}) {
    const response = await fetch(path, {
      credentials: "same-origin",
      ...options,
      headers: { "content-type": "application/json", ...(options.headers || {}) },
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message || t("The signal could not be sent.", "信号发送失败。"));
    return data;
  }

  function formatClock(seconds) {
    const value = Math.max(0, Math.floor(Number(seconds) || 0));
    const hours = String(Math.floor(value / 3600)).padStart(2, "0");
    const minutes = String(Math.floor((value % 3600) / 60)).padStart(2, "0");
    const secs = String(value % 60).padStart(2, "0");
    return `${hours}:${minutes}:${secs}`;
  }

  function formatTotal(seconds) {
    const value = Math.max(0, Math.floor(Number(seconds) || 0));
    return `${Math.floor(value / 3600)}h ${String(Math.floor((value % 3600) / 60)).padStart(2, "0")}m`;
  }

  function tickClock() {
    const elapsed = Math.floor((Date.now() - state.sessionStartedAt) / 1000);
    document.getElementById("game-session-time").textContent = formatClock(elapsed);
  }

  function renderSelf() {
    if (!state.profile) return;
    document.getElementById("game-self-name").textContent = state.profile.username;
    document.getElementById("game-self-avatar").style.cssText = avatarStyle(state.profile.avatarId);
    document.getElementById("game-total-time").textContent = formatTotal(state.totalSeconds);
    document.getElementById("game-rank-name").textContent = state.profile.rank?.name || "First Light";
  }

  function petMarkup(friend) {
    const name = escapeHtml(friend.username);
    return `<article class="game-friend-pet" data-friend="${name}">
      <div class="game-pet-stage">
        <span class="game-pet-avatar" style="${avatarStyle(friend.avatarId)}" role="img" aria-label="${name}"></span>
        <i class="game-pet-shadow" aria-hidden="true"></i>
        <span class="game-pet-online" aria-label="${t("Online", "在线")}"></span>
      </div>
      <div class="game-pet-copy"><strong>${name}</strong><span>${escapeHtml(friend.rank?.name || t("Observer", "观测员"))}</span></div>
      <button class="game-signal-button" type="button" data-signal="poke" data-username="${name}">${t("Poke", "戳一下")}</button>
    </article>`;
  }

  function offlineMarkup(friend) {
    const name = escapeHtml(friend.username);
    return `<article class="game-offline-friend">
      <span class="game-mini-avatar" style="${avatarStyle(friend.avatarId)}" aria-hidden="true"></span>
      <div><strong>${name}</strong><span>${t("Away from observatory", "暂离天文台")}</span></div>
      <button class="game-nudge-button" type="button" data-signal="come_online" data-username="${name}">${t("Nudge", "催上线")}</button>
    </article>`;
  }

  function renderFriends() {
    const online = state.friends.filter(friend => friend.online);
    const offline = state.friends.filter(friend => !friend.online);
    onlinePets.innerHTML = online.length
      ? online.map(petMarkup).join("")
      : `<div class="game-no-friends"><i aria-hidden="true"></i><span>${t("The observatory is quiet.", "天文台现在很安静。")}</span></div>`;
    offlineList.innerHTML = offline.length
      ? offline.map(offlineMarkup).join("")
      : `<p class="game-empty-offline">${t("Everyone is already here.", "所有好友都已经在线。")}</p>`;
    document.getElementById("game-offline-count").textContent = String(offline.length);
  }

  function showToast(signal) {
    const name = escapeHtml(signal.sender?.username || t("A friend", "一位好友"));
    const message = signal.kind === "come_online"
      ? t(`${name} is waiting for you at the observatory.`, `${name} 正在天文台等你上线。`)
      : t(`${name} tapped on your observatory window.`, `${name} 戳了戳你的天文台舷窗。`);
    toast.innerHTML = `<span class="game-toast-avatar" style="${avatarStyle(signal.sender?.avatarId)}"></span><p>${message}</p>`;
    toast.hidden = false;
    requestAnimationFrame(() => toast.classList.add("is-visible"));
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toast.classList.remove("is-visible");
      setTimeout(() => { toast.hidden = true; }, 350);
    }, 5200);
  }

  async function receiveSignals() {
    const data = await api("/api/social/signals");
    for (const signal of data.signals || []) {
      showToast(signal);
      await api(`/api/social/signals/${encodeURIComponent(signal.id)}`, {
        method: "PATCH",
        body: "{}",
      }).catch(() => {});
    }
  }

  async function refreshFriends() {
    const data = await api("/api/social/friends");
    state.friends = data.friends || [];
    renderFriends();
    await receiveSignals();
  }

  async function sendSignal(button) {
    const username = button.dataset.username;
    const kind = button.dataset.signal;
    const key = `${kind}:${username}`;
    if (Number(state.cooldowns.get(key) || 0) > Date.now()) return;
    button.disabled = true;
    const original = button.textContent;
    try {
      await api("/api/social/signals", {
        method: "POST",
        body: JSON.stringify({ username, kind }),
      });
      state.cooldowns.set(key, Date.now() + 120_000);
      button.closest(".game-friend-pet")?.classList.add("is-poked");
      setTimeout(() => button.closest(".game-friend-pet")?.classList.remove("is-poked"), 700);
      button.textContent = kind === "poke" ? t("Sent", "戳到了") : t("Called", "已催上线");
      signalStatus.textContent = kind === "poke"
        ? t(`A tiny signal is on its way to ${username}.`, `一束小信号已经飞向 ${username}。`)
        : t(`${username} will see your invitation next time they arrive.`, `${username} 上线时会看到你的邀请。`);
    } catch (error) {
      signalStatus.textContent = error.message;
      button.textContent = original;
      button.disabled = false;
      return;
    }
    setTimeout(() => {
      button.textContent = original;
      button.disabled = false;
      signalStatus.textContent = "";
    }, 2600);
  }

  async function init() {
    try {
      const session = await api("/api/auth/session");
      if (!session.user) return;
      state.user = session.user;
      const [profileData] = await Promise.all([
        api(`/api/social/profile?username=${encodeURIComponent(session.user.username)}`),
        refreshFriends(),
      ]);
      state.profile = profileData.profile;
      state.totalSeconds = Number(state.profile.playSeconds || 0);
      renderSelf();
      sessionRail.hidden = false;
      friendsRail.hidden = false;
      document.documentElement.classList.add("game-social-enabled");
      tickClock();
      state.clockTimer = setInterval(tickClock, 1000);
      state.refreshTimer = setInterval(() => {
        if (!document.hidden) refreshFriends().catch(() => {});
      }, 20_000);
    } catch (_) {
      // The game stays fully playable when the optional social layer is unavailable.
    }
  }

  offlineToggle.addEventListener("click", () => {
    const expanded = offlineToggle.getAttribute("aria-expanded") === "true";
    offlineToggle.setAttribute("aria-expanded", String(!expanded));
    offlineList.hidden = expanded;
  });
  friendsRail.addEventListener("click", event => {
    const button = event.target.closest("[data-signal]");
    if (button) sendSignal(button);
  });
  [sessionRail, friendsRail].forEach(rail => {
    rail.addEventListener("pointerdown", event => event.stopPropagation());
    rail.addEventListener("keydown", event => event.stopPropagation());
  });
  addEventListener("observatory:playtime", event => {
    const data = event.detail || {};
    state.totalSeconds = Number(data.playSeconds || state.totalSeconds);
    if (state.profile && data.rank) state.profile.rank = data.rank;
    renderSelf();
  });
  addEventListener("visibilitychange", () => {
    if (!document.hidden && state.user) refreshFriends().catch(() => {});
  });
  init();
})();
