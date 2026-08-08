import { access, cp, mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";

const outputDir = resolve(process.argv[2] || "build/web");
const studyPack = resolve(process.argv[3] || join(outputDir, ".study-godot-export", "study.pck"));
const mainIndex = join(outputDir, "game", "index.html");
const studyDir = join(outputDir, "study", "game");

await Promise.all([access(mainIndex), access(studyPack)]).catch(() => {
	throw new Error("Build the main web shell and the study Godot PCK before creating the study shell.");
});

const source = await readFile(mainIndex, "utf8");
const configMatch = source.match(/const GODOT_CONFIG = (\{[^\n]+\});/);
if (!configMatch) throw new Error("Could not read GODOT_CONFIG from the main game shell.");
const mainConfig = JSON.parse(configMatch[1]);
const mainExecutable = String(mainConfig.executable || "");
const mainWasmKey = Object.keys(mainConfig.fileSizes || {}).find(key => key.endsWith("index.wasm"));
if (!mainExecutable || !mainWasmKey) throw new Error("The main game shell does not expose a reusable Godot runtime.");

await mkdir(studyDir, { recursive: true });
const publishedPack = join(studyDir, "study.pck");
await cp(studyPack, publishedPack);

const toWebPath = value => relative(studyDir, join(outputDir, "game", value)).split(sep).join("/");
const executable = toWebPath(mainExecutable);
const wasm = toWebPath(mainWasmKey);
const packSize = (await stat(publishedPack)).size;
const config = {
	args: [], canvasResizePolicy: 2, emscriptenPoolSize: Number(mainConfig.emscriptenPoolSize || 8),
	ensureCrossOriginIsolationHeaders: true, executable, experimentalVK: false,
	fileSizes: { "study.pck": packSize, [wasm]: Number(mainConfig.fileSizes[mainWasmKey]) },
	focusCanvas: true, gdextensionLibs: [], mainPack: "study.pck",
};

const engineScript = toWebPath("index.js");
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pixel Observatory Study Observatory</title>
<style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#03070f;color:#dcecff;font-family:system-ui,sans-serif}canvas{display:block;width:100%;height:100%;outline:0}.loading{position:fixed;inset:0;display:grid;place-items:center;background:#03070f;transition:opacity .35s ease}.loading[hidden]{opacity:0;pointer-events:none}.panel{width:min(420px,80vw);text-align:center}.mark{width:56px;height:56px;margin:0 auto 18px;border:1px solid #5fd8ff;border-radius:50%;box-shadow:0 0 30px #5fd8ff33;animation:pulse 1.8s ease-in-out infinite}.bar{height:3px;margin-top:18px;background:#142637;overflow:hidden}.bar i{display:block;width:10%;height:100%;background:#5fd8ff;box-shadow:0 0 15px #5fd8ff;transition:width .2s ease}@keyframes pulse{50%{transform:scale(.9);opacity:.55}}@media(prefers-reduced-motion:reduce){.mark{animation:none}}</style></head>
<body><canvas id="canvas" tabindex="0"></canvas><div class="loading" id="loading"><div class="panel"><div class="mark"></div><strong>CALIBRATING STUDY OBSERVATORY</strong><div class="bar"><i id="bar"></i></div></div></div>
<script src="${engineScript}"></script><script>const config=${JSON.stringify(config)};const engine=new Engine(config);const loading=document.getElementById('loading');const bar=document.getElementById('bar');engine.startGame({onProgress:(current,total)=>{if(total>0)bar.style.width=Math.round(current/total*100)+'%';}}).then(()=>{loading.hidden=true;document.getElementById('canvas').focus();}).catch(error=>{loading.querySelector('strong').textContent='OBSERVATORY STARTUP FAILED';console.error(error);});</script></body></html>`;

await writeFile(join(studyDir, "index.html"), html, "utf8");
console.log(`Published independent Godot study shell at ${join(studyDir, "index.html")}`);
