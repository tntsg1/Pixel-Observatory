async page => {
  const calls = [];
  const json = (route, body, status = 200) => route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
  await page.route("**/api/**", route => {
    const request = route.request();
    const path = request.url().replace(/^https?:\/\/[^/]+/, "").split("?")[0];
    const method = request.method();
    calls.push({ path, method, body: request.postData() || "" });
    if (path === "/api/auth/session") return json(route, { user: { id: "A", username: "ObserverA", role: "user" } });
    if (path === "/api/social/profile") return json(route, { profile: { username: "ObserverA", avatarId: 1, playSeconds: 3660, rank: { name: "Observer Apprentice", progress: .4, next: { name: "Stellar Recorder" } } } });
    if (path === "/api/social/friends") return json(route, { friends: [{ username: "FriendOne", online: true, avatarId: 2, activityKey: "observing_fast", rank: { name: "Signal Keeper" } }], incoming: [], outgoing: [] });
    if (path === "/api/social/signals" && method === "GET") return json(route, { signals: [] });
    if (path === "/api/social/signals") return json(route, { ok: true }, 201);
    if (path === "/api/social/presence") return json(route, { ok: true, activityKey: "observatory" });
    if (path === "/api/messages/conversations") return json(route, { conversations: [{ id: "CV1", kind: "direct", peer_username: "FriendOne", title: "FriendOne", last_message: "Ready", updated_at: 1 }] });
    if (path === "/api/messages/conversations/CV1") return json(route, { conversation: { id: "CV1", kind: "direct" }, currentUserId: "A", members: [{ id: "A", username: "ObserverA" }, { id: "B", username: "FriendOne" }], messages: [{ id: "M1", sender_user_id: "B", sender_label: "FriendOne", body: "Ready", created_at: 1, message_kind: "user" }] });
    if (path.endsWith("/read")) return json(route, { ok: true });
    if (path === "/api/config") return json(route, { social: true, turnstileSiteKey: "" });
    if (path === "/api/social/playtime") return json(route, { playSeconds: 3660, earnedSeconds: 0, leaseAccepted: true });
    return json(route, { ok: true });
  });
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.goto("http://127.0.0.1:8766/game/?lang=en&social-rail-test=1", { waitUntil: "domcontentloaded" });
  await page.waitForSelector('[data-friend="FriendOne"] [data-signal="invite_observe"]');
  await page.evaluate(() => {
    document.getElementById("status").style.display = "none";
    dispatchEvent(new CustomEvent("observatory:playtime-local", { detail: { sessionSeconds: 540 } }));
    dispatchEvent(new CustomEvent("observatory:cloud-sync", { detail: { status: "synced" } }));
  });
  const state = await page.evaluate(() => ({
    activity: document.querySelector(".game-pet-activity")?.textContent.trim(),
    time: document.querySelector("#game-session-time")?.textContent.trim(),
    cloud: document.querySelector("#game-cloud-sync")?.dataset.status,
    progress: document.querySelector("#game-rank-progress-fill")?.style.width,
  }));
  if (JSON.stringify(state) !== JSON.stringify({ activity: "Observing with FAST", time: "00:09:00", cloud: "synced", progress: "40%" })) throw new Error(JSON.stringify(state));
  await page.locator('[data-signal="poke"]').click();
  await page.locator('[data-signal="invite_observe"]').click();
  await page.locator('[data-message="FriendOne"]').click();
  await page.waitForSelector('#po-inbox-modal:not([hidden]) .po-reply textarea');
  const title = await page.locator("#po-inbox-modal .po-thread-head h3").textContent();
  if (title.trim() !== "FriendOne") throw new Error("Direct conversation did not open in game.");
  await page.screenshot({ path: "output/playwright/game_social_activity_desktop.png", fullPage: true });
  const signals = calls.filter(call => call.path === "/api/social/signals" && call.method === "POST").map(call => JSON.parse(call.body).kind);
  if (!signals.includes("poke") || !signals.includes("invite_observe")) throw new Error(JSON.stringify(signals));
  return JSON.stringify({ state, signals, directMessage: title.trim() });
}
