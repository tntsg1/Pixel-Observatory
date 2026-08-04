import assert from "node:assert/strict";

const baseUrl = process.env.FRIEND_MESSAGING_TEST_URL || "http://127.0.0.1:8791";
const password = "FriendMessaging!2026";
const suffix = `${Date.now().toString(36)}${Math.floor(Math.random() * 10_000)}`;
const testNetwork = 20 + Math.floor(Math.random() * 200);

function sessionCookie(response) {
	const raw = response.headers.get("set-cookie") || "";
	const match = raw.match(/(?:^|,\s*)(po_session=[^;]+)/);
	assert.ok(match, "Registration must return a server session cookie.");
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
	assert.equal(
		response.status,
		expectedStatus,
		`${options.method || "GET"} ${path}: expected ${expectedStatus}, got ${response.status} ${JSON.stringify(data)}`,
	);
	return { response, data };
}

async function register(prefix, addressOctet) {
	const username = `${prefix}${suffix}`;
	const { response, data } = await api("/api/auth/register", {
		method: "POST",
		// Give each remote acceptance run a reserved, isolated test address so a
		// prior test cannot consume the production registration rate-limit bucket.
		headers: { "X-Pixel-Observatory-Test-IP": `198.18.${testNetwork}.${addressOctet}` },
		body: JSON.stringify({
			username,
			password,
			website: "",
			turnstileToken: "local-test",
		}),
	}, "", 201);
	return {
		id: data.user.id,
		username: data.user.username,
		cookie: sessionCookie(response),
	};
}

async function becomeFriends(requester, addressee) {
	const { data: requested } = await api("/api/social/friends", {
		method: "POST",
		body: JSON.stringify({ username: addressee.username }),
	}, requester.cookie, 201);
	await api(`/api/social/friends/${encodeURIComponent(requested.friendshipId)}`, {
		method: "PATCH",
		body: JSON.stringify({ action: "accept" }),
	}, addressee.cookie);
	return requested.friendshipId;
}

const accountA = await register("msgia", 11);
const accountB = await register("msgib", 12);
const outsider = await register("msgic", 13);
const friendshipId = await becomeFriends(accountA, accountB);

const { data: presenceA } = await api("/api/social/presence", {
	method: "POST",
	body: JSON.stringify({ activityKey: "observing_fast" }),
}, accountA.cookie);
assert.equal(presenceA.activityKey, "observing_fast");
const { data: friendsB } = await api("/api/social/friends", {}, accountB.cookie);
const visibleAccountA = friendsB.friends.find(friend => friend.username === accountA.username);
assert.ok(visibleAccountA, "The accepted friend must appear in the observing rail.");
assert.equal(visibleAccountA.online, true);
assert.equal(visibleAccountA.activityKey, "observing_fast", "A friend's current observing activity must cross the API boundary.");

const invalidPresence = await api("/api/social/presence", {
	method: "POST",
	body: JSON.stringify({ activityKey: "invented_activity" }),
}, accountA.cookie, 400);
assert.equal(invalidPresence.data.error, "invalid_activity");

const { data: poke } = await api("/api/social/signals", {
	method: "POST",
	body: JSON.stringify({ username: accountB.username, kind: "poke" }),
}, accountA.cookie, 201);
assert.equal(poke.kind, "poke");
const { data: signalsB } = await api("/api/social/signals", {}, accountB.cookie);
assert.equal(signalsB.signals.some(signal => signal.kind === "poke" && signal.sender?.username === accountA.username), true);

const { data: nudge } = await api("/api/social/signals", {
	method: "POST",
	body: JSON.stringify({ username: accountA.username, kind: "come_online" }),
}, accountB.cookie, 201);
assert.equal(nudge.kind, "come_online");
const { data: signalsA } = await api("/api/social/signals", {}, accountA.cookie);
assert.equal(signalsA.signals.some(signal => signal.kind === "come_online" && signal.sender?.username === accountB.username), true);

const { data: invite } = await api("/api/social/signals", {
	method: "POST",
	body: JSON.stringify({ username: accountB.username, kind: "invite_observe" }),
}, accountA.cookie, 201);
assert.equal(invite.kind, "invite_observe");
const { data: invitedSignalsB } = await api("/api/social/signals", {}, accountB.cookie);
const observingInvite = invitedSignalsB.signals.find(signal => signal.kind === "invite_observe" && signal.sender?.username === accountA.username);
assert.ok(observingInvite, "An observing invitation must reach the friend without leaving the game.");
assert.equal(observingInvite.sender.activityKey, "observing_fast");

const deniedOutsider = await api("/api/messages/conversations", {
	method: "POST",
	body: JSON.stringify({
		username: accountA.username,
		body: "This must not create a conversation.",
	}),
}, outsider.cookie, 403);
assert.equal(deniedOutsider.data.error, "not_friends");

const xssProbe = `<img src=x onerror="globalThis.__xss=1"> & orbit`;
const { data: created } = await api("/api/messages/conversations", {
	method: "POST",
	body: JSON.stringify({
		username: accountB.username,
		body: xssProbe,
	}),
}, accountA.cookie, 201);
assert.ok(created.conversationId, "The first real message creates the direct conversation.");

const { data: listB } = await api("/api/messages/conversations", {}, accountB.cookie);
const listed = listB.conversations.find(item => item.id === created.conversationId);
assert.ok(listed, "The recipient sees the new conversation without a second creation path.");
assert.equal(listed.peer_username, accountA.username);

const { data: conversationB } = await api(
	`/api/messages/conversations/${encodeURIComponent(created.conversationId)}`,
	{},
	accountB.cookie,
);
assert.equal(conversationB.messages.at(-1).body, xssProbe, "The API preserves text; the shared renderer escapes it.");

await api(`/api/social/friends/${encodeURIComponent(friendshipId)}`, {
	method: "DELETE",
}, accountA.cookie);

const deniedAfterRemoval = await api(
	`/api/messages/conversations/${encodeURIComponent(created.conversationId)}/messages`,
	{
		method: "POST",
		body: JSON.stringify({ body: "This must be rejected after unfriending." }),
	},
	accountA.cookie,
	403,
);
assert.equal(deniedAfterRemoval.data.error, "not_friends");

const { data: retainedHistory } = await api(
	`/api/messages/conversations/${encodeURIComponent(created.conversationId)}`,
	{},
	accountA.cookie,
);
assert.equal(
	retainedHistory.messages.some(message => message.body === xssProbe),
	true,
	"Removing a friend blocks new sends without destroying existing history.",
);

console.log(JSON.stringify({
	ok: true,
	conversationId: created.conversationId,
	existingConversationVisibleToRecipient: true,
	pokeDelivered: true,
	nudgeDelivered: true,
	observingActivityVisible: visibleAccountA.activityKey,
	observingInviteDelivered: true,
	outsiderDenied: deniedOutsider.data.error,
	sendAfterUnfriendDenied: deniedAfterRemoval.data.error,
	historyRetained: true,
	xssPayloadPreservedAsText: true,
}, null, 2));
