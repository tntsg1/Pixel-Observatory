import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const sourcePath = resolve(
  process.argv[2] ||
    "C:/Users/tntsg/Desktop/\u661f\u5149\u5929\u6587\u53f0\u5b98\u7f51.html",
);
const outputPath = resolve(process.argv[3] || "web/landing/promo.html");
let html = await readFile(sourcePath, "utf8");

html = html
  .replace(/<html[^>]*>/i, '<html lang="en" data-lang="en">')
  .replace(/<title>[^<]*<\/title>/i, "<title>Starlight Observatory</title>")
  .replace(
    /<meta name="description"[^>]*>/i,
    '<meta name="description" content="Starlight Observatory is a pixel astronomy simulation. Build your telescope, read the sky, and discover more.">',
  )
  .replace(
    'html[data-lang="en"] .zh{display:none!important}',
    'html[data-lang="en"] .zh{display:none!important}\n  html[data-lang="en"] .pr h3 .lat{display:none!important}',
  )
  .replace(
    "transition:opacity .5s,transform .6s cubic-bezier(.22,1,.36,1);max-width:calc(100vw - 24px);",
    "transition:opacity .18s ease-out,transform .22s cubic-bezier(.23,1,.32,1);max-width:calc(100vw - 24px);",
  )
  .replaceAll("https://tntsg1.github.io/Pixel-Observatory/", "game/")
  .replace(
    '<h1>STARLIGHT OBSERVATORY<span class="sub">',
    '<h1>STARLIGHT OBSERVATORY<span class="sub zh">',
  )
  .replace(
    /(<p class="eyebrow rv" style="text-align:center">)Starlight Observatory[^<]*(<\/p>)/,
    '$1<span class="en">Starlight Observatory</span><span class="zh">&#26143;&#20809;&#22825;&#25991;&#21488;</span>$2',
  )
  .replace(
    /<b>STARLIGHT OBSERVATORY[^<]*<\/b>/,
    '<b><span class="en">STARLIGHT OBSERVATORY</span><span class="zh">&#26143;&#20809;&#22825;&#25991;&#21488;</span></b>',
  )
  .replace(
    /(<button[^>]+id="langZh"[^>]+aria-pressed=")true(")/,
    "$1false$2",
  )
  .replace(
    /(<button[^>]+id="langEn"[^>]+aria-pressed=")false(")/,
    "$1true$2",
  )
  .replace(
    /var TITLES = \{[^;]+;/,
    "var TITLES = {zh:'\\u661f\\u5149\\u5929\\u6587\\u53f0', en:'Starlight Observatory'};",
  )
  .replace(
    /setLang\(saved \|\| \(\(navigator\.language \|\| 'en'\)[^;]+;/,
    "setLang(saved || 'en', false);",
  )
  .replace(
    `  var lastY = 0, ticking = false;
  function onScroll(){
    var y = scrollY;
    if(!reduced && heroInner && y < innerHeight*1.2){
      heroInner.style.transform = 'translateY('+(y*.34)+'px)';
      heroInner.style.opacity = Math.max(0, 1 - y/(innerHeight*.72));
      heroCv.style.transform = 'translateY('+(y*.16)+'px)';
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
      heroInner.style.transform = 'translateY('+(y*.34)+'px)';
      heroInner.style.opacity = Math.max(0, 1 - y/(innerHeight*.72));
      heroCv.style.transform = 'translateY('+(y*.16)+'px)';
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
  onScroll();`,
  );

if (!html.includes('rel="icon"')) {
  html = html.replace(
    "</head>",
    `<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='8' fill='%2305070d'/%3E%3Cpath d='M16 4l2.4 8.3L27 16l-8.6 3.7L16 28l-2.4-8.3L5 16l8.6-3.7L16 4z' fill='%23d9a648'/%3E%3C/svg%3E">\n</head>`,
  );
}

const englishTooltips = [
  "Human horizontal vision approaches 120 degrees, the widest view used in this journey.",
  "The unaided eye reaches roughly magnitude 6; fainter objects require an instrument.",
  "About 30 minutes in darkness lets the pupil and rod cells reveal fainter stars.",
  "Focal length is the distance from the objective or primary mirror to its focus.",
  "Magnification equals telescope focal length divided by eyepiece focal length.",
  "Higher magnification narrows the field, revealing detail while making targets easier to lose.",
  "Aperture, focus and atmospheric stability all limit image sharpness.",
  "Earth rotates one degree every four minutes, so high-power targets drift quickly.",
  "Passing clouds can temporarily hide a target; waiting or changing targets are both valid choices.",
  "Turbulent air softens and shakes the image. High power works best under steady seeing.",
  "City glow raises the sky background and overwhelms faint objects.",
  "Adapt by lowering power, refocusing or enabling tracking when conditions change.",
  "Tracking matches the sky's apparent motion and keeps the target centered.",
  "A Newtonian primary must be parabolic to bring edge and central rays to one focus.",
  "The secondary and spider block a small part of the aperture and create diffraction spikes.",
  "Typical Newtonian focal ratios run from f/4 to f/8; faster systems demand tighter collimation.",
  "Collimation aligns the primary, secondary and eyepiece on one optical axis.",
  "Light-gathering power scales with aperture area: twice the diameter gathers four times the light.",
  "Amateur Dobsonians commonly use 200 to 500 mm apertures at relatively low cost.",
  "The simple altitude-azimuth mount moves vertically on one axis and horizontally on the other.",
  "Without motorized tracking, the observer gently nudges the telescope to follow the sky.",
  "Eighteen hexagonal beryllium segments form JWST's 6.5 m primary mirror.",
  "Five separated polyimide layers radiate heat away through the vacuum of space.",
  "The mirrors work below 50 K, while the mid-infrared instrument is cooled to about 7 K.",
  "At Sun-Earth L2, the Sun, Earth and Moon remain on the observatory's shielded side.",
  "FAST's 500 m spherical surface contains 4,450 triangular aluminum panels.",
  "Only an approximately 300 m region is shaped into the working paraboloid at any moment.",
  "Actuators reshape cable-net nodes in real time with millimeter-scale accuracy.",
  "The roughly 30 tonne feed cabin hangs about 140 m above the dish on six steel cables.",
];

let tooltipIndex = 0;
html = html.replace(/data-tip="([^"]*)"/g, (_, chineseTooltip) => {
  const englishTooltip = englishTooltips[tooltipIndex++];
  if (!englishTooltip) {
    throw new Error("The source website contains more tooltips than expected.");
  }
  return `data-tip="${englishTooltip}" data-tip-en="${englishTooltip}" data-tip-zh="${chineseTooltip}"`;
});
if (tooltipIndex !== englishTooltips.length) {
  throw new Error(
    `Expected ${englishTooltips.length} tooltips, found ${tooltipIndex}.`,
  );
}

html = html.replace(
  "    document.title = TITLES[l];",
  `    document.title = TITLES[l];
    document.querySelectorAll('[data-tip-en]').forEach(function(el){
      el.setAttribute('data-tip', el.getAttribute(l === 'zh' ? 'data-tip-zh' : 'data-tip-en'));
    });`,
);

if (!html.includes("gnav-visits")) {
  html = html.replace(
    "</style>",
    `  .gnav-visits{
    color:var(--txt-low);font-family:var(--mono);font-size:10px;
    letter-spacing:.14em;white-space:nowrap;padding:0 8px;
  }
  .gnav-visits b{color:var(--gold-soft);font-weight:600}
  @media (max-width:980px){.gnav-visits{display:none}}
</style>`,
  );
  html = html.replace(
    '  <a class="gnav-play"',
    '  <span class="gnav-visits" aria-live="polite">VISITORS <b id="visitor-count">--</b></span>\n  <a class="gnav-play"',
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
}

await writeFile(outputPath, html);
console.log(`Imported ${sourcePath} into ${outputPath}`);
