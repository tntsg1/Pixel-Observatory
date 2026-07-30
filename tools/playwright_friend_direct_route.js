async page => {
  const calls = [];
  let createdDirect = false;
  const existing = {
    id: "CV-EXISTING",
    kind: "direct",
    peer_username: "FriendOne",
    title: "FriendOne",
    unread_count: 1,
    updated_at: 2,
    last_message_at: 2,
    last_message: "Existing signal",
  };
  const created = {
    id: "CV-NEW",
    kind: "direct",
    peer_username: "NewFriend",
    title: "NewFriend",
    unread_count: 0,
    updated_at: 3,
    last_message_at: 3,
    last_message: "First pulse",
  };
  const fulfill = (route, body, status = 200) => route.fulfill({
    status,
    contentType: "application/json",
    body: JSON.stringify(body),
  });

  await page.route("**/api/**", async route => {
    const request = route.request();
    const path = request.url().replace(/^https?:\/\/[^/]+/, "").split("?")[0];
    const method = request.method();
    calls.push({ path, method, body: request.postData() || "" });
    if (path === "/api/auth/session") {
      return fulfill(route, { ok: true, user: { id: "U-A", username: "ObserverA", role: "user" } });
    }
    if (path === "/api/social/friends") {
      return fulfill(route, { ok: true, friends: [
        { username: "FriendOne", online: true, avatarId: 1, rank: { name: "Signal Keeper" } },
        { username: "NewFriend", online: true, avatarId: 2, rank: { name: "First Light" } },
      ], incoming: [], outgoing: [] });
    }
    if (path === "/api/social/profile") {
      return fulfill(route, { ok: true, profile: { username: "ObserverA", avatarId: 1, playSeconds: 60, rank: { name: "First Light" } } });
    }
    if (path === "/api/social/signals") return fulfill(route, { ok: true, signals: [] });
    if (path === "/api/messages/conversations" && method === "GET") {
      return fulfill(route, { ok: true, conversations: createdDirect ? [existing, created] : [existing] });
    }
    if (path === "/api/messages/conversations" && method === "POST") {
      const payload = JSON.parse(request.postData() || "{}");
      if (payload.username !== "NewFriend" || payload.body !== "First pulse") {
        return fulfill(route, { ok: false, message: "Unexpected direct-message payload." }, 400);
      }
      createdDirect = true;
      return fulfill(route, { ok: true, conversationId: "CV-NEW", messageId: "MSG-NEW" }, 201);
    }
    if (path === "/api/messages/conversations/CV-EXISTING" && method === "GET") {
      return fulfill(route, {
        ok: true,
        conversation: { id: "CV-EXISTING", kind: "direct" },
        currentUserId: "U-A",
        members: [{ id: "U-A", username: "ObserverA" }, { id: "U-B", username: "FriendOne" }],
        messages: [{ id: "M1", sender_user_id: "U-B", sender_label: "FriendOne", body: "Existing signal", created_at: 1, message_kind: "user" }],
      });
    }
    if (path === "/api/messages/conversations/CV-NEW" && method === "GET") {
      return fulfill(route, {
        ok: true,
        conversation: { id: "CV-NEW", kind: "direct" },
        currentUserId: "U-A",
        members: [{ id: "U-A", username: "ObserverA" }, { id: "U-C", username: "NewFriend" }],
        messages: [{ id: "M2", sender_user_id: "U-A", sender_label: "ObserverA", body: "First pulse", created_at: 2, message_kind: "user" }],
      });
    }
    if (/\/api\/messages\/conversations\/[^/]+\/read$/.test(path)) return fulfill(route, { ok: true });
    if (path === "/api/config") return fulfill(route, { ok: true, turnstileSiteKey: "", social: true });
    if (path === "/api/social/playtime") return fulfill(route, { ok: true, playSeconds: 60, earnedSeconds: 0, leaseAccepted: true });
    return fulfill(route, { ok: true });
  });

  await page.goto("http://127.0.0.1:8766/game/?friend-direct-route=1", { waitUntil: "domcontentloaded" });
  await page.setViewportSize({ width: 1920, height: 1080 });
  await page.waitForSelector('#game-friends-rail:not([hidden]) [data-message="FriendOne"]');
  await page.evaluate(() => { document.getElementById("status").style.display = "none"; });

  await page.locator('#game-friends-rail [data-message="FriendOne"]').click();
  await page.waitForSelector('#po-inbox-modal:not([hidden]) .po-reply textarea');
  const existingState = await page.evaluate(() => ({
    title: document.querySelector("#po-inbox-modal .po-thread-head h3")?.textContent?.trim(),
    composeVisible: Boolean(document.querySelector("#po-inbox-modal .po-new-form")),
    usernameField: Boolean(document.querySelector('#po-inbox-modal input[name="username"]')),
    replyFocused: document.activeElement === document.querySelector("#po-inbox-modal .po-reply textarea"),
    body: document.querySelector("#po-inbox-modal .po-message-body")?.textContent?.trim(),
  }));
  if (existingState.title !== "FriendOne" || existingState.composeVisible || existingState.usernameField || existingState.body !== "Existing signal") {
    throw new Error(`Existing conversation did not open directly: ${JSON.stringify(existingState)}`);
  }
  await page.screenshot({ path: "output/playwright/friend_direct_existing_conversation.png", fullPage: true });

  await page.locator("#po-inbox-modal .po-close").click();
  await page.waitForSelector("#po-inbox-modal", { state: "hidden" });
  await page.locator('#game-friends-rail [data-message="NewFriend"]').click();
  await page.waitForSelector('#po-inbox-modal:not([hidden]) .po-reply textarea');
  await page.waitForFunction(() =>
    document.activeElement === document.querySelector("#po-inbox-modal .po-reply textarea")
  );
  const emptyState = await page.evaluate(() => ({
    title: document.querySelector("#po-inbox-modal .po-thread-head h3")?.textContent?.trim(),
    composeVisible: Boolean(document.querySelector("#po-inbox-modal .po-new-form")),
    usernameField: Boolean(document.querySelector('#po-inbox-modal input[name="username"]')),
    replyFocused: document.activeElement === document.querySelector("#po-inbox-modal .po-reply textarea"),
  }));
  if (emptyState.title !== "NewFriend" || emptyState.composeVisible || emptyState.usernameField || !emptyState.replyFocused) {
    throw new Error(`Empty direct thread fell back to compose: ${JSON.stringify(emptyState)}`);
  }
  await page.locator("#po-inbox-modal .po-reply textarea").fill("First pulse");
  await page.locator("#po-inbox-modal .po-send").click();
  await page.waitForFunction(() =>
    document.querySelector("#po-inbox-modal .po-message-body")?.textContent?.trim() === "First pulse"
  );
  await page.screenshot({ path: "output/playwright/friend_direct_first_message.png", fullPage: true });

  const createCall = calls.find(call => call.path === "/api/messages/conversations" && call.method === "POST");
  if (!createCall) throw new Error("First direct message did not create the conversation.");
  return JSON.stringify({ existingState, emptyState, createdDirect, createBody: JSON.parse(createCall.body) });
}
