import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

const outputDir = resolve(process.argv[2] || "build/web");
const indexPath = join(outputDir, "index.html");
const shellAsset = join(outputDir, "site-assets", "observatory-night.png");
let html = await readFile(indexPath, "utf8");

if (!html.includes("<canvas id=\"canvas\">")) {
	throw new Error("Godot Web export marker was not found.");
}

await mkdir(dirname(shellAsset), { recursive: true });
await copyFile(resolve("assets/main_menu/main_menu_bg_1024.png"), shellAsset);

const styles = `
/* Pixel Observatory browser shell */
:root { color-scheme: dark; }
body { background: #02060c; font-family: Georgia, "Noto Serif SC", serif; }
#canvas { width: 100vw; height: 100vh; }
#po-shell { position: fixed; inset: 0; z-index: 20; overflow: hidden; background: #02060c; color: #f4e7be; }
#po-shell::before { content: ""; position: absolute; inset: 0; background: linear-gradient(90deg, rgba(1,4,9,.88), rgba(1,4,9,.28) 58%, rgba(1,4,9,.7)), url("site-assets/observatory-night.png") center/cover no-repeat; transform: scale(1.02); animation: po-drift 16s ease-in-out infinite alternate; }
#po-shell::after { content: ""; position: absolute; inset: 0; pointer-events: none; background: linear-gradient(180deg, rgba(0,0,0,.08), rgba(0,0,0,.58)); }
.po-topbar, .po-hero, .po-footer { position: relative; z-index: 1; }
.po-topbar { display: flex; justify-content: space-between; align-items: center; padding: 28px clamp(22px, 5vw, 76px); font: 600 13px/1.2 Arial, sans-serif; letter-spacing: .14em; }
.po-brand { color: #e8c46f; text-transform: uppercase; }
.po-visitor { display: flex; gap: 10px; align-items: baseline; color: #dae4eb; }
.po-visitor strong { min-width: 3ch; color: #f4e7be; font-size: 18px; font-variant-numeric: tabular-nums; }
.po-hero { min-height: calc(100vh - 156px); display: flex; align-items: center; padding: 24px clamp(22px, 11vw, 172px) 92px; }
.po-copy { max-width: 590px; }
.po-kicker { margin: 0 0 18px; color: #d9b55e; font: 600 12px/1.2 Arial, sans-serif; letter-spacing: .18em; text-transform: uppercase; }
.po-title { margin: 0; font-size: clamp(48px, 8vw, 102px); font-weight: 600; line-height: .89; letter-spacing: 0; text-shadow: 0 3px 22px #000; }
.po-title span { display: block; color: #d9b55e; }
.po-summary { max-width: 470px; margin: 28px 0; color: #d9e0e6; font: 400 clamp(16px, 2vw, 20px)/1.6 Arial, "Noto Sans SC", sans-serif; }
.po-launch { display: inline-flex; align-items: center; gap: 12px; border: 1px solid #d6aa46; background: rgba(8,19,31,.82); box-shadow: inset 0 0 0 1px rgba(255,233,160,.18), 0 10px 35px rgba(0,0,0,.36); color: #ffe7a4; cursor: pointer; padding: 16px 23px; font: 700 14px/1 Arial, sans-serif; letter-spacing: .1em; transition: transform .18s ease, background .18s ease, box-shadow .18s ease; }
.po-launch:hover, .po-launch:focus-visible { transform: translateY(-2px); background: rgba(26,48,67,.96); box-shadow: inset 0 0 0 1px rgba(255,233,160,.32), 0 14px 35px rgba(0,0,0,.48); outline: none; }
.po-launch::before { content: ""; width: 0; height: 0; border-block: 7px solid transparent; border-left: 11px solid #e9c770; }
.po-footer { position: absolute; bottom: 25px; left: clamp(22px, 5vw, 76px); right: clamp(22px, 5vw, 76px); display: flex; justify-content: space-between; gap: 16px; color: #b6c2cc; font: 12px/1.4 Arial, sans-serif; }
#po-shell.po-leaving { opacity: 0; pointer-events: none; transition: opacity .62s ease; }
@keyframes po-drift { from { transform: scale(1.02) translate3d(0,0,0); } to { transform: scale(1.07) translate3d(-.8%, -.5%,0); } }
@media (max-width: 620px) { .po-topbar { padding-top: 20px; } .po-visitor span { display: none; } .po-hero { padding-bottom: 110px; } .po-footer { flex-direction: column; } }
`;

const shell = `
<section id="po-shell" aria-label="Pixel Observatory">
  <div class="po-topbar"><div class="po-brand">Pixel Observatory</div><div class="po-visitor"><span>观测站访客</span><strong id="po-visitor-count">--</strong></div></div>
  <main class="po-hero"><div class="po-copy"><p class="po-kicker">Astronomy Education Game</p><h1 class="po-title">像素<span>天文台</span></h1><p class="po-summary">亲手组装望远镜，穿过真实的夜空，完成属于你的观测记录。</p><button class="po-launch" id="po-launch" type="button">进入观测站</button></div></main>
  <div class="po-footer"><span>Build a telescope. Learn the sky.</span><span id="po-visit-status">正在校准观测站</span></div>
</section>`;

const client = `
<script>
(() => {
  const shell = document.getElementById('po-shell');
  const launch = document.getElementById('po-launch');
  const count = document.getElementById('po-visitor-count');
  const status = document.getElementById('po-visit-status');
  const storageKey = 'pixel-observatory-visitor-id';
  const visitorId = (() => {
    let id = localStorage.getItem(storageKey);
    if (!id) { id = (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random()).replace(/[^a-zA-Z0-9_-]/g, ''); localStorage.setItem(storageKey, id); }
    return id;
  })();
  const animate = (target) => {
    const start = Number(count.textContent.replace(/\\D/g, '')) || 0;
    const began = performance.now();
    const tick = (now) => { const p = Math.min(1, (now - began) / 650); count.textContent = Math.round(start + (target - start) * (1 - Math.pow(1 - p, 3))).toLocaleString(); if (p < 1) requestAnimationFrame(tick); };
    requestAnimationFrame(tick);
  };
  const visitEndpoint = location.hostname.endsWith('github.io') ? 'https://pixelobservatorygame.com/api/visits' : '/api/visits';
  fetch(visitEndpoint, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ visitorId }) })
    .then((response) => response.ok ? response.json() : Promise.reject())
    .then(({ total, isNew }) => { animate(total); status.textContent = isNew ? '欢迎加入今晚的观测' : '欢迎回来，观测记录仍在等待'; })
    .catch(() => { count.textContent = '—'; status.textContent = '观测站已就绪'; });
  launch.addEventListener('click', () => shell.classList.add('po-leaving'));
})();
</script>`;

html = html.replace("</style>", `${styles}</style>`);
html = html.replace("<body>", `<body>${shell}`);
html = html.replace("</body>", `${client}</body>`);
await writeFile(indexPath, html);
console.log(`Added Pixel Observatory web shell to ${indexPath}`);
