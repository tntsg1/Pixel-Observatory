(() => {
  "use strict";
  const state = {payload:null, share:null, shell:null, status:null, friends:[]};
  const zh = () => document.documentElement.dataset.lang === "zh";
  const t = (en, cn) => zh() ? cn : en;
  const esc = value => String(value ?? "").replace(/[&<>"']/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[character]);
  const api = async (path, options = {}) => {
    const response = await fetch(path, {credentials:"same-origin", ...options, headers:{"content-type":"application/json",...(options.headers||{})}});
    const data = await response.json().catch(() => ({}));
    if (!response.ok) { const error = new Error(data.message || t("Request failed.", "请求未能完成。")); error.status = response.status; throw error; }
    return data;
  };

  function payloadSignature(payload) {
    return JSON.stringify(payload || {});
  }

  function buildCard(payload) {
    const object = payload.object || {};
    const equipment = payload.equipment || {};
    const parameters = (payload.parameters || []).slice(0, 6).map(item => `<div><span>${esc(item.label)}</span><strong>${esc(item.value)}</strong></div>`).join("");
    return `<section class="observation-share-card">
      <div class="observation-share-identity"><span class="observation-share-eyebrow">${t("Observation result", "观测成果")}</span><h2>${esc(object.name)}</h2><p>${esc(object.type)} · ${esc(payload.telescopeName)}</p></div>
      <div class="observation-share-ring"><i></i></div>
      <div class="observation-share-data"><div><span>${t("Quality", "质量")}</span><strong>${esc(payload.quality?.grade)}</strong></div><div><span>${t("Equipment", "设备")}</span><strong>${esc(equipment.primary || payload.telescopeName)}</strong></div>${parameters}</div>
      <div class="observation-share-discovery"><span class="observation-share-eyebrow">${t("What became visible", "本次发现")}</span><br>${esc(payload.discovery)}</div>
    </section>`;
  }

  function toast(message) {
    let node = document.querySelector(".observation-share-toast");
    if (!node) { node = document.createElement("div"); node.className = "observation-share-toast"; document.body.append(node); }
    node.textContent = message; node.classList.add("is-visible"); clearTimeout(node._timer); node._timer = setTimeout(() => node.classList.remove("is-visible"), 2400);
  }

  async function session() {
    return api("/api/auth/session").then(result => result.user || null);
  }

  async function createLink(button) {
    if (state.share) return state.share;
    button.disabled = true;
    state.status.textContent = t("Publishing the result record…", "正在生成成果记录……");
    try {
      state.share = await api("/api/observation-shares", {method:"POST", body:JSON.stringify(state.payload)});
      renderTools(await session());
      toast(t("Share link is ready.", "分享链接已生成。"));
      return state.share;
    } catch (error) {
      if (error.status === 401) renderTools(null);
      else state.status.textContent = error.message;
      throw error;
    } finally { button.disabled = false; }
  }

  async function renderTools(user) {
    const tools = state.shell.querySelector(".observation-share-tools");
    if (!user) {
      tools.innerHTML = `<h3>${t("Share this observation", "分享本次观测")}</h3><p>${t("The card is ready. Sign in to keep a public link or send it to a friend.", "成果卡已经准备好。登录后可以保存公开链接，或直接发送给好友。")}</p><div class="observation-share-auth">${t("Observation links are attached to an observer account so they cannot be anonymously flooded.", "观测链接会关联到观测员账号，避免匿名滥用。")}
        <div><button class="observation-share-button primary" data-auth="register">${t("Create account", "注册账号")}</button><button class="observation-share-button" data-auth="login">${t("Sign in", "登录")}</button></div></div><div class="observation-share-status"></div>`;
      state.status = tools.querySelector(".observation-share-status");
      tools.querySelectorAll("[data-auth]").forEach(button => button.onclick = () => { close(); document.getElementById("account-open")?.click(); setTimeout(() => document.querySelector(`[data-mode="${button.dataset.auth}"]`)?.click(), 80); });
      return;
    }
    let friends = [];
    try { friends = (await api("/api/social/friends")).friends || []; } catch (_) {}
    state.friends = friends.sort((a,b) => Number(b.online)-Number(a.online) || String(a.username).localeCompare(String(b.username)));
    const friendRows = state.share ? state.friends.map(friend => `<div class="observation-share-friend"><div><strong>${esc(friend.username)}</strong><span>${friend.online ? t("Online now", "当前在线") : t("Offline", "离线")}</span></div><button class="observation-share-button" data-send-friend="${esc(friend.username)}">${t("Send", "发送")}</button></div>`).join("") : "";
    tools.innerHTML = `<h3>${t("Share this observation", "分享本次观测")}</h3><p>${state.share ? t("Your result now has a permanent observatory link.", "本次成果已经拥有可访问的天文台链接。") : t("Publish one link, then send it directly to a confirmed friend.", "先生成一个链接，再直接发送给已确认的好友。")}</p>
      ${state.share ? `<div class="observation-share-url"><input value="${esc(state.share.url)}" readonly><button class="observation-share-button" id="copy-observation-link">${t("Copy", "复制")}</button></div><div class="observation-share-friends">${friendRows || `<span>${t("Add a friend in the community to send this result directly.", "在社区添加好友后，就能直接发送本次成果。")}</span>`}</div>` : `<button class="observation-share-button primary" id="create-observation-link">${t("Generate share link", "生成分享链接")}</button>`}
      <div class="observation-share-actions"><button class="observation-share-button" id="native-observation-share" ${state.share ? "" : "disabled"}>${t("System share", "系统分享")}</button><button class="observation-share-button" id="open-observation-link" ${state.share ? "" : "disabled"}>${t("Open result page", "打开成果页")}</button></div><div class="observation-share-status"></div>`;
    state.status = tools.querySelector(".observation-share-status");
    tools.querySelector("#create-observation-link")?.addEventListener("click", event => createLink(event.currentTarget).catch(()=>{}));
    tools.querySelector("#copy-observation-link")?.addEventListener("click", async () => { await navigator.clipboard.writeText(state.share.url); toast(t("Link copied.", "链接已复制。")); });
    tools.querySelector("#open-observation-link")?.addEventListener("click", () => window.open(state.share.url, "_blank", "noopener"));
    tools.querySelector("#native-observation-share")?.addEventListener("click", async () => { if (navigator.share) await navigator.share({title:state.payload.object?.name || "Observation",text:state.payload.discovery,url:state.share.url}); else await navigator.clipboard.writeText(state.share.url); });
    tools.querySelectorAll("[data-send-friend]").forEach(button => button.onclick = async () => {
      button.disabled = true; state.status.textContent = t(`Sending to ${button.dataset.sendFriend}…`, `正在发送给 ${button.dataset.sendFriend}……`);
      try { await api(`/api/observation-shares/${encodeURIComponent(state.share.id)}/send`, {method:"POST",body:JSON.stringify({username:button.dataset.sendFriend,language:zh()?"zh":"en"})}); state.status.textContent = t(`Sent to ${button.dataset.sendFriend}.`, `已发送给 ${button.dataset.sendFriend}。`); toast(t("Observation sent.", "观测成果已发送。")); }
      catch(error){ state.status.textContent = error.message; }
      finally { button.disabled = false; }
    });
  }

  async function open(payload) {
    if (!payload?.object?.name) return;
    if (payloadSignature(payload) !== payloadSignature(state.payload)) state.share = null;
    state.payload = payload;
    if (state.shell) state.shell.remove();
    const shell = document.createElement("div");
    shell.className = "observation-share-shell";
    shell.innerHTML = `<section class="observation-share-dialog" role="dialog" aria-modal="true" aria-label="${t("Share observation", "分享观测")}"><header class="observation-share-head"><span>${t("Field record ready", "观测记录已就绪")}</span><button class="observation-share-close" type="button" aria-label="${t("Close", "关闭")}">×</button></header><div class="observation-share-body">${buildCard(payload)}<aside class="observation-share-tools"><h3>${t("Share this observation", "分享本次观测")}</h3><p>${t("Checking your observer account…", "正在确认观测员账号……")}</p><div class="observation-share-status"></div></aside></div></section>`;
    document.body.append(shell); state.shell = shell; state.status = shell.querySelector(".observation-share-status");
    shell.querySelector(".observation-share-close").onclick = close;
    shell.addEventListener("click", event => { if (event.target === shell) close(); });
    addEventListener("keydown", escapeClose, {once:true});
    requestAnimationFrame(() => shell.classList.add("is-open"));
    try { await renderTools(await session()); } catch (error) { state.status.textContent = error.message; }
  }

  function escapeClose(event) { if (event.key === "Escape") close(); }
  function close() { if (!state.shell) return; state.shell.classList.remove("is-open"); const shell=state.shell; state.shell=null; setTimeout(()=>shell.remove(),220); }
  addEventListener("observatory:observation-complete", event => { if (event.detail?.object?.name) state.payload = event.detail; });
  addEventListener("observatory:open-observation-share", event => open(event.detail || state.payload));
  window.POObservationShare = {open, close};
})();
