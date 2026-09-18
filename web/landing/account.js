(() => {
  "use strict";
const state = {
    user:null,
    config:null,
    widgetId:null,
    feedbackFrame:0,
    cloudSave:window.__pixelObservatoryCloudSave||{status:"local_saved"},
    announcement:null,
    announcementPresented:false,
    sessionResolved:false,
};

window.pixelObservatoryCloudRequest = async request => {
	let status = 0;
	let responseText = "";
	try {
		const options = {
			method: request?.method || "GET",
			headers: { Accept: "application/json", "Content-Type": "application/json" },
			credentials: "same-origin",
		};
		if (options.method !== "GET" && request?.body) options.body = request.body;
		const response = await fetch(request?.path || "/api/auth/session", options);
		status = response.status;
		responseText = await response.text();
	} catch (error) {
		responseText = JSON.stringify({ error: "network_error", detail: String(error) });
	}
	if (typeof window.pixelObservatoryCloudResponse === "function") {
		window.pixelObservatoryCloudResponse(request?.operation || "", status, responseText);
	}
};
  const closeTimers = new WeakMap();
  const gameContext = { scene:"", level:"", language:"" };
  const isZh = () => document.documentElement.dataset.lang === "zh";
  const t = (en, zh) => isZh() ? zh : en;
  const esc = value => String(value).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));

  document.body.insertAdjacentHTML("beforeend", `
    <section class="po-modal" id="po-account-modal" hidden aria-modal="true" role="dialog"><div class="po-dialog"><button class="po-close" type="button" aria-label="Close">&times;</button><div id="po-account-content"></div></div></section>
    <section class="po-modal po-feedback-modal" id="po-feedback-modal" hidden aria-modal="true" role="dialog" aria-labelledby="po-feedback-title"><div class="po-dialog po-feedback-dialog"><button class="po-close" type="button" aria-label="Close">&times;</button><div id="po-feedback-content"></div></div></section>
    <section class="po-modal po-release-modal" id="po-release-modal" hidden aria-modal="true" role="dialog" aria-labelledby="po-release-title"><div class="po-dialog po-release-dialog"><button class="po-close" type="button" aria-label="Close">&times;</button><div id="po-release-content"></div></div></section>`);
  const accountModal = document.getElementById("po-account-modal");
  const feedbackModal = document.getElementById("po-feedback-modal");
  const releaseModal = document.getElementById("po-release-modal");
  const accountContent = document.getElementById("po-account-content");
  const feedbackContent = document.getElementById("po-feedback-content");
  const releaseContent = document.getElementById("po-release-content");

  function open(modal){
    clearTimeout(closeTimers.get(modal));
    modal.classList.remove("is-closing");
    modal.classList.add("is-entering");
    modal.hidden=false;
    document.body.style.overflow="hidden";
    requestAnimationFrame(()=>{
      modal.classList.add("is-open");
      modal.classList.remove("is-entering");
    });
    setTimeout(()=>modal.querySelector("input,textarea,button")?.focus(),160);
  }
  function close(modal){
    modal.classList.remove("is-open","is-entering");
    modal.classList.add("is-closing");
    clearTimeout(closeTimers.get(modal));
    closeTimers.set(modal,setTimeout(()=>{
      modal.hidden=true;
      modal.classList.remove("is-closing");
      document.body.style.overflow="";
      if(state.widgetId!==null && window.turnstile){ try{window.turnstile.remove(state.widgetId);}catch(_){} state.widgetId=null; }
      if(modal!==releaseModal) setTimeout(maybeShowReleaseAnnouncement,80);
    },260));
  }
  document.querySelectorAll(".po-modal").forEach(modal=>{
    modal.querySelector(".po-close").onclick=()=>close(modal);
    // Account and feedback forms are deliberate tasks. Keep backdrop clicks
    // inert so an imprecise click cannot discard input or close the dialog.
  });
  feedbackModal.querySelector(".po-feedback-dialog").addEventListener("pointermove",event=>{
    if(state.feedbackFrame) return;
    const dialog=event.currentTarget;
    const clientX=event.clientX;
    const clientY=event.clientY;
    state.feedbackFrame=requestAnimationFrame(()=>{
      state.feedbackFrame=0;
      const bounds=dialog.getBoundingClientRect();
      dialog.style.setProperty("--feedback-x",`${((clientX-bounds.left)/bounds.width)*100}%`);
      dialog.style.setProperty("--feedback-y",`${((clientY-bounds.top)/bounds.height)*100}%`);
    });
  });
  document.addEventListener("keydown", event=>{ if(event.key==="Escape") document.querySelectorAll(".po-modal:not([hidden])").forEach(close); });

  async function api(path, options={}){
    let response;
    try{
      response=await fetch(path,{credentials:"same-origin",...options,headers:{"content-type":"application/json",...(options.headers||{})}});
    }catch(_){
      throw new Error(t("Could not reach the observatory. Check your connection and try again.","\u65e0\u6cd5\u8fde\u63a5\u5929\u6587\u53f0\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5\u3002"));
    }
    const data=await response.json().catch(()=>null);
    if(!data||typeof data!=="object") throw new Error(t("The observatory service was interrupted. Please try again.","\u5929\u6587\u53f0\u670d\u52a1\u6682\u65f6\u4e2d\u65ad\uff0c\u8bf7\u91cd\u8bd5\u3002"));
    if(!response.ok) throw new Error(data.message||t("The request could not be completed. Please try again.","\u8bf7\u6c42\u672a\u80fd\u5b8c\u6210\uff0c\u8bf7\u91cd\u8bd5\u3002"));
    return data;
  }
  async function turnstile(container){
    if(!state.config) state.config=await api("/api/config");
    if(!state.config.turnstileSiteKey){ container.textContent=t("Human check is temporarily unavailable.","人机验证暂时不可用。"); return; }
    if(!window.turnstile){
      await new Promise((resolve,reject)=>{
        const old=document.querySelector("script[data-po-turnstile]");
        if(old){ old.addEventListener("load",resolve,{once:true}); return; }
        const script=document.createElement("script");
        script.src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
        script.async=true; script.defer=true; script.dataset.poTurnstile="true"; script.onload=resolve; script.onerror=reject;
        document.head.appendChild(script);
      });
    }
    state.widgetId=window.turnstile.render(container,{sitekey:state.config.turnstileSiteKey,theme:"dark",appearance:"interaction-only"});
  }
  const challengeToken=()=>state.widgetId===null||!window.turnstile?"":window.turnstile.getResponse(state.widgetId);
  addEventListener("observatory:game-context",event=>{
    const detail=event.detail||{};
    gameContext.scene=String(detail.scene||"").replace(/[^a-z0-9_./-]/gi,"").slice(0,120);
    gameContext.level=String(detail.level||"").replace(/[^0-9]/g,"").slice(0,6);
    gameContext.language=/^(zh|en)$/i.test(String(detail.language||""))?String(detail.language).toLowerCase():"";
    maybeShowReleaseAnnouncement();
  });

  const localized = value => value&&typeof value==="object" ? String(value[isZh()?"zh":"en"]||value.en||value.zh||"") : String(value||"");
  const releaseSeenKey = announcement => `po-release-announcement:${state.user?.id||"guest"}:${announcement.version}`;
  function releaseWasSeen(announcement){
    try{return localStorage.getItem(releaseSeenKey(announcement))==="seen";}catch(_){return false;}
  }
  function markReleaseSeen(){
    if(!state.user||!state.announcement)return;
    try{localStorage.setItem(releaseSeenKey(state.announcement),"seen");}catch(_){}
  }
  function validAnnouncement(value){
    return value&&value.schema===1&&value.audience==="registered"
      &&/^v\d+\.\d+\.\d+(?:[-+][a-z0-9.-]+)?$/i.test(String(value.version||""))
      &&Array.isArray(value.sections)&&value.sections.length>0;
  }
  async function loadReleaseAnnouncement(){
    try{
      const response=await fetch("/release-announcement.json",{cache:"no-store",credentials:"same-origin"});
      const data=await response.json();
      if(!response.ok||!validAnnouncement(data))return;
      state.announcement=data;
      maybeShowReleaseAnnouncement();
    }catch(_){}
  }
  function renderReleaseAnnouncement(force=false){
    const announcement=state.announcement;
    if(!state.user||!announcement)return;
    if(!force&&releaseWasSeen(announcement)){state.announcementPresented=true;return;}
    const sections=announcement.sections.map(section=>`<section class="po-release-section">
      <h3>${esc(localized(section.heading))}</h3>
      <ul>${(Array.isArray(section.items)?section.items:[]).map(item=>`<li>${esc(localized(item))}</li>`).join("")}</ul>
    </section>`).join("");
    releaseContent.innerHTML=`<header class="po-release-head">
        <span class="po-release-seal" aria-hidden="true"><i></i></span>
        <div><span class="po-release-kicker">${t("OBSERVATORY RELEASE BULLETIN","天文台版本公告")}</span>
        <div class="po-release-meta"><strong>${esc(announcement.version)}</strong><time datetime="${esc(announcement.published_at||"")}">${esc(announcement.published_at||"")}</time></div></div>
      </header>
      <h2 id="po-release-title">${esc(localized(announcement.title))}</h2>
      <p class="po-release-summary">${esc(localized(announcement.summary))}</p>
      <div class="po-release-rule" aria-hidden="true"><i></i></div>
      <div class="po-release-body">${sections}</div>
      <footer class="po-release-footer"><p>${esc(localized(announcement.footer))}</p>
        <button class="po-primary po-release-ack" id="po-release-ack" type="button">${t("Acknowledge and enter observatory","已阅，进入天文台")}</button>
      </footer>`;
    document.getElementById("po-release-ack").onclick=()=>{markReleaseSeen();close(releaseModal);};
    state.announcementPresented=true;
    open(releaseModal);
  }
  function maybeShowReleaseAnnouncement(){
    if(state.announcementPresented||!state.sessionResolved||!state.user||!state.announcement)return;
    if(!/^\/game\/?$/i.test(location.pathname))return;
    if(!String(gameContext.scene||"").toLowerCase().includes("main_menu"))return;
    if(document.querySelector(".po-modal:not([hidden])"))return;
    renderReleaseAnnouncement();
  }
  function feedbackContext(){
    const canvas=document.getElementById("canvas");
    const loader=document.getElementById("status");
    const gamePage=/\/game\/?$/i.test(location.pathname);
    return {
      language:gameContext.language||document.documentElement.dataset.lang||navigator.language,
      viewport:`${innerWidth}x${innerHeight}`,
      surface:gamePage?"game":"website",
      gameState:gamePage
        ? (loader&&getComputedStyle(loader).visibility!=="hidden"?"loading":"running")
        : "not_applicable",
      canvas:canvas?`${canvas.width}x${canvas.height}`:null,
      browserLanguage:navigator.language,
      scene:gameContext.scene||"unavailable",
      level:gameContext.level||"unavailable",
      build:String(document.documentElement.dataset.pixelObservatoryBuild||"local").replace(/[^a-z0-9._-]/gi,"").slice(0,80),
    };
  }
  function updateNav(){
    const button=document.getElementById("account-open");
    button?.classList.toggle("is-signed-in",Boolean(state.user));
    const label=document.getElementById("account-label");
    if(label) label.textContent=state.user?.username||t("Account","账号");
  }

  function notifyGameSessionChanged(){
    document.dispatchEvent(new CustomEvent("po:session-changed"));
    if(typeof window.pixelObservatorySessionChanged==="function") window.pixelObservatorySessionChanged();
  }

  function cloudSaveMarkup(){
    const cloud=state.cloudSave||{};
    const status=String(cloud.status||"saved");
    if(status==="merge_required"||cloud.mergeRequired){
      const guestLevel=Math.max(1,Number(cloud.guestLevel||1));
      const cloudLevel=Math.max(1,Number(cloud.cloudLevel||1));
      return `<section class="po-save-merge" aria-live="polite">
        <span class="po-save-orbit" aria-hidden="true"><i></i></span>
        <div><strong>${t("Local progress found","发现游客进度")}</strong>
        <p>${t(`This browser reached Level ${guestLevel}. Merge it with the cloud archive${cloud.hasCloudSave?` at Level ${cloudLevel}`:""} without losing either record.`,`这台浏览器已到达第 ${guestLevel} 关。一键合并后，本地与云端的关卡、解锁和观测记录都会保留。`)}</p></div>
        <button class="po-primary po-merge-save" id="po-merge-save" type="button">${t("Merge progress","一键合并进度")}</button>
        ${cloud.hasCloudSave?`<button class="po-text-action" id="po-keep-cloud-save" type="button">${t("Keep cloud archive instead","改用云端存档")}</button>`:""}
      </section>`;
    }
    const labels={
      local_saved:t("Saved locally just now","刚刚已保存"),
      saved:t("Saved just now","刚刚已保存"),
      syncing:t("Syncing","正在同步"),
      offline:t("Saved offline","离线保存"),
    };
    const label=labels[status]||labels.saved;
    return `<div class="po-sync" data-status="${esc(status)}" aria-live="polite"><i aria-hidden="true"></i><span>${label}</span></div>`;
  }

  function bindCloudSaveActions(){
    const merge=document.getElementById("po-merge-save");
    if(merge) merge.onclick=()=>{
      if(typeof window.pixelObservatoryMergeGuestSave!=="function") return;
      merge.disabled=true;
      merge.textContent=t("Merging...","正在合并…");
      window.pixelObservatoryMergeGuestSave();
    };
    const keep=document.getElementById("po-keep-cloud-save");
    if(keep) keep.onclick=()=>{
      if(typeof window.pixelObservatoryUseCloudSave!=="function") return;
      keep.disabled=true;
      window.pixelObservatoryUseCloudSave();
    };
  }

  function renderAccount(mode="login"){
    if(state.user){
      accountContent.innerHTML=`<h2>${t("Observer account","观测员账号")}</h2>
        <p class="po-lead">${t("Your field record can follow you between browsers.","你的观测记录可以在不同浏览器之间同步。")}</p>
        <div class="po-user-panel"><div class="po-user-name">${esc(state.user.username)}</div>
        ${cloudSaveMarkup()}
        <button class="po-secondary" id="po-open-profile" type="button">${t("Open observer profile","打开个人主页")}</button>
        <button class="po-secondary" id="po-open-friends" type="button">${t("Friends and online status","好友与在线状态")}</button>
        ${state.announcement?`<button class="po-secondary po-release-reopen" id="po-open-release" type="button">${t("Latest update","最新公告")} · ${esc(state.announcement.version)}</button>`:""}
        ${state.user.role==="admin"?'<a class="po-secondary" href="admin/" style="display:grid;place-items:center;text-decoration:none">Open feedback console</a>':""}
        <button class="po-secondary" id="po-change-password" type="button">${t("Change password","修改密码")}</button>
        <button class="po-secondary" id="po-logout" type="button">${t("Sign out","退出登录")}</button></div>`;
      document.getElementById("po-change-password").onclick=renderPasswordChange;
      bindCloudSaveActions();
      document.getElementById("po-open-profile").onclick=()=>{close(accountModal);document.dispatchEvent(new CustomEvent("po:open-social",{detail:{tab:"profile"}}));};
      document.getElementById("po-open-friends").onclick=()=>{close(accountModal);document.dispatchEvent(new CustomEvent("po:open-social",{detail:{tab:"friends"}}));};
      const releaseButton=document.getElementById("po-open-release");
      if(releaseButton)releaseButton.onclick=()=>{close(accountModal);setTimeout(()=>renderReleaseAnnouncement(true),320);};
      document.getElementById("po-logout").onclick=async()=>{ await api("/api/auth/logout",{method:"POST",body:"{}"}); state.user=null; state.announcementPresented=false; updateNav(); notifyGameSessionChanged(); renderAccount(); };
      return;
    }
    accountContent.innerHTML=`<h2>${t("Observer account","观测员账号")}</h2>
      <p class="po-lead">${t("Sign in to carry your telescope, journal, and course progress to another device.","登录后可在其他设备继续使用你的望远镜、日志和课程进度。")}</p>
      <div class="po-tabs"><button class="po-tab" data-mode="login" aria-selected="${mode==="login"}">${t("Sign in","登录")}</button><button class="po-tab" data-mode="register" aria-selected="${mode==="register"}">${t("Create account","注册")}</button></div>
      <form id="po-account-form">
        <label class="po-field">${t("Observer name","用户名")}<input name="username" autocomplete="username" minlength="3" maxlength="24" required></label>
        <label class="po-field">${t("Password","密码")}<input name="password" type="password" autocomplete="${mode==="register"?"new-password":"current-password"}" minlength="8" maxlength="128" required></label>
        <label class="po-honeypot">Website<input name="website" tabindex="-1" autocomplete="off"></label>
        ${mode==="register"?'<div id="po-account-turnstile"></div>':""}
        <button class="po-primary" type="submit">${mode==="register"?t("Create cloud archive","创建云端档案"):t("Sign in","登录")}</button>
        <p class="po-status" id="po-account-status" role="status"></p>
      </form><p class="po-note">${t("Passwords are hashed before storage. Sessions use a secure, browser-only cookie.","密码经哈希处理后保存，会话使用浏览器不可读取的安全 Cookie。")}</p>`;
    accountContent.querySelectorAll(".po-tab").forEach(button=>button.onclick=()=>renderAccount(button.dataset.mode));
    if(mode==="register") turnstile(document.getElementById("po-account-turnstile")).catch(()=>{});
    document.getElementById("po-account-form").onsubmit=async event=>{
      event.preventDefault();
      const form=new FormData(event.currentTarget), status=document.getElementById("po-account-status"), submit=event.currentTarget.querySelector('[type="submit"]');
      status.textContent=""; submit.disabled=true;
      try{
        const data=await api(`/api/auth/${mode}`,{method:"POST",body:JSON.stringify({username:form.get("username"),password:form.get("password"),website:form.get("website"),turnstileToken:mode==="register"?challengeToken():undefined})});
        state.user=data.user; state.announcementPresented=false; updateNav(); notifyGameSessionChanged(); renderAccount(); maybeShowReleaseAnnouncement();
      }catch(error){ status.textContent=error.message; if(mode==="register"&&state.widgetId!==null) window.turnstile?.reset(state.widgetId); }
      finally{ submit.disabled=false; }
    };
  }

  function renderPasswordChange(){
    accountContent.innerHTML=`<h2>${t("Change password","修改密码")}</h2><p class="po-lead">${t("Replace the temporary or current password for this observer account.","为这个观测员账号设置新的密码。")}</p>
      <form id="po-password-form"><label class="po-field">${t("Current password","当前密码")}<input name="current" type="password" autocomplete="current-password" required></label>
      <label class="po-field">${t("New password","新密码")}<input name="next" type="password" autocomplete="new-password" minlength="8" maxlength="128" required></label>
      <button class="po-primary" type="submit">${t("Update password","更新密码")}</button><button class="po-secondary" id="po-password-back" type="button">${t("Back","返回")}</button><p class="po-status" id="po-password-status"></p></form>`;
    document.getElementById("po-password-back").onclick=()=>renderAccount();
    document.getElementById("po-password-form").onsubmit=async event=>{
      event.preventDefault();const form=new FormData(event.currentTarget),status=document.getElementById("po-password-status"),submit=event.currentTarget.querySelector('[type="submit"]');submit.disabled=true;
      try{await api("/api/auth/password",{method:"POST",body:JSON.stringify({currentPassword:form.get("current"),newPassword:form.get("next")})});status.classList.add("good");status.textContent=t("Password updated.","密码已更新。");}
      catch(error){status.textContent=error.message;}finally{submit.disabled=false;}
    };
  }

  function renderFeedback(){
    const categories=[
      ["bug",t("Bug","错误")],["idea",t("Idea","建议")],["visual",t("Visual","画面")],
      ["audio",t("Audio","声音")],["story",t("Story","剧情")],["other",t("Other","其他")],
    ];
    feedbackContent.innerHTML=`<div class="po-feedback-hero">
        <span class="po-feedback-signal" aria-hidden="true"><i></i><i></i><i></i></span>
        <div><span class="po-eyebrow">${t("Observer Network · Field Report","观测者网络 · 现场反馈")}</span>
        <h2 id="po-feedback-title">${t("Help us see the rough edges.","帮我们看清那些不够好的地方。")}</h2>
        <p class="po-lead">${t("Every useful signal reaches the developer console. Clear details help us reproduce the moment you saw.","每一条有效反馈都会进入开发者工作台。描述得越清楚，我们越容易复现你看到的那一刻。")}</p></div>
      </div>
      <form id="po-feedback-form">
        <fieldset class="po-feedback-categories"><legend>${t("What kind of signal is this?","这属于哪一类反馈？")}</legend>
          <div class="po-feedback-segments">${categories.map(([value,label],index)=>`<label><input type="radio" name="category" value="${value}" ${index===0?"checked":""}><span>${label}</span></label>`).join("")}</div>
        </fieldset>
        <label class="po-field po-feedback-message"><span>${t("What did you notice?","你发现了什么？")}</span>
          <textarea name="message" minlength="8" maxlength="4000" required placeholder="${t("Where were you, what did you expect, and what happened instead?","当时在哪个界面？你原本期待什么？实际发生了什么？")}"></textarea>
          <span class="po-field-meta"><span>${t("Page and browser details are attached automatically.","页面与浏览器信息会自动附上。")}</span><output id="po-feedback-count">0 / 4000</output></span>
        </label>
        <label class="po-honeypot">Website<input name="website" tabindex="-1" autocomplete="off"></label>
        <div class="po-feedback-verification"><div><strong>${t("Protected channel","安全反馈通道")}</strong><span>${t("A brief human check keeps automated noise away.","简短的人机验证会拦住自动化骚扰。")}</span></div><div id="po-feedback-turnstile"></div></div>
        <button class="po-primary po-feedback-submit" type="submit"><span class="po-submit-arrow" aria-hidden="true">↑</span><span class="po-submit-label">${t("Send to the developer","发送给开发者")}</span><span class="po-submit-signal" aria-hidden="true"><i></i><i></i><i></i></span></button>
        <p class="po-status" id="po-feedback-status" role="status" aria-live="polite"></p>
      </form>`;
    turnstile(document.getElementById("po-feedback-turnstile")).catch(()=>{});
    const message=feedbackContent.querySelector('textarea[name="message"]');
    const count=document.getElementById("po-feedback-count");
    message.addEventListener("input",()=>{count.textContent=`${message.value.length} / 4000`;});
    document.getElementById("po-feedback-form").onsubmit=async event=>{
      event.preventDefault();
      const form=new FormData(event.currentTarget), submit=event.currentTarget.querySelector('[type="submit"]'), status=document.getElementById("po-feedback-status");
      submit.disabled=true; submit.classList.add("is-sending"); submit.querySelector(".po-submit-label").textContent=t("Transmitting…","正在发送…"); status.textContent="";
      try{
        const data=await api("/api/feedback",{method:"POST",body:JSON.stringify({category:form.get("category"),message:form.get("message"),website:form.get("website"),turnstileToken:challengeToken(),page:location.href,context:feedbackContext()})});
        if(state.widgetId!==null && window.turnstile){ try{window.turnstile.remove(state.widgetId);}catch(_){} state.widgetId=null; }
        feedbackContent.innerHTML=`<div class="po-receipt"><span class="po-receipt-orbit" aria-hidden="true"><i></i></span><span class="po-eyebrow">${t("Transmission complete","传输完成")}</span><strong>${t("You made the observatory better.","你刚刚让天文台变得更好了。")}</strong><p>${t("Thank you for taking the time to mark a rough edge instead of simply walking past it. Your report is now waiting in the developer console.","谢谢你没有直接绕过这个问题，而是认真地把它标记出来。这条反馈已经进入开发者工作台。")}</p><div class="po-receipt-id"><span>${t("Receipt","回执编号")}</span><code>${esc(data.receipt)}</code></div>${data.conversationId?`<p>${t("A personal thank-you letter is waiting in your inbox. The developer can continue replying there.","一封专门写给你的感谢信已经送到信箱，开发者之后也可以在那里继续回复你。")}</p><button class="po-primary po-feedback-submit" id="po-open-feedback-letter" type="button">${t("Read the letter","查看感谢信")}</button>`:""}<button class="po-secondary po-receipt-close" id="po-feedback-done" type="button">${t("Return to the observatory","返回天文台")}</button></div>`;
        const letterButton=document.getElementById("po-open-feedback-letter");
        if(letterButton) letterButton.onclick=()=>{close(feedbackModal);document.dispatchEvent(new CustomEvent("po:open-inbox"));};
        document.getElementById("po-feedback-done").onclick=()=>close(feedbackModal);
      }catch(error){ status.textContent=error.message; if(state.widgetId!==null) window.turnstile?.reset(state.widgetId); submit.disabled=false; submit.classList.remove("is-sending"); submit.querySelector(".po-submit-label").textContent=t("Send to the developer","发送给开发者"); }
    };
  }
  // The game shell inserts its feedback control after this shared account
  // module has loaded.  Delegate instead of taking a one-time snapshot so the
  // same, privacy-scoped form works on the website and on /game/.
  document.addEventListener("click",event=>{
    if(event.target.closest("#account-open")){
      renderAccount();
      open(accountModal);
      return;
    }
    if(event.target.closest("#feedback-open")){
      renderFeedback();
      open(feedbackModal);
    }
  });
  document.addEventListener("po:open-account",event=>{
    const mode=event.detail?.mode==="register"?"register":"login";
    renderAccount(mode);
    open(accountModal);
  });
  addEventListener("observatory:cloud-save-status",event=>{
    state.cloudSave=event.detail||{status:"offline"};
    if(state.user&&!accountModal.hidden) renderAccount();
  });
  ["pointerdown","pointerup","click","wheel","keydown","keyup"].forEach(type=>{
    feedbackModal.addEventListener(type,event=>event.stopPropagation());
  });
  ["pointerdown","pointerup","click","wheel","keyup"].forEach(type=>{
    releaseModal.addEventListener(type,event=>event.stopPropagation());
  });
  releaseModal.addEventListener("keydown",event=>{
    if(event.key==="Escape"){markReleaseSeen();close(releaseModal);}
    event.stopPropagation();
  });
  releaseModal.querySelector(".po-close").addEventListener("click",markReleaseSeen);
  loadReleaseAnnouncement();
  api("/api/auth/session").then(data=>{state.user=data.user;state.sessionResolved=true;updateNav();maybeShowReleaseAnnouncement();}).catch(()=>{state.sessionResolved=true;updateNav();});
})();
