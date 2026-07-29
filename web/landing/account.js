(() => {
  "use strict";
  const state = { user:null, config:null, widgetId:null };
  const isZh = () => document.documentElement.dataset.lang === "zh";
  const t = (en, zh) => isZh() ? zh : en;
  const esc = value => String(value).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));

  document.body.insertAdjacentHTML("beforeend", `
    <section class="po-modal" id="po-account-modal" hidden aria-modal="true" role="dialog"><div class="po-dialog"><button class="po-close" type="button" aria-label="Close">&times;</button><div id="po-account-content"></div></div></section>
    <section class="po-modal" id="po-feedback-modal" hidden aria-modal="true" role="dialog"><div class="po-dialog"><button class="po-close" type="button" aria-label="Close">&times;</button><div id="po-feedback-content"></div></div></section>`);
  const accountModal = document.getElementById("po-account-modal");
  const feedbackModal = document.getElementById("po-feedback-modal");
  const accountContent = document.getElementById("po-account-content");
  const feedbackContent = document.getElementById("po-feedback-content");

  function open(modal){ modal.hidden=false; document.body.style.overflow="hidden"; setTimeout(()=>modal.querySelector("input,textarea,button")?.focus(),0); }
  function close(modal){
    modal.hidden=true; document.body.style.overflow="";
    if(state.widgetId!==null && window.turnstile){ try{window.turnstile.remove(state.widgetId);}catch(_){} state.widgetId=null; }
  }
  document.querySelectorAll(".po-modal").forEach(modal=>{
    modal.querySelector(".po-close").onclick=()=>close(modal);
    modal.onclick=event=>{ if(event.target===modal) close(modal); };
  });
  document.addEventListener("keydown", event=>{ if(event.key==="Escape") document.querySelectorAll(".po-modal:not([hidden])").forEach(close); });

  async function api(path, options={}){
    const response=await fetch(path,{credentials:"same-origin",...options,headers:{"content-type":"application/json",...(options.headers||{})}});
    const data=await response.json().catch(()=>({message:"The observatory returned an unreadable response."}));
    if(!response.ok) throw new Error(data.message||"Request failed.");
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
  function updateNav(){
    const button=document.getElementById("account-open");
    button?.classList.toggle("is-signed-in",Boolean(state.user));
    const label=document.getElementById("account-label");
    if(label) label.textContent=state.user?.username||t("Account","账号");
  }

  function renderAccount(mode="login"){
    if(state.user){
      accountContent.innerHTML=`<h2>${t("Observer account","观测员账号")}</h2>
        <p class="po-lead">${t("Your field record can follow you between browsers.","你的观测记录可以在不同浏览器之间同步。")}</p>
        <div class="po-user-panel"><div class="po-user-name">${esc(state.user.username)}</div>
        <div class="po-sync">${t("Cloud archive connected. The game synchronises after sign-in and whenever progress is saved.","云端档案已连接。登录后以及游戏保存进度时会自动同步。")}</div>
        <button class="po-secondary" id="po-open-profile" type="button">${t("Open observer profile","打开个人主页")}</button>
        <button class="po-secondary" id="po-open-friends" type="button">${t("Friends and online status","好友与在线状态")}</button>
        ${state.user.role==="admin"?'<a class="po-secondary" href="admin/" style="display:grid;place-items:center;text-decoration:none">Open feedback console</a>':""}
        <button class="po-secondary" id="po-change-password" type="button">${t("Change password","修改密码")}</button>
        <button class="po-secondary" id="po-logout" type="button">${t("Sign out","退出登录")}</button></div>`;
      document.getElementById("po-change-password").onclick=renderPasswordChange;
      document.getElementById("po-open-profile").onclick=()=>{close(accountModal);document.dispatchEvent(new CustomEvent("po:open-social",{detail:{tab:"profile"}}));};
      document.getElementById("po-open-friends").onclick=()=>{close(accountModal);document.dispatchEvent(new CustomEvent("po:open-social",{detail:{tab:"friends"}}));};
      document.getElementById("po-logout").onclick=async()=>{ await api("/api/auth/logout",{method:"POST",body:"{}"}); state.user=null; updateNav(); document.dispatchEvent(new CustomEvent("po:session-changed")); renderAccount(); };
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
        state.user=data.user; updateNav(); document.dispatchEvent(new CustomEvent("po:session-changed")); renderAccount();
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
    feedbackContent.innerHTML=`<h2>${t("Send a field report","提交观测反馈")}</h2>
      <p class="po-lead">${t("A bug, a rough edge, or an idea worth trying: every useful signal reaches the developer console.","无论是问题、体验不顺，还是值得尝试的点子，都会直接进入开发者反馈台。")}</p>
      <form id="po-feedback-form">
        <label class="po-field">${t("Signal type","反馈类型")}<select name="category"><option value="bug">${t("Bug","错误")}</option><option value="idea">${t("Idea","建议")}</option><option value="visual">${t("Visual","画面")}</option><option value="audio">${t("Audio","声音")}</option><option value="story">${t("Story or guidance","剧情或引导")}</option><option value="other">${t("Other","其他")}</option></select></label>
        <label class="po-field">${t("What did you notice?","你发现了什么？")}<textarea name="message" minlength="8" maxlength="4000" required></textarea></label>
        <label class="po-honeypot">Website<input name="website" tabindex="-1" autocomplete="off"></label><div id="po-feedback-turnstile"></div>
        <button class="po-primary" type="submit">${t("Transmit report","发送反馈")}</button><p class="po-status" id="po-feedback-status" role="status"></p>
      </form>`;
    turnstile(document.getElementById("po-feedback-turnstile")).catch(()=>{});
    document.getElementById("po-feedback-form").onsubmit=async event=>{
      event.preventDefault();
      const form=new FormData(event.currentTarget), submit=event.currentTarget.querySelector('[type="submit"]'), status=document.getElementById("po-feedback-status");
      submit.disabled=true; status.textContent="";
      try{
        const data=await api("/api/feedback",{method:"POST",body:JSON.stringify({category:form.get("category"),message:form.get("message"),website:form.get("website"),turnstileToken:challengeToken(),page:location.href,context:{language:document.documentElement.dataset.lang,viewport:`${innerWidth}x${innerHeight}`}})});
        feedbackContent.innerHTML=`<div class="po-receipt"><strong>${t("Signal received.","反馈已送达。")}</strong><p>${t("Thank you for showing us where the observatory can see more clearly. Your report is now waiting in the developer console.","谢谢你认真告诉我们哪里还不够好。这条反馈已经进入开发者工作台。")}</p><p>${t("Receipt","回执编号")}: <code>${esc(data.receipt)}</code></p>${data.conversationId?`<p>${t("A personal thank-you letter is waiting in your inbox. The developer can continue replying there.","一封专门写给你的感谢信已经送到信箱，开发者之后也可以在那里继续回复你。")}</p><button class="po-primary" id="po-open-feedback-letter" type="button">${t("Read the letter","查看感谢信")}</button>`:""}</div>`;
        const letterButton=document.getElementById("po-open-feedback-letter");
        if(letterButton) letterButton.onclick=()=>{close(feedbackModal);document.dispatchEvent(new CustomEvent("po:open-inbox"));};
      }catch(error){ status.textContent=error.message; if(state.widgetId!==null) window.turnstile?.reset(state.widgetId); submit.disabled=false; }
    };
  }
  document.getElementById("account-open")?.addEventListener("click",()=>{renderAccount();open(accountModal);});
  document.getElementById("feedback-open")?.addEventListener("click",()=>{renderFeedback();open(feedbackModal);});
  api("/api/auth/session").then(data=>{state.user=data.user;updateNav();}).catch(updateNav);
})();
