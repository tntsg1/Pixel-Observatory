(() => {
  "use strict";

  const languageStorageKey = "so-lang";
  const normalizeLanguage = value => /^zh(?:\b|-|_)/i.test(String(value || "")) ? "zh" : String(value || "").toLowerCase() === "en" ? "en" : "";
  const queryLanguage = normalizeLanguage(new URLSearchParams(location.search).get("lang"));
  let storedLanguage = "";
  try { storedLanguage = normalizeLanguage(localStorage.getItem(languageStorageKey)); } catch (_) {}
  const language = queryLanguage || storedLanguage || normalizeLanguage(navigator.language) || "en";
  try { localStorage.setItem(languageStorageKey, language); } catch (_) {}
  document.documentElement.dataset.lang = language;
  document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
  window.POLanguage = Object.freeze({
    current: () => language,
    storageKey: languageStorageKey,
  });

  const overlay = document.getElementById("status");
  const progress = document.getElementById("status-progress");
  const phase = document.getElementById("loader-phase");
  const percent = document.getElementById("loader-percent");
  const orbitalPercent = document.getElementById("loader-orbital-percent");
  const loaded = document.getElementById("loader-loaded");
  const optical = document.getElementById("loader-optical");
  const catalogue = document.getElementById("loader-catalogue");
  const network = document.getElementById("loader-network");
  const notice = document.getElementById("status-notice");
  const canvas = document.getElementById("loader-stars");
  if (!overlay || !progress || !phase || !percent) return;
  const context = canvas?.getContext("2d");
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const zh = language === "zh";
  const copy = zh ? {
    brand: "像素观测站",
    link: "浏览器观测链路已建立",
    eyebrow: "观测站启动序列",
    summary: "正在准备仪器、星表与观测席位。",
    stream: "实时资源流",
    open: "请保持此标签页开启",
    archive: "数据档案",
    optics: "光学平台",
    catalogue: "天空星表",
    preparing: "正在准备资源流",
    phases: [
      {until: .12, label: "正在打开观测档案"},
      {until: .38, label: "正在加载仪器与光学组件"},
      {until: .7, label: "正在绘制恒星星表"},
      {until: .92, label: "正在校准观测系统"},
      {until: 1.01, label: "正在让观测站上线"},
    ],
    opticalWaiting: "等待校准", opticalReady: "光路已校验",
    catalogueWaiting: "正在加载坐标", catalogueReady: "星位已索引",
    network: "\u7f51\u7edc\u94fe\u8def",
    runtimePhases: {
      downloading: "\u6b63\u5728\u4e0b\u8f7d\u6e38\u620f\u6570\u636e",
      resuming: "\u6b63\u5728\u7ee7\u7eed\u5df2\u4fdd\u5b58\u7684\u4e0b\u8f7d",
      cached: "\u6b63\u5728\u6253\u5f00\u672c\u5730\u6e38\u620f\u7f13\u5b58",
      ready: "\u6b63\u5728\u51c6\u5907\u5df2\u4e0b\u8f7d\u7684\u8fd0\u884c\u73af\u5883",
      interrupted: "\u8fde\u63a5\u5df2\u6682\u505c\uff0c\u5df2\u5b8c\u6210\u7684\u90e8\u5206\u4e0d\u4f1a\u4e22\u5931",
    },
  } : {
    brand: "Pixel Observatory",
    link: "Browser observatory link established",
    eyebrow: "Observatory startup sequence",
    summary: "Preparing your instruments, sky catalogue and observing station.",
    stream: "Live package stream",
    open: "Keep this tab open",
    archive: "Data archive",
    optics: "Optical bench",
    catalogue: "Sky catalogue",
    network: "Network link",
    preparing: "Preparing stream",
    phases: [
      {until: .12, label: "Opening observatory archive"},
      {until: .38, label: "Loading instruments and optics"},
      {until: .7, label: "Plotting the stellar catalogue"},
      {until: .92, label: "Calibrating observation systems"},
      {until: 1.01, label: "Bringing the observatory online"},
    ],
    opticalWaiting: "Awaiting calibration", opticalReady: "Optical path verified",
    catalogueWaiting: "Loading coordinates", catalogueReady: "Star positions indexed",
    runtimePhases: {
      downloading: "Downloading game data",
      resuming: "Resuming saved download",
      cached: "Opening local game cache",
      ready: "Preparing downloaded runtime",
      interrupted: "Connection paused — completed data is saved",
    },
  };
  const setText = (id, value) => {
    const node = document.getElementById(id);
    if (node) node.textContent = value;
  };
  setText("loader-brand-name", copy.brand);
  setText("loader-link-state", copy.link);
  setText("loader-eyebrow", copy.eyebrow);
  setText("loader-summary", copy.summary);
  setText("loader-stream", copy.stream);
  setText("loader-open", copy.open);
  setText("loader-data-label", copy.archive);
  setText("loader-optical-label", copy.optics);
  setText("loader-catalogue-label", copy.catalogue);
  setText("loader-network-label", copy.network);

  const phases = copy.phases;
  let lastPercent = -1;
  let stars = [];
  let dust = [];
  let constellation = [];
  let pointerFrame = 0;
  const runtimeTransfers = new Map();
  let runtimeTransfer = null;
  let runtimeDirty = false;

  function formatBytes(value) {
    const bytes = Number(value) || 0;
    if (bytes < 1024 * 1024) return `${Math.max(0, Math.round(bytes / 1024))} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  function formatRate(value) {
    const bytes = Number(value) || 0;
    if (bytes <= 0) return "--";
    return `${formatBytes(bytes)}/s`;
  }

  function formatDuration(value) {
    const seconds = Math.max(0, Math.round(Number(value) || 0));
    if (!seconds) return "--";
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    const remainder = seconds % 60;
    return minutes >= 60 ? `${Math.floor(minutes / 60)}h ${minutes % 60}m` : `${minutes}m ${remainder}s`;
  }

  function renderRuntimeTransfer() {
    if (!runtimeTransfer) return false;
    const total = Number(runtimeTransfer.total) || 0;
    const value = Math.min(total, Math.max(0, Number(runtimeTransfer.loaded) || 0));
    if (!total) return false;
    const ratio = value / total;
    const nextPercent = Math.round(ratio * 100);
    percent.textContent = `${nextPercent}%`;
    if (orbitalPercent) orbitalPercent.textContent = `${nextPercent}%`;
    phase.textContent = copy.runtimePhases[runtimeTransfer.phase] || copy.preparing;
    if (loaded) loaded.textContent = `${formatBytes(value)} / ${formatBytes(total)}`;
    if (network) {
      if (runtimeTransfer.phase === "cached") network.textContent = zh ? "\u672c\u5730\u7f13\u5b58\u5df2\u547d\u4e2d" : "Local cache hit";
      else if (runtimeTransfer.phase === "interrupted") network.textContent = zh ? "\u5df2\u6682\u505c\uff0c\u4e0b\u6b21\u4ece\u5df2\u4fdd\u5b58\u90e8\u5206\u7ee7\u7eed" : "Paused; completed ranges are saved";
      else {
        const rate = formatRate(runtimeTransfer.rate);
        const remaining = `${zh ? "\u5269\u4f59" : "Remaining"} ${formatBytes(Math.max(0, total - value))}`;
        const eta = runtimeTransfer.eta > 0 ? `${zh ? "\u5269\u4f59" : "ETA"} ${formatDuration(runtimeTransfer.eta)}` : "";
        network.textContent = [rate, remaining, eta].filter(Boolean).join(" \u00b7 ") || (zh ? "\u6b63\u5728\u6d4b\u91cf\u901f\u5ea6" : "Measuring transfer");
      }
    }
    if (optical) optical.textContent = ratio > .43 ? copy.opticalReady : copy.opticalWaiting;
    if (catalogue) catalogue.textContent = ratio > .72 ? copy.catalogueReady : copy.catalogueWaiting;
    return true;
  }

  function recordRuntimeTransfer(detail) {
    if (!detail?.asset) return;
    runtimeTransfers.set(detail.asset, detail);
    const transfers = [...runtimeTransfers.values()].filter(item => Number(item.total) > 0);
    if (!transfers.length) return;
    const total = transfers.reduce((sum, item) => sum + Number(item.total || 0), 0);
    const loaded = transfers.reduce((sum, item) => sum + Math.min(Number(item.total || 0), Math.max(0, Number(item.loaded || 0))), 0);
    const cachedBytes = transfers.reduce((sum, item) => sum + Math.min(Number(item.total || 0), Math.max(0, Number(item.cachedBytes || 0))), 0);
    const rate = transfers.reduce((sum, item) => sum + Math.max(0, Number(item.rate || 0)), 0);
    const active = transfers.filter(item => !["cached", "ready", "interrupted"].includes(item.phase));
    const phase = transfers.some(item => item.phase === "interrupted") ? "interrupted"
      : active.some(item => item.phase === "downloading") ? "downloading"
        : active.some(item => item.phase === "resuming") ? "resuming"
          : transfers.some(item => item.phase === "ready") ? "ready" : "cached";
    runtimeTransfer = { phase, total, loaded, cachedBytes, rate, eta: rate > 0 ? Math.max(0, total - loaded) / rate : 0 };
    runtimeDirty = true;
  }

  addEventListener("po:runtime-progress", event => recordRuntimeTransfer(event.detail));
  navigator.serviceWorker?.addEventListener("message", event => {
    if (event.data?.source !== "pixel-observatory-runtime") return;
    recordRuntimeTransfer(event.data);
  });

  function update() {
    if (!overlay.isConnected) return;
    if (runtimeTransfer && (runtimeDirty || runtimeTransfer.phase !== "ready")) {
      runtimeDirty = false;
      renderRuntimeTransfer();
      requestAnimationFrame(update);
      return;
    }
    const max = Number(progress.max) || 0;
    const value = Number(progress.value) || 0;
    const ratio = max > 0 ? Math.min(1, Math.max(0, value / max)) : 0;
    const nextPercent = Math.round(ratio * 100);

    if (nextPercent !== lastPercent) {
      lastPercent = nextPercent;
      percent.textContent = `${nextPercent}%`;
      if (orbitalPercent) orbitalPercent.textContent = `${nextPercent}%`;
      phase.textContent = phases.find(item => ratio < item.until)?.label || phases.at(-1).label;
      if (loaded) loaded.textContent = max > 0 ? `${formatBytes(value)} / ${formatBytes(max)}` : copy.preparing;
      if (optical) optical.textContent = ratio > .43 ? copy.opticalReady : copy.opticalWaiting;
      if (catalogue) catalogue.textContent = ratio > .72 ? copy.catalogueReady : copy.catalogueWaiting;
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
  const pendingKey = "pixel-observatory:pending-play-seconds";
  const pendingReportKey = "pixel-observatory:pending-playtime-report";
  const sessionKey = "pixel-observatory:play-session-id";
  const sessionUserKey = "pixel-observatory:play-session-user";
  const effectiveSessionKey = "pixel-observatory:effective-play-seconds";
  const heartbeatIntervalMs = 30_000;
  const maxPendingSeconds = 90;
  let audioContext = null;
  let heartbeatTimer = 0;
  let signedIn = null;
  let gameInteractive = false;
  let foregroundStartedAt = 0;
  let foregroundTimer = 0;
  let heartbeatInFlight = false;
  let leaseAccepted = false;
  let signedInUserId = sessionStorage.getItem(sessionUserKey) || "";
  let pendingSeconds = Math.max(0, Math.min(
    maxPendingSeconds,
    Number(sessionStorage.getItem(pendingKey) || 0),
  ));
  let pendingReport = null;
  try {
    const storedReport = JSON.parse(sessionStorage.getItem(pendingReportKey) || "null");
    if (storedReport
      && /^[a-zA-Z0-9_-]{16,96}$/.test(String(storedReport.id || ""))
      && ["heartbeat", "resume", "pause", "leave"].includes(String(storedReport.event || ""))
      && Number.isFinite(Number(storedReport.activeSeconds))) {
      pendingReport = {
        id: String(storedReport.id),
        event: String(storedReport.event),
        activeSeconds: Math.max(0, Math.min(maxPendingSeconds, Math.floor(Number(storedReport.activeSeconds)))),
      };
    }
  } catch {
    sessionStorage.removeItem(pendingReportKey);
  }
  let effectiveSessionSeconds = Math.max(0, Number(sessionStorage.getItem(effectiveSessionKey) || 0));
  let playSessionId = sessionStorage.getItem(sessionKey) || "";
  if (!/^[a-zA-Z0-9_-]{16,96}$/.test(playSessionId)) {
    playSessionId = crypto.randomUUID
      ? crypto.randomUUID()
      : `${Date.now().toString(36)}_${crypto.getRandomValues(new Uint32Array(2)).join("_")}`;
    sessionStorage.setItem(sessionKey, playSessionId);
  }

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

  function syncStatus(status, message = "") {
    document.documentElement.dataset.playtimeSync = status;
    dispatchEvent(new CustomEvent("observatory:playtime-sync", {
      detail: {
        status,
        message,
        pendingSeconds: Math.floor(pendingSeconds),
        effectiveSessionSeconds: Math.floor(effectiveSessionSeconds),
        leaseAccepted,
      },
    }));
  }

  function persistPending() {
    sessionStorage.setItem(pendingKey, pendingSeconds.toFixed(3));
    sessionStorage.setItem(effectiveSessionKey, effectiveSessionSeconds.toFixed(3));
    if (pendingReport) sessionStorage.setItem(pendingReportKey, JSON.stringify(pendingReport));
    else sessionStorage.removeItem(pendingReportKey);
  }

  function createReportId() {
    return crypto.randomUUID
      ? crypto.randomUUID()
      : `${Date.now().toString(36)}_${crypto.getRandomValues(new Uint32Array(2)).join("_")}`;
  }

  function reportFor(event) {
    if (pendingReport && pendingReport.event === event) return pendingReport;
    pendingReport = {
      id: createReportId(),
      event,
      activeSeconds: Math.floor(pendingSeconds),
    };
    persistPending();
    return pendingReport;
  }

  function publishEffectiveSession() {
    dispatchEvent(new CustomEvent("observatory:playtime-local", {
      detail: {
        active: Boolean(gameInteractive && !document.hidden && leaseAccepted),
        leaseAccepted,
        sessionSeconds: Math.floor(effectiveSessionSeconds),
        pendingSeconds: Math.floor(pendingSeconds),
      },
    }));
  }

  function resetSessionForUser(userId = "") {
    pendingSeconds = 0;
    effectiveSessionSeconds = 0;
    leaseAccepted = false;
    pendingReport = null;
    persistPending();
    signedInUserId = userId;
    sessionStorage.setItem(sessionUserKey, userId);
    playSessionId = crypto.randomUUID
      ? crypto.randomUUID()
      : `${Date.now().toString(36)}_${crypto.getRandomValues(new Uint32Array(2)).join("_")}`;
    sessionStorage.setItem(sessionKey, playSessionId);
  }

  function accrueForeground() {
    if (!gameInteractive || !foregroundStartedAt) return;
    const now = performance.now();
    const elapsed = Math.max(0, Math.min(maxPendingSeconds, (now - foregroundStartedAt) / 1000));
    pendingSeconds = Math.min(maxPendingSeconds, pendingSeconds + elapsed);
    if (leaseAccepted && !document.hidden) {
      effectiveSessionSeconds += elapsed;
    }
    foregroundStartedAt = document.hidden ? 0 : now;
    persistPending();
    publishEffectiveSession();
  }

  async function resolveSession(force = false) {
    if (!force && signedIn !== null) return signedIn;
    const sessionResponse = await fetch("/api/auth/session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    if (!sessionResponse.ok) throw new Error(`Session check failed (${sessionResponse.status}).`);
    const session = await sessionResponse.json();
    // The Worker returns { ok, user }; it intentionally has no client-owned
    // "authenticated" flag. The signed server session user is the authority.
    const userId = String(session?.user?.id || "");
    signedIn = Boolean(userId);
    if (!signedIn) {
      resetSessionForUser("");
    } else if (signedInUserId !== userId) {
      resetSessionForUser(userId);
    }
    return signedIn;
  }

  async function heartbeat(event = "heartbeat", options = {}) {
    if (!gameInteractive) return;
    if (document.hidden && event !== "pause" && event !== "leave") return;
    accrueForeground();
    if (heartbeatInFlight) return;
    heartbeatInFlight = true;
    try {
      if (!(await resolveSession(options.forceSession))) return;
      const report = reportFor(event);
      const response = await fetch("/api/social/playtime", {
        method: "POST",
        credentials: "same-origin",
        headers: { "content-type": "application/json" },
        keepalive: Boolean(options.keepalive),
        body: JSON.stringify({
          sessionId: playSessionId,
          reportId: report.id,
          event,
          activeSeconds: report.activeSeconds,
        }),
      });
      if (!response.ok) {
        if (response.status === 401) signedIn = null;
        throw new Error(`Playtime sync failed (${response.status}).`);
      }
      const data = await response.json();
      const releasesLease = event === "pause" || event === "leave";
      leaseAccepted = data.leaseAccepted !== false && !releasesLease;
      const acknowledged = Math.max(0, Number(data.acknowledgedSeconds ?? data.earnedSeconds ?? 0));
      pendingSeconds = Math.max(0, pendingSeconds - acknowledged);
      pendingReport = null;
      persistPending();
      syncStatus(data.leaseAccepted === false ? "standby" : "synced");
      publishEffectiveSession();
      dispatchEvent(new CustomEvent("observatory:playtime", { detail: data }));
      const level = Number(data.rank?.level || 0);
      const previous = Number(localStorage.getItem(rankKey) || 0);
      if (previous > 0 && level > previous) celebrate(data.rank);
      if (level > 0) localStorage.setItem(rankKey, String(level));
    } catch (error) {
      persistPending();
      syncStatus("retrying", error instanceof Error ? error.message : "Playtime sync delayed.");
    } finally {
      heartbeatInFlight = false;
    }
  }

  function startTracking() {
    if (gameInteractive) return;
    gameInteractive = true;
    foregroundStartedAt = document.hidden ? 0 : performance.now();
    clearInterval(foregroundTimer);
    foregroundTimer = setInterval(accrueForeground, 1000);
    clearInterval(heartbeatTimer);
    heartbeat("resume", { forceSession: true });
    heartbeatTimer = setInterval(() => heartbeat("heartbeat"), heartbeatIntervalMs);
  }

  function watchForInteractiveGame() {
    if (!document.getElementById("status")) {
      startTracking();
      return;
    }
    const observer = new MutationObserver(() => {
      if (!document.getElementById("status")) {
        observer.disconnect();
        startTracking();
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  addEventListener("visibilitychange", () => {
    if (!gameInteractive) return;
    if (document.hidden) {
      heartbeat("pause", { keepalive: true });
      foregroundStartedAt = 0;
      publishEffectiveSession();
    } else {
      foregroundStartedAt = performance.now();
      heartbeat("resume", { forceSession: true });
      publishEffectiveSession();
    }
  });
  addEventListener("pagehide", () => heartbeat("leave", { keepalive: true }));
  addEventListener("beforeunload", () => heartbeat("leave", { keepalive: true }));
  addEventListener("observatory:request-heartbeat", () => heartbeat("heartbeat", { forceSession: true }));
  addEventListener("observatory:session-changed", () => {
    signedIn = null;
    leaseAccepted = false;
    publishEffectiveSession();
    heartbeat("resume", { forceSession: true });
  });
  watchForInteractiveGame();
})();

(() => {
  "use strict";

  const zh = window.POLanguage?.current() === "zh";
  const t = (en, cn) => zh ? cn : en;
  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[char]);
  const state = {
    user: null,
    profile: null,
    friends: [],
    effectiveSessionSeconds: Math.max(0, Number(sessionStorage.getItem("pixel-observatory:effective-play-seconds") || 0)),
    totalSeconds: 0,
    refreshTimer: 0,
    refreshInFlight: false,
    lastFriendsRefresh: 0,
    clockTimer: 0,
    cooldowns: new Map(),
  };

  document.body.insertAdjacentHTML("beforeend", `
    <section class="game-social-rail game-session-rail" id="game-session-rail" hidden aria-label="${t("Current observing session", "当前观测班次")}">
      <div class="game-glass-panel game-guest-panel" id="game-session-guest" hidden>
        <span class="game-guest-kicker">${t("OBSERVER ARCHIVE", "\u89c2\u6d4b\u8005\u6863\u6848")}</span>
        <h2>${t("Keep what you discover.", "\u8ba9\u6bcf\u6b21\u53d1\u73b0\u90fd\u7559\u4e0b\u6765\u3002")}</h2>
        <p>${t("Create a free observer account to save progress across devices and turn observing time into rank.", "\u521b\u5efa\u514d\u8d39\u89c2\u6d4b\u8005\u8d26\u53f7\uff0c\u8de8\u8bbe\u5907\u4fdd\u5b58\u8fdb\u5ea6\uff0c\u5e76\u5c06\u89c2\u6d4b\u65f6\u957f\u7d2f\u79ef\u4e3a\u6bb5\u4f4d\u3002")}</p>
        <button class="game-guest-feature" type="button" data-auth-feature="cloud" data-auth-mode="register"><i aria-hidden="true">\u2601</i><span><strong>${t("Cloud progress", "\u4e91\u7aef\u5b58\u6863")}</strong><small>${t("Continue on another browser", "\u5728\u5176\u4ed6\u6d4f\u89c8\u5668\u7ee7\u7eed\u6e38\u73a9")}</small></span><b aria-hidden="true">\u203a</b></button>
        <button class="game-guest-feature" type="button" data-auth-feature="rank" data-auth-mode="register"><i aria-hidden="true">\u25ce</i><span><strong>${t("Observer rank", "\u89c2\u6d4b\u8005\u6bb5\u4f4d")}</strong><small>${t("Record playtime and achievements", "\u8bb0\u5f55\u65f6\u957f\u4e0e\u6210\u5c31")}</small></span><b aria-hidden="true">\u203a</b></button>
        <div class="game-guest-actions"><button type="button" data-auth-mode="register">${t("Create account", "\u6ce8\u518c\u8d26\u53f7")}</button><button type="button" data-auth-mode="login">${t("Sign in", "\u767b\u5f55")}</button></div>
      </div>
      <div class="game-glass-panel game-session-panel" id="game-session-member">
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
        <small class="game-playtime-sync" id="game-playtime-sync" aria-live="polite"></small>
      </div>
    </section>
    <aside class="game-social-rail game-friends-rail" id="game-friends-rail" hidden aria-label="${t("Friends at the observatory", "天文台好友")}">
      <div class="game-glass-panel game-guest-panel" id="game-friends-guest" hidden>
        <span class="game-guest-kicker">${t("OBSERVER NETWORK", "\u89c2\u6d4b\u8005\u7f51\u7edc")}</span>
        <h2>${t("The observatory is better together.", "\u5929\u6587\u53f0\u6709\u540c\u4f34\u65f6\u66f4\u6709\u8da3\u3002")}</h2>
        <p>${t("Sign in to see who is online, send private messages, and join the community ranking.", "\u767b\u5f55\u540e\u67e5\u770b\u5728\u7ebf\u597d\u53cb\u3001\u53d1\u9001\u79c1\u4fe1\uff0c\u5e76\u52a0\u5165\u793e\u533a\u6392\u884c\u699c\u3002")}</p>
        <button class="game-guest-feature" type="button" data-auth-feature="friends" data-auth-mode="login"><i aria-hidden="true">\u2726</i><span><strong>${t("Friends online", "\u5728\u7ebf\u597d\u53cb")}</strong><small>${t("Message, poke, and invite", "\u79c1\u4fe1\u3001\u620f\u4e00\u4e0b\u4e0e\u50ac\u4e0a\u7ebf")}</small></span><b aria-hidden="true">\u203a</b></button>
        <button class="game-guest-feature" type="button" data-auth-feature="community" data-auth-mode="login"><i aria-hidden="true">\u2261</i><span><strong>${t("Community and ranking", "\u793e\u533a\u4e0e\u6392\u884c\u699c")}</strong><small>${t("Meet other observers", "\u8ba4\u8bc6\u5176\u4ed6\u89c2\u6d4b\u8005")}</small></span><b aria-hidden="true">\u203a</b></button>
        <div class="game-guest-note"><span aria-hidden="true">\u25cf</span>${t("Your game remains playable without an account.", "\u4e0d\u6ce8\u518c\u4e5f\u53ef\u4ee5\u6b63\u5e38\u6e38\u73a9\u3002")}</div>
      </div>
      <div class="game-glass-panel game-friends-panel" id="game-friends-member">
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
    <aside class="game-feedback-dock" aria-label="${t("Game feedback", "游戏反馈")}">
      <button class="game-feedback-button" id="feedback-open" type="button">
        <span class="game-feedback-signal" aria-hidden="true"><i></i><i></i></span>
        <span><small>${t("FIELD REPORT", "现场记录")}</small><strong>${t("Report this moment", "反馈此刻的问题")}</strong></span>
        <b aria-hidden="true">+</b>
      </button>
    </aside>
    <section class="game-compact-controls" id="game-compact-controls" hidden aria-label="${t("Observatory tools", "观测站工具")}">
      <button class="game-compact-toggle" id="game-compact-toggle" type="button" aria-expanded="false"><span aria-hidden="true">⌁</span>${t("Observatory link", "观测站连接")}</button>
      <div class="game-compact-actions" id="game-compact-actions" hidden>
        <button type="button" data-compact-account data-auth-mode="register">${t("Account", "\u8d26\u53f7")}</button>
        <button type="button" data-compact-view="session">${t("My shift", "我的班次")}</button>
        <button type="button" data-compact-view="friends">${t("Friends", "好友")}</button>
        <button type="button" data-compact-feedback>${t("Report", "反馈")}</button>
      </div>
    </section>
    <div class="game-friend-toast" id="game-friend-toast" hidden role="status" aria-live="polite"></div>`);

  const sessionRail = document.getElementById("game-session-rail");
  const friendsRail = document.getElementById("game-friends-rail");
  const sessionGuest = document.getElementById("game-session-guest");
  const friendsGuest = document.getElementById("game-friends-guest");
  const sessionMember = document.getElementById("game-session-member");
  const friendsMember = document.getElementById("game-friends-member");
  const onlinePets = document.getElementById("game-online-pets");
  const offlineList = document.getElementById("game-offline-list");
  const offlineToggle = document.getElementById("game-offline-toggle");
  const signalStatus = document.getElementById("game-signal-status");
  const toast = document.getElementById("game-friend-toast");
  const feedbackDock = document.querySelector(".game-feedback-dock");
  const compactControls = document.getElementById("game-compact-controls");
  const compactToggle = document.getElementById("game-compact-toggle");
  const compactActions = document.getElementById("game-compact-actions");
  let toastTimer = 0;

  function openAccount(mode = "login", feature = "account") {
    document.dispatchEvent(new CustomEvent("po:open-account", {
      detail: { mode: mode === "register" ? "register" : "login", feature },
    }));
  }

  function showSocialSurface(authenticated) {
    sessionGuest.hidden = authenticated;
    friendsGuest.hidden = authenticated;
    sessionMember.hidden = !authenticated;
    friendsMember.hidden = !authenticated;
    sessionRail.hidden = false;
    friendsRail.hidden = false;
    compactControls.hidden = false;
    document.documentElement.classList.add("game-social-enabled");
    document.documentElement.classList.toggle("game-social-guest", !authenticated);
  }

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
    document.getElementById("game-session-time").textContent = formatClock(state.effectiveSessionSeconds);
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
      <div class="game-pet-actions"><button class="game-message-button" type="button" data-message="${name}">${t("Message", "私信")}</button><button class="game-signal-button" type="button" data-signal="poke" data-username="${name}">${t("Poke", "戳一下")}</button></div>
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

  function setCompactView(view) {
    const root = document.documentElement;
    root.classList.add("game-social-compact-open");
    root.classList.toggle("game-social-compact-session", view === "session");
    root.classList.toggle("game-social-compact-friends", view === "friends");
    compactToggle?.setAttribute("aria-expanded", "true");
    compactActions.hidden = false;
  }

  function closeCompactView() {
    const root = document.documentElement;
    root.classList.remove("game-social-compact-open", "game-social-compact-session", "game-social-compact-friends");
    compactToggle?.setAttribute("aria-expanded", "false");
    compactActions.hidden = true;
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
    if (state.refreshInFlight) return;
    state.refreshInFlight = true;
    try {
      const data = await api("/api/social/friends");
      state.friends = data.friends || [];
      state.lastFriendsRefresh = Date.now();
      renderFriends();
      await receiveSignals();
    } finally {
      state.refreshInFlight = false;
    }
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
      clearInterval(state.refreshTimer);
      clearInterval(state.clockTimer);
      if (!session.user) {
        state.user = null;
        state.profile = null;
        state.friends = [];
        showSocialSurface(false);
        return;
      }
      state.user = session.user;
      const [profileData] = await Promise.all([
        api(`/api/social/profile?username=${encodeURIComponent(session.user.username)}`),
        refreshFriends(),
      ]);
      state.profile = profileData.profile;
      state.totalSeconds = Number(state.profile.playSeconds || 0);
      renderSelf();
      showSocialSurface(true);
      tickClock();
      state.clockTimer = setInterval(tickClock, 1000);
      // Presence is an active-game signal, not something that waits for a
      // modal or manual refresh. Keep the rail responsive without allowing
      // concurrent list/signal requests to race each other.
      state.refreshTimer = setInterval(() => {
        if (!document.hidden) refreshFriends().catch(() => {});
      }, 8_000);
    } catch (_) {
      // The game stays fully playable when the optional social layer is unavailable.
    }
  }

  offlineToggle.addEventListener("click", () => {
    const expanded = offlineToggle.getAttribute("aria-expanded") === "true";
    offlineToggle.setAttribute("aria-expanded", String(!expanded));
    offlineList.hidden = expanded;
  });
  sessionRail.addEventListener("click", event => {
    const button = event.target.closest("[data-auth-mode]");
    if (button) openAccount(button.dataset.authMode, button.dataset.authFeature);
  });
  friendsRail.addEventListener("click", event => {
    const authButton = event.target.closest("[data-auth-mode]");
    if (authButton) {
      openAccount(authButton.dataset.authMode, authButton.dataset.authFeature);
      return;
    }
    const button = event.target.closest("[data-signal]");
    if (button) sendSignal(button);
    const messageButton = event.target.closest("[data-message]");
    if (messageButton) {
      document.dispatchEvent(new CustomEvent("po:open-inbox", {
        detail: {
          username: String(messageButton.dataset.message || ""),
          direct: true,
        },
      }));
    }
  });
  compactToggle?.addEventListener("click", () => {
    if (document.documentElement.classList.contains("game-social-compact-open")) closeCompactView();
    else setCompactView("session");
  });
  compactActions?.addEventListener("click", event => {
    const accountButton = event.target.closest("[data-compact-account]");
    if (accountButton) {
      closeCompactView();
      openAccount(accountButton.dataset.authMode, "account");
      return;
    }
    const view = event.target.closest("[data-compact-view]")?.dataset.compactView;
    if (view) setCompactView(view);
    if (event.target.closest("[data-compact-feedback]")) {
      closeCompactView();
      document.getElementById("feedback-open")?.click();
    }
  });
  [sessionRail, friendsRail, feedbackDock].forEach(rail => {
    rail.addEventListener("pointerdown", event => event.stopPropagation());
    rail.addEventListener("keydown", event => event.stopPropagation());
  });
  addEventListener("observatory:playtime", event => {
    const data = event.detail || {};
    state.totalSeconds = Number(data.playSeconds || state.totalSeconds);
    if (state.profile && data.rank) state.profile.rank = data.rank;
    renderSelf();
  });
  addEventListener("observatory:playtime-local", event => {
    state.effectiveSessionSeconds = Math.max(0, Number(event.detail?.sessionSeconds || 0));
    tickClock();
  });
  addEventListener("observatory:playtime-sync", event => {
    const status = String(event.detail?.status || "");
    const node = document.getElementById("game-playtime-sync");
    if (!node) return;
    node.dataset.status = status;
    node.textContent = status === "retrying"
      ? t("Playtime sync delayed - retrying", "游玩时长同步延迟，正在重试")
      : status === "standby"
        ? t("Counted in another active tab", "正在另一活动标签页中计时")
        : "";
  });
  addEventListener("visibilitychange", () => {
    if (!document.hidden && state.user) {
      refreshFriends().catch(() => {});
      dispatchEvent(new Event("observatory:request-heartbeat"));
    }
  });
  addEventListener("focus", () => {
    if (state.user) refreshFriends().catch(() => {});
  });
  document.addEventListener("po:session-changed", () => {
    closeCompactView();
    init();
  });
  init();
})();
