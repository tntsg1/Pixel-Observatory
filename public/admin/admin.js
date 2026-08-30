(() => {
  "use strict";
  const list = document.getElementById("feedback-list");
  const notice = document.getElementById("notice");
  const count = document.getElementById("count");
  const statusFilter = document.getElementById("status-filter");
  const categoryFilter = document.getElementById("category-filter");
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));

  async function api(path, options = {}) {
    const response = await fetch(path, {
      credentials: "same-origin",
      ...options,
      headers: {"content-type":"application/json", ...(options.headers || {})},
    });
    const data = await response.json().catch(() => ({message:"Unreadable server response."}));
    if (!response.ok) throw new Error(data.message || "Request failed.");
    return data;
  }
  async function load() {
    notice.textContent = "Listening for field reports...";
    const params = new URLSearchParams();
    if (statusFilter.value) params.set("status", statusFilter.value);
    if (categoryFilter.value) params.set("category", categoryFilter.value);
    try {
      const data = await api(`/api/admin/feedback?${params}`);
      count.textContent = `${data.feedback.length} reports`;
      list.innerHTML = data.feedback.map(item => `
        <article data-id="${esc(item.id)}" data-conversation="${esc(item.conversation_id || "")}">
          <div class="meta"><b>${esc(item.id)}</b><span class="category">${esc(item.category)}</span>
            <span>${esc(item.username_snapshot)}</span><time>${new Date(item.created_at * 1000).toLocaleString()}</time>
            <span>${esc(item.page || "")}</span></div>
          <div class="message">${esc(item.message)}</div>
          <div class="admin-grid">
            <section class="internal-tools">
              <h2>Internal handling</h2>
              <p>Only administrators can see this status and note.</p>
              <div class="actions">
                <select class="item-status">${["new","reviewing","planned","resolved","closed"].map(status => `<option ${status === item.status ? "selected" : ""}>${status}</option>`).join("")}</select>
                <textarea class="item-note" placeholder="Private developer note">${esc(item.admin_note || "")}</textarea>
                <button class="save" type="button">Save internally</button>
              </div>
            </section>
            <section class="player-reply">
              <h2>Reply to player</h2>
              ${item.conversation_id ? `
                <p>This text is sent to <b>${esc(item.username_snapshot)}</b> through their inbox.</p>
                <textarea class="reply-body" maxlength="4000" placeholder="Write a warm, useful update..."></textarea>
                <button class="send-reply" type="button">Send to player</button>
                <span class="reply-status" role="status"></span>` :
                `<p class="guest-note">This report was submitted without a signed-in account, so there is no inbox to reply to.</p>`}
            </section>
          </div>
        </article>`).join("") || "<p>No reports match these filters.</p>";
      notice.textContent = "";
      list.querySelectorAll(".save").forEach(button => button.onclick = save);
      list.querySelectorAll(".send-reply").forEach(button => button.onclick = sendReply);
    } catch (error) {
      notice.textContent = `${error.message} Sign in with an administrator account on the main site first.`;
      list.innerHTML = "";
    }
  }
  async function save(event) {
    const article = event.target.closest("article");
    event.target.disabled = true;
    try {
      await api(`/api/admin/feedback/${encodeURIComponent(article.dataset.id)}`, {
        method: "PATCH",
        body: JSON.stringify({
          status: article.querySelector(".item-status").value,
          adminNote: article.querySelector(".item-note").value,
        }),
      });
      event.target.textContent = "Saved";
      setTimeout(() => event.target.textContent = "Save internally", 1200);
    } catch (error) {
      notice.textContent = error.message;
    } finally {
      event.target.disabled = false;
    }
  }
  async function sendReply(event) {
    const article = event.target.closest("article");
    const body = article.querySelector(".reply-body");
    const status = article.querySelector(".reply-status");
    if (!body.value.trim()) {
      status.textContent = "Write a reply first.";
      return;
    }
    event.target.disabled = true;
    status.textContent = "Sending...";
    try {
      await api(`/api/messages/conversations/${encodeURIComponent(article.dataset.conversation)}/messages`, {
        method: "POST",
        body: JSON.stringify({body: body.value}),
      });
      body.value = "";
      status.textContent = "Delivered to the player's inbox.";
    } catch (error) {
      status.textContent = error.message;
    } finally {
      event.target.disabled = false;
    }
  }
  document.getElementById("refresh").onclick = load;
  statusFilter.onchange = load;
  categoryFilter.onchange = load;
  load();
})();
