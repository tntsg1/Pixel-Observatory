import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(new URL("../package.json", import.meta.url)));
const artifactsDir = join(root, "artifacts", "research");
const sessionName = `research-text-route-${process.pid}`;
const npxCli = join(dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js");
const sessionStorageKey = "pixel-observatory:research-session:v2";
const apiCalls = [];
const questions = [
  {
    id: "a-wide-view",
    prompt: { en: "Which view is most useful first?", zh: "开始时最适合使用哪种视野？" },
    options: [
      { id: "finder", en: "A wide finder view", zh: "宽广的寻星镜视野" },
      { id: "narrow", en: "The narrowest view", zh: "最窄的视野" },
    ],
  },
  {
    id: "a-focus",
    prompt: { en: "What changes sharpness?", zh: "什么会改变清晰度？" },
    options: [
      { id: "focus", en: "The focuser", zh: "调焦器" },
      { id: "weather", en: "A weather label", zh: "天气标签" },
    ],
  },
  {
    id: "a-alignment",
    prompt: { en: "What should share a target?", zh: "什么应该指向同一目标？" },
    options: [
      { id: "aligned", en: "Finder and main telescope", zh: "寻星镜和主望远镜" },
      { id: "unrelated", en: "Two unrelated targets", zh: "两个无关目标" },
    ],
  },
];

const researchState = {
  participantId: "RSP-TEXT-ROUTE",
  language: "en",
  routeArm: "archive_text",
  currentNode: "A",
  completedNodes: ["baseline"],
  deferCounts: { A: 0 },
  lateResponseCount: 0,
  crossExposed: false,
  withdrawn: false,
  questions,
  rewardOffer: null,
};

const [pageHtml, studyEntry, studyScript, studyStyles, researchContent] = await Promise.all([
  readFile(join(root, "web", "landing", "study", "index.html")),
  readFile(join(root, "web", "landing", "study-entry.txt")),
  readFile(join(root, "web", "landing", "study", "study.js")),
  readFile(join(root, "web", "landing", "study", "study.css")),
  readFile(join(root, "web", "landing", "study", "research-content.mjs")),
]);

await mkdir(artifactsDir, { recursive: true });
const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url || "/", "http://127.0.0.1");
    if (request.method === "POST" && url.pathname.startsWith("/api/research/")) {
      const body = await requestJson(request);
      apiCalls.push({ path: url.pathname, body });
      return handleResearchApi(url.pathname, body, response);
    }
    if (url.pathname === "/study/") return send(response, 200, "text/html; charset=utf-8", studyEntry);
    if (url.pathname === "/study/index.html") return send(response, 200, "text/html; charset=utf-8", pageHtml);
    if (url.pathname === "/study/study.js") return send(response, 200, "text/javascript; charset=utf-8", studyScript);
    if (url.pathname === "/study/study.css") return send(response, 200, "text/css; charset=utf-8", studyStyles);
    if (url.pathname === "/study/research-content.mjs") return send(response, 200, "text/javascript; charset=utf-8", researchContent);
    if (url.pathname === "/game/") {
      return send(response, 200, "text/html; charset=utf-8", "<!doctype html><title>Original Pixel Observatory</title><main>Original game opening</main>");
    }
    return send(response, 404, "text/plain; charset=utf-8", "Not found");
  } catch (error) {
    return send(response, 500, "text/plain; charset=utf-8", error instanceof Error ? error.stack || error.message : String(error));
  }
});

const origin = await listen(server);
let pageCodeStep = 0;

try {
  await cli("open", `${origin}/study/`);
  await cli("resize", "1024", "768");
  await cli("snapshot");
  await pageCode("await page.waitForSelector('[data-view=\"fresh-entry\"]');");
  await pageCode(`
    const state = await page.evaluate(() => ({
      language: document.documentElement.lang,
      surveyCount: document.querySelectorAll('[data-research-survey], [data-question]').length,
      hasEarlyTerms: /baseline|consent|archive_text/i.test(document.querySelector('#study-app')?.innerText || ''),
    }));
    if (state.language !== 'en' || state.surveyCount !== 0 || state.hasEarlyTerms) throw new Error('Fresh study entry exposed a pre-Level-1 research step: ' + JSON.stringify(state));
  `);
  await pageCode(`
    await page.locator('[data-action="start-opening"]').click();
    await page.waitForURL(/\\/game\\/\\?mode=study&research_intro=1&participant=local-prestudy-[^&]+&study_reset=\\d+/);
  `);
  await cli("go-back");
  await pageCode("await page.waitForSelector('[data-view=\"fresh-entry\"]'); await page.locator('[data-language=\"zh\"]').click();");
  await pageCode(`
    const text = await page.locator('#study-app').innerText();
    const language = await page.evaluate(() => document.documentElement.lang);
    if (language !== 'zh-CN' || text.includes('Start with the original observatory opening.')) throw new Error('Chinese fresh entry did not render.');
    await page.locator('[data-language="en"]').click();
  `);

  const restoredSession = JSON.stringify({
    participantId: "RSP-TEXT-ROUTE",
    token: "token-text-route",
    language: "en",
    noRemindSessionNodes: [],
  });
  await cli("localstorage-set", sessionStorageKey, restoredSession);
  await cli("reload");
  await cli("snapshot");
  await pageCode("await page.waitForSelector('[data-view=\"archive-text\"]');");
  await pageCode(`
    const state = await page.evaluate(() => ({
      title: document.querySelector('h1')?.textContent?.trim(),
      questions: document.querySelectorAll('[data-question]').length,
      forms: document.querySelectorAll('[data-research-survey]').length,
      simulations: document.querySelectorAll('canvas, iframe, [class*="mini-game"]').length,
    }));
    if (state.title !== 'Finding and Focusing' || state.questions !== 3 || state.forms !== 1 || state.simulations !== 0) {
      throw new Error('Restored archive route is incomplete: ' + JSON.stringify(state));
    }
  `);
  await pageCode(`
    await page.locator('[data-language="zh"]').click();
    const language = await page.evaluate(() => document.documentElement.lang);
    if (language !== 'zh-CN' || (await page.locator('h1').innerText()) === 'Finding and Focusing') throw new Error('Chinese archive module did not render.');
    await page.locator('[data-language="en"]').click();
  `);
  await pageCode(`await page.screenshot({ path: ${JSON.stringify(join(artifactsDir, "text-route-desktop.png"))}, fullPage: true });`);

  await pageCode(`
    await page.locator('[data-action="defer"]').focus();
    if (await page.evaluate(() => document.activeElement?.dataset.action) !== 'defer') throw new Error('Deferred-reminder control did not receive keyboard focus.');
  `);
  await cli("press", "Enter");
  await pageCode("await page.getByText('Reminder saved (1 of 2).').waitFor();");
  await pageCode("await page.locator('[data-action=\"defer\"]').click(); await page.getByText('Reminder saved (2 of 2).').waitFor();");
  await pageCode(`
    if (await page.locator('[data-action="defer"]').count()) throw new Error('A third defer action remained after the two-reminder limit.');
    await page.locator('[data-action="no-remind"]').click();
    await page.locator('#paused-title').waitFor();
    const stored = JSON.parse(await page.evaluate(key => localStorage.getItem(key), ${JSON.stringify(sessionStorageKey)}));
    const keys = Object.keys(stored).sort().join(',');
    if (keys !== 'language,noRemindSessionNodes,participantId,token' || !stored.noRemindSessionNodes.includes('A')) {
      throw new Error('No-reminder setting was not persisted narrowly: ' + JSON.stringify(stored));
    }
  `);
  await pageCode("await page.locator('.survey-paused [data-action=\"open-settings\"]').click(); await page.locator('.study-settings [data-action=\"enable-reminder\"]').click(); await page.waitForSelector('[data-research-survey]');");
  await pageCode(`
    if (await page.locator('[data-question]').count() !== 3) throw new Error('Settings did not restore the exact three-question survey.');
  `);

  await cli("resize", "390", "844");
  await pageCode(`
    await page.waitForTimeout(80);
    const dimensions = await page.evaluate(() => ({ width: innerWidth, scrollWidth: document.documentElement.scrollWidth }));
    if (dimensions.width !== 390 || dimensions.scrollWidth > dimensions.width + 1) throw new Error('Mobile layout overflow: ' + JSON.stringify(dimensions));
    await page.screenshot({ path: ${JSON.stringify(join(artifactsDir, "text-route-mobile.png"))}, fullPage: true });
  `);
  await cli("resize", "1024", "768");

  await pageCode("await page.locator('[data-action=\"ordinary-game\"]').click(); await page.getByText('primary comparison').waitFor();");
  assert.equal(apiCalls.filter(call => call.path === "/api/research/exposure").length, 1, "Ordinary game exposure must be recorded before the notice.");

  await pageCode("await page.evaluate(() => { window.__researchRewardOffers = []; window.addEventListener('po:research-reward-offer', event => window.__researchRewardOffers.push(event.detail)); });");
  await pageCode(`
    const questionFields = page.locator('[data-question]');
    for (let index = 0; index < await questionFields.count(); index += 1) {
      await questionFields.nth(index).locator('input[type="radio"]').first().check();
    }
    await page.locator('[data-research-survey] button[type="submit"]').click();
    await page.waitForSelector('[data-view="completed"]');
    const offers = await page.evaluate(() => window.__researchRewardOffers);
    if (offers.length !== 1 || offers[0].offerId !== 'RO-TEXT-A' || offers[0].nodeId !== 'A' || offers[0].candidates.length !== 3) {
      throw new Error('Reward offer event was not emitted with the API payload: ' + JSON.stringify(offers));
    }
  `);
  const submitCall = apiCalls.find(call => call.path === "/api/research/submit");
  assert.ok(submitCall, "Archive survey must submit a response.");
  assert.equal(Object.keys(submitCall.body.answers || {}).length, 3, "Archive survey must submit exactly three answers.");

  await pageCode("await page.locator('[data-action=\"open-withdrawal\"]').click(); await page.waitForSelector('[data-withdrawal-dialog][open]'); await page.locator('[data-action=\"confirm-withdrawal\"]').click(); await page.waitForSelector('[data-view=\"withdrawn\"]');");
  assert.equal(apiCalls.filter(call => call.path === "/api/research/withdraw").length, 1, "Withdrawal must require and send one confirmed request.");

  console.log("playwright research text route: ok");
} finally {
  await cli("close").catch(() => {});
  await closeServer(server);
}

function stateResponse() {
  return {
    ...researchState,
    completedNodes: [...researchState.completedNodes],
    deferCounts: { ...researchState.deferCounts },
    questions: researchState.currentNode === "A" ? questions : [],
    rewardOffer: researchState.rewardOffer ? { ...researchState.rewardOffer, candidates: [...researchState.rewardOffer.candidates] } : null,
  };
}

function handleResearchApi(path, body, response) {
  if (body.participantId !== "RSP-TEXT-ROUTE" || body.token !== "token-text-route") {
    return sendJson(response, 401, { message: "Research session not found." });
  }
  if (path === "/api/research/session") return sendJson(response, 200, { state: stateResponse() });
  if (path === "/api/research/defer") {
    researchState.deferCounts.A = Math.min(2, Number(researchState.deferCounts.A || 0) + 1);
    return sendJson(response, 200, { state: stateResponse(), deferCount: researchState.deferCounts.A });
  }
  if (path === "/api/research/exposure") {
    assert.equal(body.kind, "ordinary_game", "The text route must identify ordinary gameplay exposure.");
    researchState.crossExposed = true;
    return sendJson(response, 200, { state: stateResponse() });
  }
  if (path === "/api/research/submit") {
    assert.equal(body.nodeId, "A", "The restored archive route must submit its current node.");
    researchState.currentNode = null;
    researchState.completedNodes = ["baseline", "A", "B", "C", "D", "E"];
    researchState.rewardOffer = { offerId: "RO-TEXT-A", nodeId: "A", candidates: ["reward-a", "reward-b", "reward-c"] };
    return sendJson(response, 200, { state: stateResponse(), feedback: { nodeId: "A", recorded: true }, rewardOffer: researchState.rewardOffer });
  }
  if (path === "/api/research/withdraw") {
    researchState.withdrawn = true;
    researchState.currentNode = null;
    return sendJson(response, 200, { state: stateResponse(), eventId: "RE-WITHDRAW-TEXT" });
  }
  return sendJson(response, 404, { message: "Unknown research test endpoint." });
}

function send(response, status, contentType, body) {
  response.writeHead(status, { "Content-Type": contentType, "Cache-Control": "no-store" });
  response.end(body);
}

function sendJson(response, status, body) {
  send(response, status, "application/json; charset=utf-8", JSON.stringify(body));
}

function requestJson(request) {
  return new Promise((resolve, reject) => {
    let payload = "";
    request.setEncoding("utf8");
    request.on("data", chunk => { payload += chunk; });
    request.on("end", () => {
      try {
        resolve(payload ? JSON.parse(payload) : {});
      } catch (error) {
        reject(error);
      }
    });
    request.on("error", reject);
  });
}

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      server.off("error", reject);
      const address = server.address();
      resolve(`http://127.0.0.1:${address.port}`);
    });
  });
}

function closeServer(server) {
  return new Promise(resolve => server.close(() => resolve()));
}

function cli(...args) {
  return new Promise((resolve, reject) => {
    const command = process.platform === "win32" ? process.execPath : "npx";
    const commandArgs = process.platform === "win32"
      ? [npxCli, "--yes", "--package", "@playwright/cli", "playwright-cli", `-s=${sessionName}`, ...args]
      : ["--yes", "--package", "@playwright/cli", "playwright-cli", `-s=${sessionName}`, ...args];
    const child = spawn(command, commandArgs, {
      cwd: root,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", chunk => { stdout += chunk; });
    child.stderr.on("data", chunk => { stderr += chunk; });
    child.on("error", reject);
    child.on("close", code => {
      if (code === 0) resolve(stdout);
      else reject(new Error(`playwright-cli ${args[0]} failed (${code}):\n${stdout}${stderr}`));
    });
  });
}

async function pageCode(code) {
  const step = ++pageCodeStep;
  const filename = join(tmpdir(), `${sessionName}-${step}.mjs`);
  await writeFile(filename, `async page => { ${code} }`, "utf8");
  try {
    return await cli("run-code", "--filename", filename);
  } catch (error) {
    error.message = `Browser code step ${step} failed.\n${code}\n${error.message}`;
    throw error;
  } finally {
    await rm(filename, { force: true });
  }
}
