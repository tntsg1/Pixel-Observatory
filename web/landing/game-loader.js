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
