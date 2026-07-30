import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const root = new URL("../", import.meta.url);
const messagingSource = fs.readFileSync(new URL("../web/landing/messaging.js", import.meta.url), "utf8");
const socialSource = fs.readFileSync(new URL("../web/landing/social.js", import.meta.url), "utf8");
const gameLoaderSource = fs.readFileSync(new URL("../web/landing/game-loader.js", import.meta.url), "utf8");
const inboxSource = fs.readFileSync(new URL("../web/landing/inbox.js", import.meta.url), "utf8");
const workerSource = fs.readFileSync(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8");

const listeners = {};
const context = {
  console,
  URL,
  encodeURIComponent,
  setTimeout,
  clearTimeout,
  setInterval: () => 1,
  clearInterval() {},
  document: {
    hidden: false,
    documentElement: { dataset: { lang: "en" } },
    addEventListener(type, callback) { listeners[type] = callback; },
  },
  window: {
    fetch: async () => { throw new Error("Unexpected singleton request"); },
    setInterval: () => 1,
    clearInterval() {},
    addEventListener() {},
  },
};
context.window.window = context.window;
context.window.document = context.document;
vm.createContext(context);
vm.runInContext(messagingSource, context, { filename: "messaging.js" });

const calls = [];
let conversationVersion = 1;
const response = (body, status = 200) => ({
  ok: status >= 200 && status < 300,
  status,
  async json() { return body; },
});
const fakeFetch = async (path, options = {}) => {
  calls.push({ path, options });
  if (path === "/api/messages/conversations" && (!options.method || options.method === "GET")) {
    return response({ conversations: [{
      id: "CV-EXISTING",
      kind: "direct",
      peer_username: "tntsg1",
      title: "tntsg1",
      unread_count: 0,
      updated_at: 1,
    }] });
  }
  if (path === "/api/messages/conversations" && options.method === "POST") {
    return response({ conversationId: "CV-NEW", messageId: "MSG-NEW" }, 201);
  }
  if (path === "/api/messages/conversations/CV-EXISTING") {
    return response({
      conversation: { id: "CV-EXISTING", kind: "direct" },
      currentUserId: "U-A",
      messages: conversationVersion === 1
        ? [{ id: "M1", sender_user_id: "U-B", sender_label: "tntsg1", body: "<img src=x onerror=alert(1)>", created_at: 1, message_kind: "user" }]
        : [
            { id: "M1", sender_user_id: "U-B", sender_label: "tntsg1", body: "<img src=x onerror=alert(1)>", created_at: 1, message_kind: "user" },
            { id: "M2", sender_user_id: "U-A", sender_label: "tntsg", body: "received live", created_at: 2, message_kind: "user" },
          ],
    });
  }
  throw new Error(`Unexpected request ${options.method || "GET"} ${path}`);
};

const controller = context.window.POMessagingFactory({ fetch: fakeFetch, pollInterval: 1000 });
const conversations = await controller.listConversations();
assert.equal(controller.findDirectConversation("Tntsg1", conversations)?.id, "CV-EXISTING", "existing direct conversation is reused");
assert.equal(controller.findDirectConversation("new-friend", conversations), null, "opening an empty chat does not create a conversation");
assert.equal(calls.filter(call => call.options.method === "POST").length, 0, "conversation list never creates an empty thread");

await controller.startDirect("new-friend", "first message");
const createCall = calls.find(call => call.path === "/api/messages/conversations" && call.options.method === "POST");
assert.deepEqual(JSON.parse(createCall.options.body), { username: "new-friend", body: "first message" }, "first message creates the direct conversation");

const firstData = await controller.getConversation("CV-EXISTING");
const markup = controller.renderMessages(firstData);
assert.ok(markup.includes("&lt;img"), "message body is rendered as escaped text");
assert.ok(!markup.includes("<img"), "XSS markup is never inserted");

let liveUpdates = 0;
const stopWatching = controller.watchConversation("CV-EXISTING", data => {
  if (data) liveUpdates += 1;
});
await new Promise(resolve => setTimeout(resolve, 0));
conversationVersion = 2;
await controller.poll(true);
stopWatching();
assert.equal(liveUpdates, 2, "an open conversation receives a new server message without refresh");

assert.ok(inboxSource.includes("const messaging = window.POMessaging"), "Inbox uses the shared messaging controller");
assert.ok(!inboxSource.includes("setInterval(() => {\n      pollOpenInbox"), "Inbox no longer owns a duplicate message polling loop");
assert.ok(gameLoaderSource.includes("direct: true"), "in-game friend message actions explicitly request a direct conversation");
assert.ok(inboxSource.includes("openDirectConversation(state.directUsername)"), "in-game friend routes open the requested conversation directly");
assert.ok(inboxSource.includes("messaging.findDirectConversation(username, state.conversations)"), "existing friend conversations are reused");
assert.ok(inboxSource.includes("renderDirectStart(username)"), "friends without history see an empty direct thread instead of the generic compose screen");
assert.ok(!inboxSource.includes("render().then(() => {\n      if (state.composeUsername) renderCompose();"), "the old unconditional compose routing is removed");
assert.ok(socialSource.includes("data-message-friend"), "friend cards expose the in-place message action");
assert.ok(socialSource.includes("friend-chat-drawer"), "community contains the in-place chat drawer");
assert.ok(socialSource.includes("catch (error) {\n        status.textContent = error.message;"), "send failures stay inline without clearing the draft");
assert.ok(socialSource.includes('"从这里开始一段观测交流。"'), "friend drawer ships readable UTF-8 Chinese copy");
assert.ok(socialSource.includes('t("Private conversation", "私信对话")'), "friend drawer localizes its accessible name");
assert.ok(socialSource.includes("attachFriendConversation(activeFriend, activeConversation)"), "open chat rerenders when language changes");
assert.ok(workerSource.includes("Only confirmed friends can exchange private messages."), "Worker rejects non-friend direct messages");
const directHandler = workerSource.slice(workerSource.indexOf("async function handleDirectConversationPost"), workerSource.indexOf("function rankForSeconds"));
const postHandler = workerSource.slice(workerSource.indexOf("async function handleMessagePost"), workerSource.indexOf("async function handleDirectConversationPost"));
assert.ok(directHandler.includes("acceptedFriendship(env, user.id, recipient.id)"), "new direct conversations require accepted friendship");
assert.ok(postHandler.includes('conversation.kind === "direct"') && postHandler.includes("acceptedFriendship"), "existing direct conversations re-check friendship");

console.log("PASS web friend messaging: shared realtime controller, lazy creation, XSS escaping, and friend-only authorization");
