import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";

const [overlay, styles, builder, patcher, verifier] = await Promise.all([
  readFile(new URL("../web/landing/research-overlay.js", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/research-overlay.css", import.meta.url), "utf8"),
  readFile(new URL("./build_web_shell.mjs", import.meta.url), "utf8"),
  readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
  readFile(new URL("./verify_web_game_shell.mjs", import.meta.url), "utf8"),
]);

class Element {
  constructor(document, tagName) {
    this.document = document;
    this.tagName = tagName.toLowerCase();
    this.children = [];
    this.parentNode = null;
    this.className = "";
    this.dataset = {};
    this.attributes = {};
    this.listeners = new Map();
    this.disabled = false;
    this.checked = false;
    this.value = "";
    this.name = "";
    this.type = "";
    this.tabIndex = 0;
    this._textContent = "";
  }

  get textContent() {
    return this._textContent + this.children.map(child => child.textContent).join("");
  }

  set textContent(value) {
    this._textContent = String(value);
    this.children = [];
  }

  append(...items) {
    for (const item of items) {
      if (!item) continue;
      if (item.tagName === "#fragment") {
        this.append(...item.children);
        continue;
      }
      item.parentNode = this;
      this.children.push(item);
    }
  }

  remove() {
    if (!this.parentNode) return;
    this.parentNode.children = this.parentNode.children.filter(child => child !== this);
    this.parentNode = null;
  }

  setAttribute(name, value) {
    this.attributes[name] = String(value);
    if (name === "tabindex") this.tabIndex = Number(value);
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) || [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  async emit(type, event = {}) {
    for (const listener of this.listeners.get(type) || []) {
      await listener({ target: this, preventDefault() {}, ...event });
    }
  }

  click() {
    return this.emit("click");
  }

  focus() {
    this.document.activeElement = this;
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] || null;
  }

  querySelectorAll(selector) {
    const matches = [];
    const selectors = selector.split(",").map(value => value.trim());
    const visit = (node) => {
      for (const child of node.children) {
        if (selectors.some(value => matchesSelector(child, value))) matches.push(child);
        visit(child);
      }
    };
    visit(this);
    return matches;
  }
}

function matchesSelector(element, selector) {
  if (selector.startsWith(".")) return element.className.split(/\s+/).includes(selector.slice(1));
  const tag = selector.match(/^[a-z]+/i)?.[0]?.toLowerCase();
  if (tag && element.tagName !== tag) return false;
  if (selector.includes(":not([disabled])") && element.disabled) return false;
  if (selector.includes("[tabindex]") && !("tabindex" in element.attributes)) return false;
  if (selector.includes("[tabindex='-1']") && element.attributes.tabindex === "-1") return false;
  return Boolean(tag || selector.startsWith("[tabindex]"));
}

class Document {
  constructor() {
    this.body = new Element(this, "body");
    this.activeElement = this.body;
    this.listeners = new Map();
  }

  createElement(tagName) {
    return new Element(this, tagName);
  }

  createDocumentFragment() {
    return new Element(this, "#fragment");
  }

  querySelector(selector) {
    return this.body.querySelector(selector);
  }

  querySelectorAll(selector) {
    return this.body.querySelectorAll(selector);
  }

  contains(element) {
    return element === this.body || this.body.querySelectorAll("*").includes(element);
  }

  addEventListener(type, listener) {
    this.listeners.set(type, listener);
  }

  removeEventListener(type, listener) {
    if (this.listeners.get(type) === listener) this.listeners.delete(type);
  }
}

function createHarness({ stored = {}, locationSearch = "", responses = [] } = {}) {
  const document = new Document();
  const calls = [];
  const continuations = [];
  const storage = new Map([["pixel-observatory:research-session:v2", JSON.stringify(stored)]]);
  const windowListeners = new Map();
  const window = {
    document,
    location: { search: locationSearch, assign() {} },
    localStorage: {
      getItem(key) { return storage.get(key) || null; },
      setItem(key, value) { storage.set(key, String(value)); },
    },
    addEventListener(type, listener) { windowListeners.set(type, listener); },
    dispatchEvent(event) { return windowListeners.get(event.type)?.(event); },
    __poResearchContinue(payload) { continuations.push(payload); },
  };
  const fetch = async (url, init) => {
    const call = { url, method: init.method, body: init.body ? JSON.parse(init.body) : undefined };
    calls.push(call);
    const next = responses.shift();
    if (!next) throw new Error(`Unexpected request: ${call.method} ${call.url}`);
    const reply = typeof next === "function" ? await next(call) : next;
    if (reply instanceof Error) throw reply;
    return {
      ok: reply.ok !== false,
      status: reply.status || (reply.ok === false ? 500 : 200),
      json: async () => reply.body || {},
    };
  };
  vm.runInNewContext(overlay, {
    window,
    document,
    fetch,
    console,
    JSON,
    Date,
    CustomEvent: class CustomEvent { constructor(type, init = {}) { this.type = type; this.detail = init.detail; } },
  });
  return {
    window,
    document,
    calls,
    continuations,
    stored: () => JSON.parse(storage.get("pixel-observatory:research-session:v2") || "{}"),
  };
}

function findButton(document, label) {
  const button = document.querySelectorAll("button").find(element => element.textContent.includes(label));
  assert.ok(button, `Expected a ${label} button.`);
  return button;
}

async function answerAll(document) {
  for (let index = 0; index < 3; index += 1) {
    const choice = document.querySelectorAll("input")[0];
    assert.ok(choice, `Question ${index + 1} is visible.`);
    await choice.emit("change");
    await findButton(document, index === 2 ? "Submit" : "Next").click();
  }
}

function questions(language, nodeId) {
  return Array.from({ length: 3 }, (_, index) => ({
    id: `${nodeId}-${index + 1}`,
    prompt: { en: `English ${nodeId} prompt ${index + 1}`, zh: `Chinese ${nodeId} question ${index + 1}` },
    options: Array.from({ length: 4 }, (_, option) => ({
      id: `${nodeId}-${index + 1}-${option + 1}`,
      en: `English option ${option + 1}`,
      zh: `Chinese option ${option + 1}`,
    })),
  }));
}

const baselineState = {
  participantId: "RSP-1",
  language: "zh",
  currentNode: "baseline",
  completedNodes: [],
  deferCounts: {},
  withdrawn: false,
  questions: questions("zh", "baseline"),
  rewardOffer: null,
};
const fieldWaitingState = {
  ...baselineState,
  routeArm: "field_gameplay",
  currentNode: null,
  completedNodes: ["baseline"],
  questions: [],
};
const fieldAState = {
  ...fieldWaitingState,
  currentNode: "A",
  questions: questions("zh", "A"),
};

const study = createHarness({ responses: [
  { status: 201, body: { participantId: "RSP-1", token: "token-1", state: baselineState } },
  { body: { state: fieldWaitingState, rewardOffer: { offerId: "RO-BASE", nodeId: "baseline", candidates: ["R01", "R02", "R03"] } } },
  { body: { receiptToken: "receipt-base", bundleId: "R01", prestigeLevel: 1 } },
  { body: { state: fieldWaitingState } },
  { body: { state: fieldAState, checkpoint: { level: 6, nodeId: "A" } } },
  { ok: false, status: 503, body: { error: "temporary outage" } },
  { body: {
    state: { ...fieldAState, currentNode: null, completedNodes: ["baseline", "A"], questions: [] },
    rewardOffer: { offerId: "RO-A", nodeId: "A", candidates: ["R04", "R05", "R06"] },
  } },
  { body: { receiptToken: "receipt-a", bundleId: "R05", prestigeLevel: 2 } },
] });

await study.window.PixelObservatoryResearch.handleCheckpoint({ detail: { nodeId: "baseline", completedLevel: 1, language: "zh" } });
assert.match(study.document.body.textContent, /Join the study/, "L1 dispatch offers the invitation without a local eligibility precheck.");
await findButton(study.document, "Join the study").click();
assert.match(study.document.body.textContent, /Chinese baseline question 1/, "Bilingual question objects render in the current game language.");
assert.doesNotMatch(study.document.body.textContent, /\[object Object\]/, "Question objects never stringify as objects.");
assert.deepEqual(study.stored(), { participantId: "RSP-1", token: "token-1" }, "Only server credentials are persisted after enrollment.");
await answerAll(study.document);
assert.equal(study.document.querySelectorAll(".po-research-reward-card").length, 3, "Baseline completion presents exactly three research-only cosmetic bundles.");
await findButton(study.document, "Solar Crown").click();
assert.match(study.document.body.textContent, /Research Prestige 1/, "A confirmed baseline reward shows its separate research prestige level.");
await findButton(study.document, "Continue").click();
assert.match(study.document.body.textContent, /Study route ready/, "The server assignment is shown after baseline confirmation.");
await findButton(study.document, "Continue gameplay").click();
assert.deepEqual(study.continuations, [JSON.stringify({ nodeId: "baseline" })], "Baseline continuation sends the exact pending bridge node as JSON.");

await study.window.PixelObservatoryResearch.handleCheckpoint({ detail: { nodeId: "A", completedLevel: 6, language: "zh" } });
assert.equal(study.window.PixelObservatoryResearch.hasVerifiedGameplaySession(), true, "Only successful field-session/checkpoint state enables a gameplay questionnaire.");
assert.match(study.document.body.textContent, /Chinese A question 1/, "Checkpoint questions use the active language.");
await answerAll(study.document);
assert.match(study.document.body.textContent, /Could not save your answers/, "A failed submit keeps the survey open for retry.");
assert.deepEqual(study.stored().pendingSubmission.answers, {
  "A-1": "A-1-1",
  "A-2": "A-2-1",
  "A-3": "A-3-1",
}, "Failed submissions retain selected answers locally.");
await findButton(study.document, "Retry").click();
await answerAll(study.document);
assert.equal(study.document.querySelectorAll(".po-research-reward-card").length, 3, "A gameplay checkpoint also presents three reward choices after a successful retry.");
await findButton(study.document, "Aurora Navigator").click();
assert.match(study.document.body.textContent, /Research Prestige 2/, "Gameplay reward confirmation advances the research prestige presentation.");
await findButton(study.document, "Return to the stars").click();
assert.deepEqual(study.continuations, [JSON.stringify({ nodeId: "baseline" }), JSON.stringify({ nodeId: "A" })], "Successful retry resumes the exact pending gameplay node.");
assert.equal(study.stored().pendingSubmission, undefined, "Answers clear only after server-confirmed submission.");

assert.deepEqual(study.calls.map(call => [call.url, call.method]), [
  ["/api/research/enroll", "POST"],
  ["/api/research/submit", "POST"],
  ["/api/research/reward/choose", "POST"],
  ["/api/research/session", "POST"],
  ["/api/research/checkpoint", "POST"],
  ["/api/research/submit", "POST"],
  ["/api/research/submit", "POST"],
  ["/api/research/reward/choose", "POST"],
], "The overlay uses the worker's POST-only research API.");
assert.deepEqual(study.calls[2].body, {
  participantId: "RSP-1", token: "token-1", offerId: "RO-BASE", bundleId: "R01",
}, "Reward choice is authenticated and can only consume the offered bundle.");
assert.deepEqual(study.calls[3].body, { participantId: "RSP-1", token: "token-1" }, "Session refresh is authenticated at the top level.");
assert.deepEqual(study.calls[4].body, { participantId: "RSP-1", token: "token-1", level: 6 }, "Checkpoint posts authenticated top-level level data from Godot.");
assert.deepEqual({ ...study.calls[1].body, durationSeconds: 0 }, {
  participantId: "RSP-1", token: "token-1", nodeId: "baseline",
  answers: { "baseline-1": "baseline-1-1", "baseline-2": "baseline-2-1", "baseline-3": "baseline-3-1" },
  durationSeconds: 0,
}, "Baseline submit uses the server's current node and authenticated answer payload.");
assert.ok(Number.isInteger(study.calls[1].body.durationSeconds) && study.calls[1].body.durationSeconds >= 0, "Submit records a non-negative duration in seconds.");
assert.deepEqual(study.calls[6].body, {
  ...study.calls[6].body,
  participantId: "RSP-1",
  token: "token-1",
  nodeId: "A",
  answers: { "A-1": "A-1-1", "A-2": "A-2-1", "A-3": "A-3-1" },
}, "Retry resends authenticated preserved answers for the current server node.");
assert.deepEqual(study.stored().rewardReceipts, undefined, "Research reward receipts stay isolated from the questionnaire credential record.");
assert.deepEqual(JSON.parse(study.window.localStorage.getItem("pixel-observatory:research-receipts:v1")), [
  { receiptToken: "receipt-base", bundleId: "R01" },
  { receiptToken: "receipt-a", bundleId: "R05" },
], "Confirmed guest rewards are preserved as opaque receipts for later account claiming.");

const checkpointWaitingState = {
  ...fieldWaitingState,
  participantId: "RSP-3",
  language: "en",
};
const checkpointAState = {
  ...checkpointWaitingState,
  currentNode: "A",
  questions: questions("en", "A"),
};
const checkpointAfterAState = {
  ...checkpointWaitingState,
  completedNodes: ["baseline", "A"],
};
const checkpointBState = {
  ...checkpointAfterAState,
  currentNode: "B",
  questions: questions("en", "B"),
};
const checkpointFlow = createHarness({
  stored: { participantId: "RSP-3", token: "token-3" },
  responses: [
    { body: { state: checkpointWaitingState } },
    { body: { state: checkpointWaitingState } },
    { body: { state: checkpointAState, checkpoint: { level: 6, nodeId: "A" } } },
    { body: { state: checkpointAfterAState } },
    { body: { state: checkpointAfterAState } },
    { body: { state: checkpointBState, checkpoint: { level: 11, nodeId: "B" } } },
  ],
});

await checkpointFlow.window.PixelObservatoryResearch.refreshResearchSession();
assert.equal(
  checkpointFlow.window.PixelObservatoryResearch.hasVerifiedGameplaySession(),
  true,
  "A server-refreshed, post-baseline field session permits bridge dispatch while currentNode is null.",
);
await checkpointFlow.window.PixelObservatoryResearch.handleCheckpoint({ detail: { nodeId: "A", completedLevel: 6 } });
assert.deepEqual(checkpointFlow.calls.slice(0, 3), [
  { url: "/api/research/session", method: "POST", body: { participantId: "RSP-3", token: "token-3" } },
  { url: "/api/research/session", method: "POST", body: { participantId: "RSP-3", token: "token-3" } },
  { url: "/api/research/checkpoint", method: "POST", body: { participantId: "RSP-3", token: "token-3", level: 6 } },
], "Bridge dispatch records an authenticated Level 6 checkpoint after its pre-dispatch session refresh.");
assert.match(checkpointFlow.document.body.textContent, /English A prompt 1/, "The Level 6 checkpoint response opens node A questions.");
await answerAll(checkpointFlow.document);
assert.deepEqual(checkpointFlow.continuations, [JSON.stringify({ nodeId: "A" })], "Submitting A resumes the Level 6 bridge continuation.");
assert.equal(
  checkpointFlow.window.PixelObservatoryResearch.hasVerifiedGameplaySession(),
  true,
  "The post-A field state still permits Level 11 dispatch while it waits with currentNode null.",
);
await checkpointFlow.window.PixelObservatoryResearch.handleCheckpoint({ detail: { nodeId: "B", completedLevel: 11 } });
assert.deepEqual(checkpointFlow.calls.slice(4, 6), [
  { url: "/api/research/session", method: "POST", body: { participantId: "RSP-3", token: "token-3" } },
  { url: "/api/research/checkpoint", method: "POST", body: { participantId: "RSP-3", token: "token-3", level: 11 } },
], "The same verified session dispatches an authenticated Level 11 checkpoint after A.");
assert.match(checkpointFlow.document.body.textContent, /English B prompt 1/, "The Level 11 checkpoint response opens node B questions.");

const deferredState = { ...fieldAState, participantId: "RSP-2", currentNode: "B", deferCounts: { B: 1 }, questions: questions("zh", "B") };
const deferral = createHarness({ stored: { participantId: "RSP-2", token: "token-2", baselineComplete: true, routeArm: "field_gameplay" }, responses: [
  { body: { state: deferredState } },
  { body: { state: deferredState, checkpoint: { level: 16, nodeId: "C" } } },
  { body: { state: { ...deferredState, deferCounts: { B: 2 } }, deferCount: 2 } },
] });
await deferral.window.PixelObservatoryResearch.handleCheckpoint({ detail: { nodeId: "C", completedLevel: 16, language: "zh" } });
await findButton(deferral.document, "Later").click();
assert.deepEqual(deferral.calls, [
  { url: "/api/research/session", method: "POST", body: { participantId: "RSP-2", token: "token-2" } },
  { url: "/api/research/checkpoint", method: "POST", body: { participantId: "RSP-2", token: "token-2", level: 16 } },
  { url: "/api/research/defer", method: "POST", body: { participantId: "RSP-2", token: "token-2", nodeId: "B" } },
], "Deferral is authenticated and targets the current server node, not the checkpoint node.");
assert.match(deferral.document.body.textContent, /Stop reminders for this session/, "The second Later offers a session-only silence action.");
await findButton(deferral.document, "Stop reminders for this session").click();
assert.deepEqual(deferral.continuations, [JSON.stringify({ nodeId: "C" })], "Deferral still resumes the bridge's pending checkpoint node.");
assert.equal(deferral.stored().sessionSilenced, undefined, "Session-only reminder silence is never persisted.");
deferral.window.PixelObservatoryResearch.openSettings();
await findButton(deferral.document, "Enable reminders").click();
assert.equal(deferral.calls.length, 3, "Settings clears local reminder silence without inventing a server payload.");

const forged = createHarness({
  stored: { participantId: "forged", token: "forged", baselineComplete: true, declined: false, routeArm: "field_gameplay" },
  locationSearch: "?participantId=forged&token=forged&routeArm=field_gameplay",
  responses: [{ ok: false, status: 401, body: { error: "invalid_research_session" } }],
});
assert.equal(forged.window.PixelObservatoryResearch.hasVerifiedGameplaySession(), false, "Local storage and URL values without a successful session refresh cannot pass bridge permission.");
await forged.window.PixelObservatoryResearch.handleCheckpoint({ detail: { nodeId: "A", completedLevel: 6 } });
assert.equal(forged.window.PixelObservatoryResearch.hasVerifiedGameplaySession(), false, "Forged URL and storage values cannot create verified gameplay eligibility.");
assert.doesNotMatch(forged.document.body.textContent, /English A prompt|Chinese A question/, "Forged browser state cannot unlock questions.");
assert.deepEqual(forged.continuations, [JSON.stringify({ nodeId: "A" })], "Rejected browser state falls through to the game.");

// Supplementary build-shell assertions; behavior above is the protocol coverage.
assert.match(overlay, /observatory:research-checkpoint/);
assert.match(overlay, /JSON\.stringify\(\{ nodeId/);
assert.match(styles, /prefers-reduced-motion:\s*reduce/);
assert.match(builder, /research-overlay\.js/);
assert.match(patcher, /research-overlay\.js/);
assert.match(verifier, /research-overlay\.js/);

console.log("research overlay contract: ok");
