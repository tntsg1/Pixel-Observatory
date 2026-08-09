import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { QUESTION_FORMS, TEXT_ARCHIVE_MODULES } from "../web/landing/study/research-content.mjs";

const root = dirname(fileURLToPath(new URL("../package.json", import.meta.url)));
const artifactsDir = join(root, "artifacts", "research");
const sessionName = `research-text-route-${process.pid}`;
const npxCli = join(dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js");
const sessionStorageKey = "pixel-observatory:research-session:v2";
const nodeIds = ["A", "B", "C", "D", "E"];
const apiCalls = [];
const submissions = [];
const nodeFixtures = Object.fromEntries(nodeIds.map(nodeId => {
  const form = QUESTION_FORMS[nodeId]?.[0];
  assert.ok(form, `Missing public research form fixture for node ${nodeId}.`);
  assert.equal(form.questions.length, 3, `${nodeId} must expose exactly three questions.`);
  for (const question of form.questions) {
    assert.equal(question.options.length, 4, `${nodeId}/${question.id} must expose exactly four options.`);
  }
  assert.ok(TEXT_ARCHIVE_MODULES[nodeId], `Missing archive text module for node ${nodeId}.`);
  return [nodeId, Object.freeze({
    title: TEXT_ARCHIVE_MODULES[nodeId].title.en,
    questions: form.questions,
  })];
}));

const researchState = {
  activeNodeIndex: 0,
  completedNodes: ["baseline"],
  deferCounts: Object.fromEntries(nodeIds.map(nodeId => [nodeId, 0])),
  crossExposed: false,
  withdrawn: false,
  lastRewardOffer: null,
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
  await pageCode("await page.evaluate(() => { window.__researchRewardOffers = []; window.addEventListener('po:research-reward-offer', event => window.__researchRewardOffers.push(event.detail)); });");

  await assertCurrentNode("A");
  await pageCode(`
    await page.locator('[data-language="zh"]').click();
    const language = await page.evaluate(() => document.documentElement.lang);
    if (language !== 'zh-CN' || (await page.locator('h1').innerText()) === ${JSON.stringify(nodeFixtures.A.title)}) throw new Error('Chinese archive module did not render.');
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
    await page.evaluate(() => {
      window.__researchRealDateNow = Date.now;
      window.__researchNow = Date.now();
      Date.now = () => window.__researchNow + 61_000;
    });
  `);
  await pageCode("await page.locator('.survey-paused [data-action=\"open-settings\"]').click(); await page.locator('.study-settings [data-action=\"enable-reminder\"]').click(); await page.waitForSelector('[data-research-survey]');");
  await assertCurrentNode("A");
  await pageCode(`
    await page.waitForTimeout(80);
    const dimensions = await page.evaluate(() => ({ width: innerWidth, scrollWidth: document.documentElement.scrollWidth }));
    if (dimensions.width !== 1024 || dimensions.scrollWidth > dimensions.width + 1) throw new Error('Desktop layout overflow: ' + JSON.stringify(dimensions));
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

  await submitCurrentNode("A", 0, 2);
  await assertCurrentNode("B");
  await submitCurrentNode("B", 1);
  await assertCurrentNode("C");
  await submitCurrentNode("C", 2);
  await assertCurrentNode("D");
  await submitCurrentNode("D", 3);
  await assertCurrentNode("E");
  await submitCurrentNode("E", 4);
  await pageCode("await page.waitForSelector('[data-view=\"completed\"]'); await page.evaluate(() => { Date.now = window.__researchRealDateNow; delete window.__researchRealDateNow; delete window.__researchNow; });");

  assert.deepEqual(researchState.completedNodes, ["baseline", "A", "B", "C", "D", "E"], "Mock session must advance strictly through each text node.");
  assert.equal(submissions.length, 5, "Each A-E archive survey must submit once.");
  assert.deepEqual(submissions.map(submission => submission.nodeId), nodeIds, "Submissions must preserve A-to-E order.");

  await pageCode("await page.locator('[data-action=\"open-withdrawal\"]').click(); await page.waitForSelector('[data-withdrawal-dialog][open]'); await page.locator('[data-action=\"confirm-withdrawal\"]').click(); await page.waitForSelector('[data-view=\"withdrawn\"]');");
  assert.equal(apiCalls.filter(call => call.path === "/api/research/withdraw").length, 1, "Withdrawal must require and send one confirmed request.");

  console.log("playwright research text route: ok");
} finally {
  await cli("close").catch(() => {});
  await closeServer(server);
}

async function assertCurrentNode(nodeId) {
  const fixture = nodeFixtures[nodeId];
  await pageCode(`
    await page.waitForSelector('[data-view="archive-text"]');
    const expectedTitle = ${JSON.stringify(fixture.title)};
    const state = await page.evaluate(expectedTitle => {
      const questions = [...document.querySelectorAll('[data-question]')].map(question => ({
        optionCount: question.querySelectorAll('input[type="radio"]').length,
        labelCount: question.querySelectorAll('.option').length,
      }));
      return {
        title: document.querySelector('h1')?.textContent?.trim(),
        formCount: document.querySelectorAll('[data-research-survey]').length,
        questions,
        simulations: document.querySelectorAll('canvas, iframe, [class*="mini-game"]').length,
        overflow: document.documentElement.scrollWidth > innerWidth + 1,
      };
    }, expectedTitle);
    if (state.title !== expectedTitle || state.formCount !== 1 || state.questions.length !== 3 || state.questions.some(question => question.optionCount !== 4 || question.labelCount !== 4) || state.simulations !== 0 || state.overflow) {
      throw new Error('Four-option archive survey mismatch for ' + ${JSON.stringify(nodeId)} + ': ' + JSON.stringify(state));
    }
  `);
}

async function submitCurrentNode(nodeId, offerIndex, expectedDurationSeconds) {
  const expectedOffer = `RO-TEXT-${nodeId}`;
  await pageCode(`
    const questionFields = page.locator('[data-question]');
    if (await questionFields.count() !== 3) throw new Error('Expected three questions before keyboard submission for ${nodeId}.');
    for (let index = 0; index < await questionFields.count(); index += 1) {
      const options = questionFields.nth(index).locator('input[type="radio"]');
      if (await options.count() !== 4) throw new Error('Expected four options for ${nodeId} question ' + index + '.');
      await options.first().focus();
      await page.keyboard.press('ArrowDown');
      await page.keyboard.press('ArrowDown');
      await page.keyboard.press('ArrowDown');
      if (!await options.nth(3).isChecked()) throw new Error('Keyboard did not select the fourth option for ${nodeId} question ' + index + '.');
    }
    ${expectedDurationSeconds === undefined ? "" : "await page.evaluate(() => { Date.now = () => window.__researchNow + 63_000; });"}
    await page.locator('[data-research-survey] button[type="submit"]').click();
    await page.waitForFunction(expectedCount => window.__researchRewardOffers.length === expectedCount, ${offerIndex + 1});
    const offers = await page.evaluate(() => window.__researchRewardOffers);
    const offer = offers[${offerIndex}];
    if (offers.length !== ${offerIndex + 1} || !offer || offer.offerId !== ${JSON.stringify(expectedOffer)} || offer.nodeId !== ${JSON.stringify(nodeId)} || offer.candidates.length !== 3) {
      throw new Error('Reward offer event mismatch for ${nodeId}: ' + JSON.stringify(offers));
    }
  `);
  const submission = submissions[offerIndex];
  assert.ok(submission, `Missing recorded submission for ${nodeId}.`);
  assert.equal(submission.nodeId, nodeId, `Submitted node order is wrong for ${nodeId}.`);
  assert.equal(Object.keys(submission.answers).length, 3, `${nodeId} must submit exactly three answers.`);
  if (expectedDurationSeconds !== undefined) {
    assert.equal(submission.durationSeconds, expectedDurationSeconds, "Paused reminder time must not be included in A's answer duration.");
  }
}

function currentNodeId() {
  return nodeIds[researchState.activeNodeIndex] || null;
}

function stateResponse() {
  const nodeId = currentNodeId();
  return {
    participantId: "RSP-TEXT-ROUTE",
    language: "en",
    routeArm: "archive_text",
    currentNode: nodeId,
    completedNodes: [...researchState.completedNodes],
    deferCounts: { ...researchState.deferCounts },
    lateResponseCount: 0,
    crossExposed: researchState.crossExposed,
    withdrawn: researchState.withdrawn,
    questions: nodeId ? nodeFixtures[nodeId].questions : [],
    rewardOffer: researchState.lastRewardOffer,
  };
}

function handleResearchApi(path, body, response) {
  if (body.participantId !== "RSP-TEXT-ROUTE" || body.token !== "token-text-route") {
    return sendJson(response, 401, { message: "Research session not found." });
  }
  if (path === "/api/research/session") return sendJson(response, 200, { state: stateResponse() });
  if (path === "/api/research/defer") {
    const nodeId = currentNodeId();
    assert.equal(body.nodeId, nodeId, "Defer requests must target the current A-E node.");
    assert.ok(researchState.deferCounts[nodeId] < 2, "The mock refuses a third reminder.");
    researchState.deferCounts[nodeId] += 1;
    return sendJson(response, 200, { state: stateResponse(), deferCount: researchState.deferCounts[nodeId] });
  }
  if (path === "/api/research/exposure") {
    assert.ok(currentNodeId(), "Exposure cannot be recorded after the A-E route is complete.");
    assert.equal(body.kind, "ordinary_game", "The text route must identify ordinary gameplay exposure.");
    researchState.crossExposed = true;
    return sendJson(response, 200, { state: stateResponse() });
  }
  if (path === "/api/research/submit") {
    const nodeId = currentNodeId();
    assert.ok(nodeId, "The mock refuses a submission after E.");
    assert.equal(body.nodeId, nodeId, "Submit requests must target the current A-E node.");
    assertValidAnswers(nodeId, body.answers);
    const durationSeconds = Number(body.durationSeconds);
    assert.ok(Number.isFinite(durationSeconds) && durationSeconds >= 1, "Submissions need a positive duration.");
    submissions.push({ nodeId, answers: { ...body.answers }, durationSeconds });
    researchState.completedNodes.push(nodeId);
    researchState.activeNodeIndex += 1;
    researchState.lastRewardOffer = {
      offerId: `RO-TEXT-${nodeId}`,
      nodeId,
      candidates: [`reward-${nodeId}-a`, `reward-${nodeId}-b`, `reward-${nodeId}-c`],
    };
    return sendJson(response, 200, { state: stateResponse(), feedback: { nodeId, recorded: true }, rewardOffer: researchState.lastRewardOffer });
  }
  if (path === "/api/research/withdraw") {
    researchState.withdrawn = true;
    return sendJson(response, 200, { state: stateResponse(), eventId: "RE-WITHDRAW-TEXT" });
  }
  return sendJson(response, 404, { message: "Unknown research test endpoint." });
}

function assertValidAnswers(nodeId, answers) {
  const questions = nodeFixtures[nodeId].questions;
  assert.deepEqual(Object.keys(answers || {}).sort(), questions.map(question => question.id).sort(), `${nodeId} answer keys must match the current public form.`);
  for (const question of questions) {
    assert.ok(question.options.some(option => option.id === answers[question.id]), `${nodeId}/${question.id} received an option outside the current form.`);
  }
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
