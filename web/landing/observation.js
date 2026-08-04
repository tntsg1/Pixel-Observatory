(() => {
  "use strict";
  const root = document.getElementById("observation-record");
  const canvas = document.getElementById("observation-sky");
  const context = canvas?.getContext("2d");
  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[character]);
  const id = decodeURIComponent(location.pathname.split("/").filter(Boolean).at(-1) || "");
  let shareData = null;

  function renderSky() {
    if (!canvas || !context) return;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    canvas.width = innerWidth * ratio;
    canvas.height = innerHeight * ratio;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, innerWidth, innerHeight);
    const seed = [...id].reduce((sum, character) => sum + character.charCodeAt(0), 1);
    for (let index = 0; index < 160; index += 1) {
      const x = (Math.sin(seed * (index + 3) * 12.9898) * 43758.5453) % 1;
      const y = (Math.sin(seed * (index + 7) * 78.233) * 24634.6345) % 1;
      const px = Math.abs(x) * innerWidth;
      const py = Math.abs(y) * innerHeight;
      const radius = .35 + (index % 7 === 0 ? .9 : .25);
      context.beginPath();
      context.fillStyle = index % 11 === 0 ? "rgba(225,183,93,.48)" : "rgba(178,220,222,.34)";
      context.arc(px, py, radius, 0, Math.PI * 2);
      context.fill();
    }
  }

  function meter(label, value) {
    const score = Math.round(Math.max(0, Math.min(100, Number(value) || 0)));
    return `<div class="observation-meter"><span>${escapeHtml(label)}</span><i style="--score:${score}%"></i><b>${score}</b></div>`;
  }

  function render(data) {
    shareData = data;
    const observation = data.observation || {};
    const object = observation.object || {};
    const equipment = observation.equipment || {};
    const quality = observation.quality || {};
    const zh = observation.locale === "zh";
    document.documentElement.lang = zh ? "zh-CN" : "en";
    document.title = `${object.name || "Observation"} · Pixel Observatory`;
    const parameters = (observation.parameters || []).map(parameter => `<div class="observation-parameter"><span>${escapeHtml(parameter.label)}</span><strong>${escapeHtml(parameter.value)}</strong></div>`).join("");
    const date = new Intl.DateTimeFormat(zh ? "zh-CN" : "en", {dateStyle:"medium",timeStyle:"short"}).format(new Date(data.createdAt));
    root.innerHTML = `<article class="observation-card">
      <section class="observation-visual">
        <div class="observation-kicker">${zh ? "已归档观测成果" : "Archived observation result"}</div>
        <div class="observation-orbit"><i class="observation-object-mark"></i></div>
        <div class="observation-visual-copy"><span class="observation-index">${escapeHtml(data.id)}</span><h1>${escapeHtml(object.name)}</h1><p>${escapeHtml(object.type)}</p></div>
      </section>
      <section class="observation-content">
        <header class="observation-header"><div><span class="observation-index">${zh ? "观测设备" : "Instrument record"}</span><h2>${escapeHtml(observation.telescopeName)}</h2></div><div class="observation-chip"><small>${zh ? "数据质量" : "Data quality"}</small>${escapeHtml(quality.grade)}</div></header>
        <div class="observation-equipment"><article><span>${zh ? "主设备" : "Primary equipment"}</span><strong>${escapeHtml(equipment.primary || observation.telescopeName)}</strong></article><article><span>${zh ? "观测配置" : "Observation setup"}</span><strong>${escapeHtml(equipment.secondary || equipment.detail || "Recorded")}</strong></article></div>
        ${parameters ? `<div class="observation-parameters">${parameters}</div>` : ""}
        <section class="observation-quality"><h3>${zh ? "观测质量" : "Observation quality"}</h3>${meter(zh ? "清晰度" : "Clarity", quality.clarity)}${meter(zh ? "对比度" : "Contrast", quality.contrast)}${meter(zh ? "细节" : "Detail", quality.detail)}</section>
        <section class="observation-discovery"><h3>${zh ? "本次发现" : "What became visible"}</h3><p>${escapeHtml(observation.discovery)}</p></section>
        <footer class="observation-footer"><div class="observation-byline"><strong>${escapeHtml(data.observer)}</strong>${escapeHtml(date)}</div><div class="observation-actions"><button class="observation-action" id="copy-observation" type="button">${zh ? "复制链接" : "Copy link"}</button><button class="observation-action primary" id="share-observation" type="button">${zh ? "分享" : "Share"}</button></div></footer>
      </section>
    </article>`;
    document.getElementById("copy-observation").onclick = async event => {
      await navigator.clipboard.writeText(location.href);
      event.currentTarget.textContent = zh ? "已复制" : "Copied";
    };
    document.getElementById("share-observation").onclick = async () => {
      if (navigator.share) await navigator.share({title: document.title, text: observation.discovery, url: location.href});
      else await navigator.clipboard.writeText(location.href);
    };
  }

  async function load() {
    if (!/^OBS-[A-Z0-9]{8,40}$/.test(id)) throw new Error("Invalid observation record.");
    const response = await fetch(`/api/observation-shares/${encodeURIComponent(id)}`, {credentials:"same-origin"});
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message || "Observation record not found.");
    render(data);
  }

  addEventListener("resize", renderSky);
  renderSky();
  load().catch(error => { root.innerHTML = `<div class="observation-error"><strong>Observation record unavailable</strong><span>${escapeHtml(error.message)}</span><a class="observation-play" href="/">Return to Pixel Observatory</a></div>`; });
})();
