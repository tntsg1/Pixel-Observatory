import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const sourcePath = resolve(
  process.argv[2] || "C:/Users/tntsg/Desktop/星光天文台官网.html",
);
const outputPath = resolve(process.argv[3] || "web/landing/promo.html");
let html = await readFile(sourcePath, "utf8");

html = html.replaceAll(
  "https://tntsg1.github.io/Pixel-Observatory/",
  "game/",
);

html = html.replace(
  "  @media (max-width:760px){.gnav-links{display:none}}",
  `  .gnav-visits{
    color:var(--txt-low);font-family:var(--mono);font-size:10px;
    letter-spacing:.14em;white-space:nowrap;padding:0 8px;
  }
  .gnav-visits b{color:var(--gold-soft);font-weight:600}
  @media (max-width:900px){.gnav-visits{display:none}}
  @media (max-width:760px){.gnav-links{display:none}}`,
);

html = html.replace(
  '  <a class="gnav-play"',
  '  <span class="gnav-visits" aria-live="polite">VISITORS <b id="visitor-count">--</b></span>\n  <a class="gnav-play"',
);

const visitorScript = `

  /* ---- anonymous visitor counter ---- */
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
    }).catch(function(){ visitorCount.textContent = '—'; });
  }
`;

const scriptEnd = html.lastIndexOf("})();");
if (scriptEnd < 0) {
  throw new Error("Could not locate the landing page script closure.");
}
html = html.slice(0, scriptEnd) + visitorScript + html.slice(scriptEnd);

await writeFile(outputPath, html);
console.log(`Imported ${sourcePath} into ${outputPath}`);
