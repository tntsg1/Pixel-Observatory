import assert from "node:assert/strict";

const baseUrl = process.env.OBSERVATION_SHARE_TEST_URL || "http://127.0.0.1:8793";
const password = "ObservationShare!2026";
const suffix = `${Date.now().toString(36)}${Math.floor(Math.random() * 10_000)}`;
const testNetwork = 30 + Math.floor(Math.random() * 150);

function sessionCookie(response) {
  const raw = response.headers.get("set-cookie") || "";
  const match = raw.match(/(?:^|,\s*)(po_session=[^;]+)/);
  assert.ok(match, "Registration must return a session cookie.");
  return match[1];
}

async function api(path, options = {}, cookie = "", expectedStatus = 200) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      "content-type": "application/json",
      ...(cookie ? { cookie } : {}),
      ...(options.headers || {}),
    },
  });
  const data = await response.json().catch(() => ({}));
  assert.equal(response.status, expectedStatus, `${options.method || "GET"} ${path}: ${response.status} ${JSON.stringify(data)}`);
  return { response, data };
}

async function register(prefix, addressOctet) {
  const username = `${prefix}${suffix}`;
  const { response, data } = await api("/api/auth/register", {
    method: "POST",
    headers: { "X-Pixel-Observatory-Test-IP": `198.18.${testNetwork}.${addressOctet}` },
    body: JSON.stringify({ username, password, website: "", turnstileToken: "local-test" }),
  }, "", 201);
  return { username: data.user.username, cookie: sessionCookie(response) };
}

async function becomeFriends(requester, addressee) {
  const { data } = await api("/api/social/friends", {
    method: "POST",
    body: JSON.stringify({ username: addressee.username }),
  }, requester.cookie, 201);
  await api(`/api/social/friends/${encodeURIComponent(data.friendshipId)}`, {
    method: "PATCH",
    body: JSON.stringify({ action: "accept" }),
  }, addressee.cookie);
}

const payload = {
  locale: "en",
  object: { id: "psr_b0329_54", name: "PSR B0329+54 <script>", type: "Radio pulsar" },
  telescopeFamily: "fast_radio",
  telescopeName: "FAST 500 m Radio Telescope",
  equipment: { primary: "Suspended feed cabin", secondary: "Cryogenic receiver", detail: "500 m aperture synthesis" },
  parameters: [
    { label: "Period", value: "714.520 ms" },
    { label: "DM", value: "26.83 pc/cm³" },
    { label: "Signal / noise", value: "58.1" },
  ],
  quality: { grade: "Excellent", metrics: { clarity: 96, contrast: 91, detail: 94 } },
  discovery: "A stable folded pulse emerged from the cleaned time-frequency data.",
  missionLevel: 77,
};

await api("/api/observation-shares", { method: "POST", body: JSON.stringify(payload) }, "", 401);
const owner = await register("obsa", 21);
const friend = await register("obsb", 22);
const outsider = await register("obsc", 23);
await becomeFriends(owner, friend);

const invalid = await api("/api/observation-shares", {
  method: "POST",
  body: JSON.stringify({ object: { id: "missing" } }),
}, owner.cookie, 400);
assert.equal(invalid.data.error, "invalid_observation");

const { data: created } = await api("/api/observation-shares", {
  method: "POST",
  body: JSON.stringify(payload),
}, owner.cookie, 201);
assert.match(created.id, /^OBS-[A-Z0-9]{8,40}$/);
assert.equal(created.url, `https://pixelobservatorygame.com/observation/${created.id}`);

const { data: publicRecord } = await api(`/api/observation-shares/${created.id}`);
assert.equal(publicRecord.observer, owner.username);
assert.equal(publicRecord.observation.object.name, payload.object.name, "Public records remain data and are escaped by the renderer.");
assert.equal(publicRecord.observation.parameters[0].value, "714.520 ms");

const outsiderSend = await api(`/api/observation-shares/${created.id}/send`, {
  method: "POST",
  body: JSON.stringify({ username: outsider.username, language: "en" }),
}, owner.cookie, 403);
assert.equal(outsiderSend.data.error, "not_friends");

await api(`/api/observation-shares/${created.id}/send`, {
  method: "POST",
  body: JSON.stringify({ username: friend.username, language: "en" }),
}, owner.cookie, 201);
const { data: conversations } = await api("/api/messages/conversations", {}, friend.cookie);
const sharedConversation = conversations.conversations.find(item => item.peer_username === owner.username);
assert.ok(sharedConversation, "The confirmed friend must receive a direct conversation.");
const { data: thread } = await api(`/api/messages/conversations/${encodeURIComponent(sharedConversation.id)}`, {}, friend.cookie);
assert.ok(thread.messages.at(-1).body.includes(`/observation/${created.id}`), "The direct message must contain the public result URL.");

console.log(JSON.stringify({
  ok: true,
  shareId: created.id,
  anonymousRead: true,
  outsiderDenied: outsiderSend.data.error,
  friendReceived: friend.username,
  publicPayloadPreserved: true,
}, null, 2));
