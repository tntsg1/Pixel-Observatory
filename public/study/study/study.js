(() => {
  "use strict";
  const app = document.getElementById("study-app");
  const storageKey = "pixel-observatory:study-session:v1";
  const origin = location.origin;
  const t0 = Date.now();
  let session = null;
  let serverState = null;
  let phaseStart = Date.now();

  const questions = [
    ["workflow", "Which step normally comes between naked-eye observation and looking through the main telescope?", [["finder", "Use a finder scope to narrow the target."], ["focus", "Adjust the focuser."], ["filter", "Add a colour filter."], ["report", "Write an observation report."]]],
    ["magnification", "Which eyepiece change normally gives a higher magnification?", [["short", "Use a shorter focal-length eyepiece."], ["long", "Use a longer focal-length eyepiece."], ["aperture", "Close the telescope aperture."], ["cloud", "Wait for cloud cover."]]],
    ["focus", "A target is dim and soft even when it is centred. What should you adjust first?", [["focuser", "The focuser."], ["mount", "The tripod height."], ["finder", "The finder scope cap."], ["credits", "The mission credits."]]],
    ["seeing", "On a night with poor atmospheric seeing, what is usually the better choice?", [["lower", "Use less magnification."], ["higher", "Use as much magnification as possible."], ["ignore", "Ignore the atmosphere."], ["aperture", "Make the target larger with a bigger aperture only."]]],
    ["tracking", "Why does a telescope need tracking during a long observation?", [["rotation", "Earth's rotation moves the sky across the field."], ["moon", "The Moon changes colour."], ["battery", "The eyepiece battery drains."], ["mirror", "The mirror becomes transparent."]]],
    ["chromatic", "What causes chromatic aberration in a simple refracting telescope?", [["refraction", "Different colours refract by different amounts."], ["radio", "Radio signals have colour."], ["tracking", "The mount tracks too smoothly."], ["dust", "Dust changes focal length."]]],
    ["light", "How does light pollution most directly affect a faint deep-sky observation?", [["glow", "Sky glow reduces contrast."], ["magnify", "It increases useful magnification."], ["cool", "It cools the optics."], ["track", "It improves tracking."]]],
    ["infrared", "Why are many space-infrared images shown in false colour?", [["false_colour", "Infrared wavelengths are assigned visible colours to show structure."], ["printer", "The printer cannot make black."], ["weather", "Clouds add colour in space."], ["mirror", "Mirrors only reflect coloured light."]]],
    ["radio", "What is a FAST radio observation mainly trying to recover?", [["signal", "A weak patterned radio signal in noisy data."], ["photo", "A conventional colour photograph."], ["temperature", "The surface temperature of a planet."], ["satellite", "A new optical lens."]]],
    ["dispersion", "In a pulsar observation, dispersion correction aligns what?", [["arrival", "Arrival times across frequency channels."], ["stars", "The shapes of visible stars."], ["mount", "The telescope legs."], ["clouds", "Cloud layers."]]],
  ];

  function escapeHtml(value) { return String(value || "").replace(/[&<>'"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;","\"":"&quot;"})[c]); }
  function saveSession() { localStorage.setItem(storageKey, JSON.stringify(session)); }
  function loadSession() { try { session = JSON.parse(localStorage.getItem(storageKey) || "null"); } catch (_) { session = null; } }
  async function api(path, body) {
    const response = await fetch(`${origin}${path}`, { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(body) });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message || "The study service could not finish that request.");
    return data;
  }
  function authenticated(body = {}) { return {...body, participantId: session?.participantId, token: session?.token}; }
  function stageLabel(stage) { return stage === "reading_posttest" ? "reading_posttest" : stage; }
  function updateProgress() {
    const current = serverState?.nextStage || "pretest";
    const order = ["pretest", "reading", "reading_posttest", "game", "posttest", "experience", "complete"];
    const index = order.indexOf(current);
    document.querySelectorAll("[data-step]").forEach(node => {
      const own = order.indexOf(node.dataset.step);
      node.classList.toggle("is-current", own === index || (current === "experience" && node.dataset.step === "posttest"));
      node.classList.toggle("is-done", own < index);
    });
  }
  function view(markup) { app.innerHTML = `<div class="study-view">${markup}</div>`; updateProgress(); }
  function showError(message) { const node = app.querySelector(".error"); if (node) node.textContent = message; }
  function home() {
    view(`<span class="eyebrow">Pixel Observatory study</span><h1>Learn the instrument. Then tell us what changed.</h1><p class="lead">This optional research flow records how a short reading and an instrument-based astronomy game affect conceptual understanding. It does not require a game account, name, or email address.</p><div class="consent"><label><input id="consent" type="checkbox"> I am choosing to participate. I understand that an anonymous study code, my responses, and active game time will be recorded for research.</label></div><p class="fine">You may close this tab at any time. Do not use this page for formal data collection until your supervisor has approved the participant information and consent wording.</p><div class="actions"><button class="primary" id="begin" type="button">Begin the study</button><button class="text-button" id="resume" type="button">Resume a saved anonymous session</button></div><p class="error" role="alert"></p>`);
    document.getElementById("begin").onclick = async () => {
      if (!document.getElementById("consent").checked) return showError("Please confirm consent before beginning.");
      try {
        const data = await api("/api/study/enroll", {consent: true, language: navigator.language.startsWith("zh") ? "zh" : "en"});
        session = {participantId: data.participantId, token: data.token}; saveSession(); serverState = data.state; render();
      } catch (error) { showError(error.message); }
    };
    document.getElementById("resume").onclick = () => session ? refresh() : showError("No anonymous study session is stored in this browser.");
  }
  function questionMarkup(prefix) {
    return questions.map(([id, text, options], index) => `<fieldset class="question"><strong>${index + 1}. ${escapeHtml(text)}</strong><div class="options">${options.map(([value, label]) => `<label class="option"><input required name="${prefix}-${id}" type="radio" value="${value}"><span>${escapeHtml(label)}</span></label>`).join("")}</div></fieldset>`).join("");
  }
  function test(phase, title, copy) {
    phaseStart = Date.now();
    view(`<span class="eyebrow">${phase === "pre" ? "Before reading" : phase === "reading_post" ? "After reading" : "After observing"}</span><h2>${title}</h2><p>${copy}</p><form id="test-form" class="study-form">${questionMarkup(phase)}<div class="actions"><button class="primary" type="submit">Continue</button>${phase === "pre" ? "" : '<button class="text-button" type="button" data-withdraw>Withdraw this study record</button>'}</div><p class="error" role="alert"></p></form>`);
    const form = document.getElementById("test-form");
    form.onsubmit = async event => {
      event.preventDefault();
      const answers = Object.fromEntries(questions.map(([id]) => [id, new FormData(form).get(`${phase}-${id}`)]));
      if (Object.values(answers).some(value => !value)) return showError("Please answer every question before continuing.");
      try {
        const data = await api("/api/study/submit", authenticated({phase, answers, durationSeconds: Math.round((Date.now() - phaseStart) / 1000)}));
        serverState = data.state; render(data.result && phase !== "post" ? `Response recorded: ${data.result.score}/${data.result.maxScore}.` : "Response recorded.");
      } catch (error) { showError(error.message); }
    };
    form.querySelector("[data-withdraw]")?.addEventListener("click", withdraw);
  }
  function reading() {
    view(`<span class="eyebrow">Short reading</span><h2>How an observation becomes evidence</h2><p>Read the four notes before completing the knowledge check. They describe the causal model used by Pixel Observatory.</p><div class="reading"><article><h3>1. The instrument changes the result</h3><p>Assembly, focus, collimation, eyepiece focal length, and tracking are not cosmetic settings. They change clarity, stability, magnification, and field of view.</p></article><article><h3>2. The atmosphere has a limit</h3><p>Cloud cover and light pollution reduce contrast. Poor atmospheric seeing also limits useful magnification: using more magnification can make a target worse rather than better.</p></article><article><h3>3. Different telescopes collect different evidence</h3><p>Optical telescopes show visible light. Infrared observations use false colour to represent invisible wavelength bands. FAST receives radio data and searches for faint structured signals, such as periodic pulsar pulses.</p></article><article><h3>4. A clear result is produced, not granted</h3><p>Finding a target begins with the naked eye and finder scope, then continues through the main telescope. Focus, tracking, environmental conditions, and a suitable configuration determine what becomes visible.</p></article></div><div class="actions"><button class="primary" id="reading-done">I have finished reading</button><button class="text-button" data-withdraw>Withdraw this study record</button></div><p class="error" role="alert"></p>`);
    document.getElementById("reading-done").onclick = async () => {
      try { const data = await api("/api/study/advance", authenticated({action: "finish_reading"})); serverState = data.state; render(); } catch (error) { showError(error.message); }
    };
    app.querySelector("[data-withdraw]").onclick = withdraw;
  }
  function game() {
    const seconds = Number(serverState?.gameActiveSeconds || 0);
    const minimum = Number(serverState?.minimumGameSeconds || 300);
    const remaining = Math.max(0, minimum - seconds);
    view(`<span class="eyebrow">Game session</span><h2>Operate the observatory.</h2><p>Open the game in a new tab. Follow the tutorial until you have assembled, located, and observed at least one target. This page records only active time for this anonymous study code.</p><div class="game-callout"><strong>Active observation time: <span class="timer">${Math.floor(seconds / 60)}m ${seconds % 60}s</span></strong><span class="fine">${remaining ? `${Math.ceil(remaining / 60)} more active minute(s) are required before the final questionnaire unlocks.` : "The final questionnaire is ready."}</span><div class="actions"><button class="primary" id="open-game">Open Pixel Observatory</button><button class="secondary" id="refresh-time">Refresh time</button>${remaining ? "" : '<button class="secondary" id="finish-game">Continue to final questions</button>'}</div></div><div class="actions"><button class="text-button" data-withdraw>Withdraw this study record</button></div><p class="error" role="alert"></p>`);
    document.getElementById("open-game").onclick = async () => {
      // Open the tab during the click itself so Safari and Chrome do not treat
      // the subsequent async stage update as an unsolicited popup.
      const gameWindow = window.open("about:blank", "pixel-observatory-study-game");
      try {
        const data = await api("/api/study/advance", authenticated({action: "start_game"})); serverState = data.state;
        const url = new URL("/game/", origin); url.searchParams.set("study", session.participantId); url.searchParams.set("study_token", session.token);
        if (gameWindow) gameWindow.location.replace(url);
        else location.assign(url);
      } catch (error) { gameWindow?.close(); showError(error.message); }
    };
    document.getElementById("refresh-time").onclick = refresh;
    document.getElementById("finish-game")?.addEventListener("click", async () => {
      try { const data = await api("/api/study/advance", authenticated({action: "finish_game"})); serverState = data.state; render(); } catch (error) { showError(error.message); }
    });
    app.querySelector("[data-withdraw]").onclick = withdraw;
  }
  function experience() {
    phaseStart = Date.now();
    const items = [["interest", "The activity increased my interest in astronomical observation."], ["causality", "The game made the relationship between my actions and the observation result clear."], ["guidance", "The guidance made it clear what I should do next."], ["difficulty", "The difficulty felt manageable."], ["achievement", "I felt a sense of accomplishment after completing the observation."]];
    view(`<span class="eyebrow">Experience</span><h2>One last field note.</h2><p>There are no right answers in this final part. Please select the response that best represents your experience.</p><form id="experience-form" class="study-form">${items.map(([id, label]) => `<fieldset class="question"><strong>${escapeHtml(label)}</strong><div class="likert">${[1,2,3,4,5].map(value => `<label title="${value}"><input required type="radio" name="experience-${id}" value="${value}"><span>${value}</span></label>`).join("")}</div></fieldset>`).join("")}<fieldset class="question"><strong>What was the most useful or confusing part of the activity? (optional)</strong><textarea name="experience-note" maxlength="1200" placeholder="Write a short field note..."></textarea></fieldset><div class="actions"><button class="primary" type="submit">Submit study record</button><button class="text-button" type="button" data-withdraw>Withdraw this study record</button></div><p class="error" role="alert"></p></form>`);
    const form = document.getElementById("experience-form");
    form.onsubmit = async event => {
      event.preventDefault();
      const answers = Object.fromEntries([...new FormData(form).entries()].map(([key, value]) => [key.replace("experience-", ""), value]));
      try { const data = await api("/api/study/submit", authenticated({phase: "experience", answers, durationSeconds: Math.round((Date.now() - phaseStart) / 1000)})); serverState = data.state; render("Your anonymous study record has been saved."); } catch (error) { showError(error.message); }
    };
    form.querySelector("[data-withdraw]").onclick = withdraw;
  }
  function completed(message = "") { view(`<span class="eyebrow">Study complete</span><h1>Thank you for taking the time to observe carefully.</h1><p class="lead">Your responses were stored under an anonymous research code. They can help evaluate whether hands-on instrument operation makes astronomy concepts easier to understand.</p>${message ? `<p class="score">${escapeHtml(message)}</p>` : ""}<div class="actions"><a class="primary" href="/">Return to Pixel Observatory</a><button class="text-button" id="forget">Remove this study code from this browser</button></div>`); document.getElementById("forget").onclick = () => { localStorage.removeItem(storageKey); session = null; home(); }; }
  async function withdraw() { if (!confirm("Withdraw this anonymous study record? Stored answers will no longer be used in the study flow.")) return; try { await api("/api/study/withdraw", authenticated()); localStorage.removeItem(storageKey); session = null; serverState = null; home(); } catch (error) { showError(error.message); } }
  function render(message = "") {
    if (!serverState) return home();
    const stage = stageLabel(serverState.nextStage);
    if (stage === "pretest") return test("pre", "A short baseline check", "Answer from what you know now. This is not a graded exam.");
    if (stage === "reading") return reading();
    if (stage === "reading_posttest") return test("reading_post", "What did the reading make clearer?", "Use the notes you just read. Your response will be compared with your first attempt.");
    if (stage === "game") return game();
    if (stage === "posttest") return test("post", "After operating the observatory", "Answer the same concepts after your game session. Do not look back at the reading notes.");
    if (stage === "experience") return experience();
    return completed(message);
  }
  async function refresh() { try { const data = await api("/api/study/session", authenticated()); serverState = data.state; render(); } catch (_) { home(); } }
  loadSession(); if (session?.participantId && session?.token) refresh(); else home();
})();
