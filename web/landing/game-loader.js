(() => {
  "use strict";

  const overlay = document.getElementById("status");
  const progress = document.getElementById("status-progress");
  const phase = document.getElementById("loader-phase");
  const percent = document.getElementById("loader-percent");
  const loaded = document.getElementById("loader-loaded");
  const optical = document.getElementById("loader-optical");
  const catalogue = document.getElementById("loader-catalogue");
  const notice = document.getElementById("status-notice");
  if (!overlay || !progress || !phase || !percent) return;

  const phases = [
    {until: .12, label: "Opening observatory archive"},
    {until: .38, label: "Loading instruments and optics"},
    {until: .7, label: "Plotting the stellar catalogue"},
    {until: .92, label: "Calibrating observation systems"},
    {until: 1.01, label: "Bringing the observatory online"},
  ];
  let lastPercent = -1;

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
      phase.textContent = phases.find(item => ratio < item.until)?.label || phases.at(-1).label;
      if (loaded) loaded.textContent = max > 0 ? `${formatBytes(value)} / ${formatBytes(max)}` : "Preparing stream";
      if (optical) optical.textContent = ratio > .43 ? "Optical path verified" : "Awaiting calibration";
      if (catalogue) catalogue.textContent = ratio > .72 ? "Star positions indexed" : "Loading coordinates";
    }
    requestAnimationFrame(update);
  }

  if (notice) {
    const syncNotice = () => {
      overlay.classList.toggle("has-notice", notice.style.display === "block");
    };
    new MutationObserver(syncNotice).observe(notice, {attributes: true, attributeFilter: ["style"]});
    syncNotice();
  }

  requestAnimationFrame(update);
})();
