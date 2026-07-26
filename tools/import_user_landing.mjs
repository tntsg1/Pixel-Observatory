// Import the authored website package into web/landing/ for the web shell.
//
// Source  : a self-contained static site package (index.html + img/ + site files)
// Target  : web/landing/promo.html + web/landing/img/ + web/landing/<site files>
//
// tools/build_web_shell.mjs then copies web/landing/* to the output root and
// renames promo.html to index.html, so the published layout stays:
//   /        official website
//   /game/   Godot Web export
//
// Every transform below is asserted. A replacement that no longer matches the
// source throws instead of silently dropping the feature it was protecting.

import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, join, resolve } from "node:path";

const packageDir = resolve(
  process.argv[2] || "C:/Users/tntsg/Desktop/pixelobservatorygame",
);
const sourcePath = join(packageDir, "index.html");
const outputPath = resolve(process.argv[3] || "web/landing/promo.html");
const landingDir = resolve("web/landing");

let html = await readFile(sourcePath, "utf8");

// --- assertion helpers -----------------------------------------------------

const applied = [];

function replaceOnce(pattern, replacement, label) {
  const before = html;
  html = html.replace(pattern, replacement);
  if (html === before) {
    throw new Error(
      `Transform "${label}" did not match the source website. ` +
        `Update tools/import_user_landing.mjs to match ${basename(sourcePath)} ` +
        `instead of shipping the landing page without it.`,
    );
  }
  applied.push(label);
}

function replaceAllOnce(search, replacement, label) {
  if (!html.includes(search)) {
    throw new Error(`Transform "${label}" found no occurrences of ${search}.`);
  }
  html = html.replaceAll(search, replacement);
  applied.push(label);
}

// --- English-first document shell -----------------------------------------

replaceOnce(
  /<html[^>]*>/i,
  '<html lang="en" data-lang="en">',
  "html element defaults to English",
);
replaceOnce(
  /<title>[^<]*<\/title>/i,
  "<title>Starlight Observatory</title>",
  "English document title",
);
replaceOnce(
  /<meta name="description"[^>]*>/i,
  '<meta name="description" content="Starlight Observatory is a pixel astronomy simulation. Build your telescope, read the sky, and discover more.">',
  "English meta description",
);

// Canonical URL, Open Graph card, Twitter card, theme colour, favicon and the
// JSON-LD block are already correct in the package and are left untouched.

// The Latin gloss under each principle heading is redundant in English mode.
replaceOnce(
  'html[data-lang="en"] .zh{display:none!important}',
  'html[data-lang="en"] .zh{display:none!important}\n  html[data-lang="en"] .pr h3 .lat{display:none!important}',
  "hide Latin gloss in English mode",
);

// The floating nav should snap rather than glide.
replaceOnce(
  "transition:opacity .5s,transform .6s cubic-bezier(.22,1,.36,1);max-width:calc(100vw - 24px)}",
  "transition:opacity .18s ease-out,transform .22s cubic-bezier(.23,1,.32,1);max-width:calc(100vw - 24px)}",
  "responsive nav transition",
);

// --- same-domain game route ------------------------------------------------

// Production serves the Godot export at /game/ (see cloudflare/worker.mjs and
// tools/build_web_shell.mjs). Never point these at an external host.
replaceAllOnce(
  "https://pixelobservatorygame.com/game/",
  "game/",
  "relative game/ route",
);

// --- bilingual wordmarks ---------------------------------------------------

replaceOnce(
  '<h1>STARLIGHT OBSERVATORY<span class="sub">',
  '<h1>STARLIGHT OBSERVATORY<span class="sub zh">',
  "hero subtitle only in Chinese mode",
);
replaceOnce(
  /(<p class="eyebrow rv" style="text-align:center">)Starlight Observatory[^<]*(<\/p>)/,
  '$1<span class="en">Starlight Observatory</span><span class="zh">&#26143;&#20809;&#22825;&#25991;&#21488;</span>$2',
  "bilingual finale eyebrow",
);
replaceOnce(
  /<b>STARLIGHT OBSERVATORY[^<]*<\/b>/,
  '<b><span class="en">STARLIGHT OBSERVATORY</span><span class="zh">&#26143;&#20809;&#22825;&#25991;&#21488;</span></b>',
  "bilingual footer wordmark",
);

// --- language switch defaults to English ----------------------------------

replaceOnce(
  /(<button[^>]+id="langZh"[^>]+aria-pressed=")true(")/,
  "$1false$2",
  "language switch: Chinese not pressed",
);
replaceOnce(
  /(<button[^>]+id="langEn"[^>]+aria-pressed=")false(")/,
  "$1true$2",
  "language switch: English pressed",
);
replaceOnce(
  /var TITLES = \{[^;]+;/,
  "var TITLES = {zh:'\\u661f\\u5149\\u5929\\u6587\\u53f0', en:'Starlight Observatory'};",
  "document titles per language",
);
replaceOnce(
  /setLang\(saved \|\| \(\(navigator\.language \|\| 'en'\)[^;]+;/,
  "setLang(saved || 'en', false);",
  "English default instead of browser language",
);

// --- nav reveal + interruptible section navigation -------------------------
// Keeps the behaviour committed in "fix: reveal navigation after scrolling
// stops" and "feat: animate section navigation".

replaceOnce(
  `  var lastY = 0, ticking = false;
  function onScroll(){
    var y = scrollY;
    if(!reduced && heroInner && y < innerHeight*1.2){
      heroInner.style.transform = 'translateY('+(y*.3)+'px)';
      heroInner.style.opacity = Math.max(0, 1 - y/(innerHeight*.7));
    }
    if(gnav){
      if(y < 90) gnav.classList.add('hide');
      else if(y > lastY + 4) gnav.classList.add('hide');
      else if(y < lastY - 4) gnav.classList.remove('hide');
    }
    lastY = y; ticking = false;
  }
  addEventListener('scroll', function(){
    if(!ticking){ requestAnimationFrame(onScroll); ticking = true; }
  }, {passive:true});
  onScroll();`,
  `  var lastY = scrollY, ticking = false, navRevealTimer = 0;
  function revealNavAfterScroll(){
    clearTimeout(navRevealTimer);
    navRevealTimer = setTimeout(function(){
      if(gnav && scrollY >= 90) gnav.classList.remove('hide');
    }, 280);
  }
  function onScroll(){
    var y = scrollY;
    if(!reduced && heroInner && y < innerHeight*1.2){
      heroInner.style.transform = 'translateY('+(y*.3)+'px)';
      heroInner.style.opacity = Math.max(0, 1 - y/(innerHeight*.7));
    }
    if(gnav){
      if(y < 90) gnav.classList.add('hide');
      else if(y > lastY + 4) gnav.classList.add('hide');
      else if(y < lastY - 4) gnav.classList.remove('hide');
    }
    lastY = y; ticking = false;
  }
  addEventListener('scroll', function(){
    if(!ticking){ requestAnimationFrame(onScroll); ticking = true; }
    revealNavAfterScroll();
  }, {passive:true});
  onScroll();

  /* ---------- interruptible section navigation ---------- */
  var sectionScrollFrame = 0;
  function cancelSectionScroll(){
    if(sectionScrollFrame) cancelAnimationFrame(sectionScrollFrame);
    sectionScrollFrame = 0;
  }
  function scrollToSection(target, hash){
    cancelSectionScroll();
    var startY = scrollY;
    var targetY = Math.max(0, target.getBoundingClientRect().top + startY - 92);
    var distance = targetY - startY;
    if(Math.abs(distance) < 2) return;
    var duration = reduced ? 180 : Math.min(760, Math.max(420, 420 + Math.abs(distance) * 0.055));
    var began = performance.now();
    history.pushState(null, '', hash);
    function step(now){
      var progress = Math.min(1, (now - began) / duration);
      var eased = progress < 0.5
        ? 4 * progress * progress * progress
        : 1 - Math.pow(-2 * progress + 2, 3) / 2;
      scrollTo(0, startY + distance * eased);
      if(progress < 1) sectionScrollFrame = requestAnimationFrame(step);
      else sectionScrollFrame = 0;
    }
    sectionScrollFrame = requestAnimationFrame(step);
  }
  document.querySelectorAll('a[href^="#"]').forEach(function(link){
    link.addEventListener('click', function(event){
      if(event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      var hash = link.getAttribute('href');
      if(!hash || hash === '#') return;
      var target = document.getElementById(hash.slice(1));
      if(!target) return;
      event.preventDefault();
      scrollToSection(target, hash);
    });
  });
  addEventListener('wheel', cancelSectionScroll, {passive:true});
  addEventListener('touchstart', cancelSectionScroll, {passive:true});`,
  "nav reveal and interruptible section navigation",
);

// --- bilingual tooltips ----------------------------------------------------
// Keyed by the authored Chinese text, so reordering or editing a tooltip in the
// source cannot silently shift the English column out of alignment.

const TOOLTIPS_EN = {
  "人眼水平视野接近 120°，是所有观测方式中最广的。":
    "Human horizontal vision approaches 120 degrees, the widest view used in this journey.",
  "肉眼极限星等约 6 等——再暗的天体就需要仪器帮忙。":
    "The unaided eye reaches roughly magnitude 6; fainter objects require an instrument.",
  "在黑暗中等待约 30 分钟，瞳孔扩张、视杆细胞激活，才能看到最暗的星。":
    "About 30 minutes in darkness lets the pupil and rod cells reveal fainter stars.",
  "物镜到焦点的距离。焦距越长，同一目镜下放大率越高。":
    "Focal length is the distance from the objective to its focus. A longer focal length yields more magnification with the same eyepiece.",
  "放大率 = 物镜焦距 ÷ 目镜焦距。游戏里用的就是这条真实公式。":
    "Magnification equals objective focal length divided by eyepiece focal length - the game uses this formula directly.",
  "倍率升高，视野变窄——看得更细，也更容易跟丢目标。":
    "Higher magnification narrows the field, revealing detail while making targets easier to lose.",
  "口径 × 2 是有效放大率上限，超过就是空放大：影像更大但更糊。":
    "Useful magnification tops out near twice the aperture in millimetres. Beyond that the image only grows blurrier.",
  "地球每 4 分钟自转 1°。倍率越高，目标离开视野越快。":
    "Earth rotates one degree every four minutes, so high-power targets drift out of view quickly.",
  "云层会临时遮挡目标，等待或换目标都是策略。":
    "Passing clouds can temporarily hide a target; waiting or changing targets are both valid choices.",
  "大气湍流让影像抖动模糊。视宁度好的夜晚才适合高倍。":
    "Turbulent air softens and shakes the image. High power works best under steady seeing.",
  "城市灯光抬高天空背景亮度，淹没暗弱天体。":
    "City glow raises the sky background and overwhelms faint objects.",
  "根据条件降低倍率、重新调焦，或启用追踪补偿自转。":
    "Adapt by lowering power, refocusing or enabling tracking when conditions change.",
  "追踪速度匹配天体周日运动，让目标稳定停留在视野中央。":
    "Tracking matches the sky's apparent motion and keeps the target centered.",
  "主镜必须是抛物面而非球面，否则边缘光线汇聚到不同位置，产生球差。":
    "A Newtonian primary must be parabolic to bring edge and central rays to one focus.",
  "副镜与蜘蛛支架挡住约 4% 的入射光，并在亮星周围产生四条衍射星芒。":
    "The secondary and spider block a small part of the aperture and create diffraction spikes.",
  "常见焦比 f/4–f/8。焦比越小，视野越亮越广，但准直要求越高。":
    "Typical Newtonian focal ratios run from f/4 to f/8; faster systems demand tighter collimation.",
  "准直：调整主镜与副镜倾角，使光轴与目镜严格同轴。反射镜的日常功课。":
    "Collimation aligns the primary, secondary and eyepiece on one optical axis.",
  "集光面积正比于口径平方：口径翻倍，进光量变为四倍。":
    "Light-gathering power scales with aperture area: twice the diameter gathers four times the light.",
  "业余多布森常见口径 200–500 毫米，远大于同价位赤道仪镜。":
    "Amateur Dobsonians commonly use 200 to 500 mm apertures at relatively low cost.",
  "经纬式两轴：一轴上下，一轴左右，结构最简单。":
    "The simple altitude-azimuth mount moves vertically on one axis and horizontally on the other.",
  "没有电动跟踪，天体因自转漂出视野，需手动轻推保持居中。":
    "Without motorized tracking, the observer gently nudges the telescope to follow the sky.",
  "18 块六边形铍镜拼成 6.5 米口径，集光面积约 25 平方米。":
    "Eighteen hexagonal beryllium segments form a 6.5 m primary with about 25 square metres of collecting area.",
  "五层聚酰亚胺薄膜，层间真空隔热，逐层把热量向外辐射掉。":
    "Five separated polyimide layers radiate heat away through the vacuum of space.",
  "镜面工作温度低于 50 K，中红外仪器需进一步制冷到约 7 K。":
    "The mirrors work below 50 K, while the mid-infrared instrument is cooled to about 7 K.",
  "日地系统第二拉格朗日点，太阳、地球、月球同处一侧。":
    "At Sun-Earth L2, the Sun, Earth and Moon remain on the observatory's shielded side.",
  "500 米球面反射面，由 4450 块三角形铝面板拼成，铺在喀斯特洼地中。":
    "A 500 m spherical surface of 4,450 triangular aluminium panels, set into a karst depression.",
  "任一时刻只有约 300 米区域被拉成抛物面参与工作。":
    "Only an approximately 300 m region is shaped into the working paraboloid at any moment.",
  "促动器实时调整索网节点，面形误差控制在毫米量级。":
    "Actuators reshape cable-net nodes in real time with millimetre-scale accuracy.",
  "馈源舱重约 30 吨，由六根钢索悬吊，定位精度毫米级。":
    "The roughly 30 tonne feed cabin hangs on six steel cables with millimetre positioning accuracy.",
};

const missingTooltips = [];
let tooltipCount = 0;
html = html.replace(/data-tip="([^"]*)"/g, (whole, zh) => {
  const en = TOOLTIPS_EN[zh];
  if (!en) {
    missingTooltips.push(zh);
    return whole;
  }
  tooltipCount += 1;
  return `data-tip="${en}" data-tip-en="${en}" data-tip-zh="${zh}"`;
});
if (missingTooltips.length > 0) {
  throw new Error(
    `No English tooltip for:\n  - ${missingTooltips.join("\n  - ")}\n` +
      `Add these to TOOLTIPS_EN in tools/import_user_landing.mjs.`,
  );
}
applied.push(`${tooltipCount} bilingual tooltips`);

replaceOnce(
  "    document.title = TITLES[l];",
  `    document.title = TITLES[l];
    document.querySelectorAll('[data-tip-en]').forEach(function(el){
      el.setAttribute('data-tip', el.getAttribute(l === 'zh' ? 'data-tip-zh' : 'data-tip-en'));
    });`,
  "tooltips follow the language switch",
);

// --- anonymous visitor counter --------------------------------------------
// Backed by the Durable Object in cloudflare/worker.mjs at /api/visits.

if (html.includes("gnav-visits")) {
  throw new Error("The source website already defines a visitor counter.");
}
replaceOnce(
  "</style>",
  `  .gnav-visits{
    color:var(--txt-low);font-family:var(--mono);font-size:10px;
    letter-spacing:.14em;white-space:nowrap;padding:0 8px;
  }
  .gnav-visits b{color:var(--gold-soft);font-weight:600;font-variant-numeric:tabular-nums}
  @media (max-width:980px){.gnav-visits{display:none}}
</style>`,
  "visitor counter styles",
);
replaceOnce(
  '  <a class="gnav-play"',
  '  <span class="gnav-visits" aria-live="polite">VISITORS <b id="visitor-count">--</b></span>\n  <a class="gnav-play"',
  "visitor counter markup",
);

const visitorScript = `

  /* ---------- anonymous visitor counter ---------- */
  var visitorCount = document.getElementById('visitor-count');
  if(visitorCount){
    var visitorKey = 'pixel-observatory-visitor-id';
    var visitorId = localStorage.getItem(visitorKey);
    if(!visitorId){
      visitorId = (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random())
        .replace(/[^a-zA-Z0-9_-]/g,'');
      localStorage.setItem(visitorKey, visitorId);
    }
    var visitorEndpoint = location.hostname.endsWith('github.io')
      ? 'https://pixelobservatorygame.com/api/visits'
      : '/api/visits';
    fetch(visitorEndpoint,{
      method:'POST',
      headers:{'content-type':'application/json'},
      body:JSON.stringify({visitorId:visitorId})
    }).then(function(response){
      if(!response.ok) throw new Error('visitor counter unavailable');
      return response.json();
    }).then(function(data){
      var start = Number(visitorCount.textContent) || 0;
      var began = performance.now();
      function update(now){
        var progress = Math.min(1,(now-began)/600);
        var eased = 1-Math.pow(1-progress,3);
        visitorCount.textContent = Math.round(start+(data.total-start)*eased).toLocaleString();
        if(progress<1) requestAnimationFrame(update);
      }
      requestAnimationFrame(update);
    }).catch(function(){ visitorCount.textContent = '--'; });
  }
`;
const scriptEnd = html.lastIndexOf("})();");
if (scriptEnd < 0) {
  throw new Error("Could not locate the landing page script closure.");
}
html = html.slice(0, scriptEnd) + visitorScript + html.slice(scriptEnd);
applied.push("visitor counter client");

// --- write landing sources -------------------------------------------------

await writeFile(outputPath, html);

// Website imagery lives beside the page and is published at /img/.
await mkdir(join(landingDir, "img"), { recursive: true });
await cp(join(packageDir, "img"), join(landingDir, "img"), {
  recursive: true,
  force: true,
});

// Keep Godot's importer out of website-only imagery.
await writeFile(join(landingDir, "img", ".gdignore"), "");

// Root-level site files, copied verbatim so the shell publishes them at /.
for (const file of ["CNAME", "robots.txt", "sitemap.xml"]) {
  await cp(join(packageDir, file), join(landingDir, file), { force: true });
}

console.log(`Imported ${sourcePath}\n      into ${outputPath}`);
for (const label of applied) console.log(`  applied: ${label}`);
console.log("  copied: img/, CNAME, robots.txt, sitemap.xml");
