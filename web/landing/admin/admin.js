(() => {
  "use strict";
  const $ = selector => document.querySelector(selector);
  const $$ = selector => [...document.querySelectorAll(selector)];
  const notice = $("#notice");
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const percent = value => `${Math.round(Number(value || 0) * 100)}%`;
  const duration = seconds => `${Math.floor(Number(seconds || 0) / 60)}m ${Math.round(Number(seconds || 0) % 60)}s`;
  const date = timestamp => timestamp ? new Date(Number(timestamp) * 1000).toLocaleString() : "-";

  async function api(path, options = {}) {
    const response = await fetch(path, {
      credentials: "same-origin",
      ...options,
      headers: {"content-type":"application/json", ...(options.headers || {})},
    });
    const data = await response.json().catch(() => ({message:"Unreadable server response."}));
    if (!response.ok) {
      const error = new Error(data.message || "Request failed.");
      error.status = response.status;
      throw error;
    }
    return data;
  }

  function reportError(error) {
    notice.textContent = `${error.message} Sign in with an administrator account on the main site first.`;
  }

  function reportResearchError(error) {
    notice.textContent = error.status === 403
      ? "Administrator access required. Sign in with an administrator account on the main site first."
      : `Research database is temporarily unavailable. No research records were erased. ${error.message}`;
  }

  async function loadFeedback() {
    notice.textContent = "Listening for field reports...";
    const params = new URLSearchParams();
    if ($("#status-filter").value) params.set("status", $("#status-filter").value);
    if ($("#category-filter").value) params.set("category", $("#category-filter").value);
    try {
      const data = await api(`/api/admin/feedback?${params}`);
      $("#feedback-count").textContent = `${data.feedback.length} reports`;
      $("#feedback-list").innerHTML = data.feedback.map(item => `
        <article data-id="${esc(item.id)}" data-conversation="${esc(item.conversation_id || "")}">
          <div class="meta"><b>${esc(item.id)}</b><span class="category">${esc(item.category)}</span><span>${esc(item.username_snapshot)}</span><time>${date(item.created_at)}</time><span>${esc(item.page || "")}</span></div>
          <div class="message">${esc(item.message)}</div>
          <div class="admin-grid">
            <section><h3>Internal handling</h3><p>Only administrators can see this status and note.</p><div class="actions"><select class="item-status">${["new","reviewing","planned","resolved","closed"].map(status => `<option ${status === item.status ? "selected" : ""}>${status}</option>`).join("")}</select><textarea class="item-note" placeholder="Private developer note">${esc(item.admin_note || "")}</textarea><button class="save" type="button">Save internally</button></div></section>
            <section class="player-reply"><h3>Reply to player</h3>${item.conversation_id ? `<p>This text is sent to <b>${esc(item.username_snapshot)}</b> through their inbox.</p><textarea class="reply-body" maxlength="4000" placeholder="Write a warm, useful update..."></textarea><button class="send-reply" type="button">Send to player</button><span class="reply-status" role="status"></span>` : `<p>This guest report has no inbox to reply to.</p>`}</section>
          </div>
        </article>`).join("") || "<p>No reports match these filters.</p>";
      notice.textContent = "";
      $$(".save").forEach(button => button.onclick = saveFeedback);
      $$(".send-reply").forEach(button => button.onclick = sendReply);
    } catch (error) { reportError(error); $("#feedback-list").innerHTML = ""; }
  }

  async function saveFeedback(event) {
    const article = event.target.closest("article");
    event.target.disabled = true;
    try {
      await api(`/api/admin/feedback/${encodeURIComponent(article.dataset.id)}`, {method:"PATCH", body:JSON.stringify({status:article.querySelector(".item-status").value, adminNote:article.querySelector(".item-note").value})});
      event.target.textContent = "Saved";
      setTimeout(() => event.target.textContent = "Save internally", 1200);
    } catch (error) { reportError(error); } finally { event.target.disabled = false; }
  }

  async function sendReply(event) {
    const article = event.target.closest("article");
    const body = article.querySelector(".reply-body");
    const status = article.querySelector(".reply-status");
    if (!body.value.trim()) { status.textContent = "Write a reply first."; return; }
    event.target.disabled = true;
    try {
      await api(`/api/messages/conversations/${encodeURIComponent(article.dataset.conversation)}/messages`, {method:"POST", body:JSON.stringify({body:body.value})});
      body.value = ""; status.textContent = "Delivered to the player's inbox.";
    } catch (error) { status.textContent = error.message; } finally { event.target.disabled = false; }
  }

  async function loadOverview() {
    notice.textContent = "Calculating research evidence...";
    try {
      const {summary} = await api("/api/admin/research/summary");
      const metrics = [
        ["Participants", summary.totalParticipants],
        ["Text route", summary.routeCounts.archive_text],
        ["Gameplay route", summary.routeCounts.field_gameplay],
        ["Text completion", percent(summary.routeCompletionRates.archive_text)],
        ["Gameplay completion", percent(summary.routeCompletionRates.field_gameplay)],
        ["Mean accuracy", percent(summary.averageScore)],
        ["Mean node time", duration(summary.averageDurationSeconds)],
        ["Skipped nodes", `${summary.skippedEvents} (${percent(summary.skipRate)})`],
        ["Incomplete / dropout", `${summary.incomplete} (${percent(summary.incompleteRate)})`],
        ["Withdrawn", `${summary.withdrawn} (${percent(summary.withdrawalRate)})`],
        ["Late submissions", summary.lateResponses],
        ["English participants", `${summary.languageCounts.en} (${percent(summary.totalParticipants ? summary.languageCounts.en / summary.totalParticipants : 0)})`],
        ["Chinese participants", `${summary.languageCounts.zh} (${percent(summary.totalParticipants ? summary.languageCounts.zh / summary.totalParticipants : 0)})`],
      ];
      $("#research-metrics").innerHTML = metrics.map(([label, value]) => `<article><span>${esc(label)}</span><strong>${esc(value)}</strong></article>`).join("");
      $("#node-summary").innerHTML = Object.entries(summary.nodeSubmissions).map(([node, value]) => `<div class="data-row"><b>${esc(node)}</b><span>${esc(value)} submissions</span></div>`).join("");
      $("#option-summary").innerHTML = Object.entries(summary.optionDistributions).map(([question, options]) => `<details><summary>${esc(summary.questionLabels?.[question] || question)} <span>${Object.values(options).reduce((a,b) => a + b, 0)} answers</span></summary>${Object.entries(options).map(([option, value]) => `<div class="data-row"><b>${esc(summary.optionLabels?.[question]?.[option] || option)}</b><span>${esc(value)}</span></div>`).join("")}</details>`).join("") || "<p>No submitted answers yet.</p>";
      notice.textContent = "";
    } catch (error) { reportResearchError(error); }
  }

  async function loadParticipants() {
    notice.textContent = "Loading anonymous records...";
    const params = new URLSearchParams();
    if ($("#participant-search").value.trim()) params.set("q", $("#participant-search").value.trim());
    if ($("#participant-route").value) params.set("route", $("#participant-route").value);
    try {
      const data = await api(`/api/admin/research/participants?${params}`);
      $("#participant-list").innerHTML = data.participants.map(participant => `<button type="button" data-participant="${esc(participant.participantId)}"><strong>${esc(participant.participantId)}</strong><span>${participant.routeArm === "archive_text" ? "Text route" : "Gameplay route"} / ${participant.responseCount}/6 nodes</span><small>${participant.complete ? "Complete" : participant.withdrawn ? "Withdrawn" : `Current: ${esc(participant.currentNode || "waiting")}`}</small></button>`).join("") || "<p>No participants match this filter.</p>";
      $$("[data-participant]").forEach(button => button.onclick = () => loadParticipant(button.dataset.participant));
      notice.textContent = "";
    } catch (error) { reportResearchError(error); }
  }

  async function loadParticipant(id) {
    const detail = $("#participant-detail");
    detail.innerHTML = "<p>Loading question-level evidence...</p>";
    try {
      const data = await api(`/api/admin/research/participants/${encodeURIComponent(id)}`);
      const participant = data.participant;
      detail.innerHTML = `<div class="detail-heading"><small>${esc(participant.routeArm)}</small><h2>${esc(participant.participantId)}</h2><p>${esc(participant.language.toUpperCase())} / ${participant.complete ? "Complete" : participant.withdrawn ? "Withdrawn" : "In progress"}</p></div>${data.responses.map(response => `<section class="response-card"><header><b>Node ${esc(response.nodeId)}</b><span>${response.score}/${response.maxScore} / ${duration(response.durationSeconds)} / ${date(response.createdAt)}${response.lateResponse ? " / Late" : ""}</span></header>${response.answers.map(answer => `<div class="answer ${answer.correct ? "is-correct" : "is-wrong"}"><p>${esc(answer.prompt)}</p><span>Selected: ${esc(answer.selectedAnswer || "No answer")}</span><span>Correct: ${esc(answer.correctAnswer)}</span></div>`).join("")}</section>`).join("") || "<p>No submitted questionnaires.</p>"}<section class="event-log"><h3>Events</h3>${data.events.map(event => `<div class="data-row"><b>${esc(event.type)}</b><span>${date(event.createdAt)}</span></div>`).join("") || "<p>No events recorded.</p>"}</section>`;
    } catch (error) { detail.innerHTML = `<p class="error">${esc(error.message)}</p>`; }
  }

  async function downloadResearch() {
    const button = $("#download-research");
    const status = $("#export-status");
    button.disabled = true; status.textContent = "Preparing CSV...";
    try {
      const response = await fetch("/api/admin/research/export.csv", {credentials:"same-origin"});
      if (!response.ok) { const data = await response.json().catch(() => ({})); throw new Error(data.message || "Export failed."); }
      const link = document.createElement("a");
      link.href = URL.createObjectURL(await response.blob());
      link.download = `pixel-observatory-research-${new Date().toISOString().slice(0,10)}.csv`;
      link.click(); URL.revokeObjectURL(link.href); status.textContent = "CSV downloaded.";
    } catch (error) { status.textContent = error.message; } finally { button.disabled = false; }
  }

  async function activateTab(name) {
    $$("[data-tab]").forEach(button => button.classList.toggle("is-active", button.dataset.tab === name));
    $$("[data-panel]").forEach(panel => panel.classList.toggle("is-active", panel.dataset.panel === name));
    notice.textContent = "";
    if (name === "feedback") await loadFeedback();
    if (name === "overview") await loadOverview();
    if (name === "participants") await loadParticipants();
  }

  $$("[data-tab]").forEach(button => button.onclick = () => activateTab(button.dataset.tab));
  $("#refresh-feedback").onclick = loadFeedback;
  $("#status-filter").onchange = loadFeedback;
  $("#category-filter").onchange = loadFeedback;
  $("#refresh-overview").onclick = loadOverview;
  $("#search-participants").onclick = loadParticipants;
  $("#participant-route").onchange = loadParticipants;
  $("#participant-search").onkeydown = event => { if (event.key === "Enter") loadParticipants(); };
  $("#download-research").onclick = downloadResearch;
  loadFeedback();
})();
