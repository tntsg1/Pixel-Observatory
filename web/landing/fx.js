/* Landing-page interaction layer (the star-dust background lives in fx-space.js):
   aperture intro, decoding titles, chapter numerals, a telescope-reticle cursor
   that snaps around controls, comet trail and starbursts, magnetic buttons,
   tilting spotlight cards, and per-chapter interactions — dark adaptation on the
   naked-eye sky, a magnifier on every eyepiece view and diagram, a HUD that
   tracks the pointer, parts flying into the refractor, the find→center→focus→
   understand sequence, the instrument path unlocking, panel reveals.
   Everything degrades to the original page when a feature is unavailable. */
(function () {
  "use strict";
  var root = document.documentElement;
  var calm = /[?&]fx=calm(&|$)/.test(location.search); // always full motion, like the Stellar Ascension page
  root.classList.add("fx-on");
  if (calm) root.classList.add("fx-calm");

  var finePointer = matchMedia("(hover: hover) and (pointer: fine)").matches;
  var hero = document.querySelector(".hero");
  var firstVisit = scrollY < 40 && !calm;
  try {
    if (sessionStorage.getItem("fx-intro-seen")) firstVisit = false;
    sessionStorage.setItem("fx-intro-seen", "1");
  } catch (e) {}
  function $$(sel, scope) { return [].slice.call((scope || document).querySelectorAll(sel)); }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function onView(el, cb, threshold) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { io.unobserve(entry.target); cb(entry.target); }
      });
    }, { threshold: threshold || 0.35 });
    io.observe(el);
  }

  /* ================= aperture intro ================= */
  if (firstVisit && hero) {
    var iris = document.createElement("div");
    iris.className = "fx-iris";
    iris.setAttribute("aria-hidden", "true");
    document.body.appendChild(iris);
    iris.addEventListener("animationend", function (e) { if (e.animationName === "fxIris") iris.remove(); });
    setTimeout(function () { iris.remove(); }, 2600);
  }

  /* ================= decoding text ================= */
  var GLYPHS = "▖▗▘▙▚▛▜▝▞▟░▒▓✦✧+*·ABCDEFGHJKLMNOPRSTUVXYZ0123456789";
  function decode(el, duration) {
    if (calm) return;
    var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    var nodes = [];
    while (walker.nextNode()) {
      var node = walker.currentNode;
      if (node.nodeValue.trim() && node.parentElement.offsetParent !== null) nodes.push({ node: node, text: node.nodeValue });
    }
    if (!nodes.length) return;
    var total = nodes.reduce(function (sum, item) { return sum + item.text.length; }, 0);
    var began = performance.now();
    function step(now) {
      var progress = Math.min(1, (now - began) / duration);
      var offset = 0;
      nodes.forEach(function (item) {
        var out = "";
        for (var i = 0; i < item.text.length; i++) {
          var ch = item.text[i];
          var reveal = (offset + i) / total;
          if (ch === " " || progress >= 1 || progress * 1.25 - 0.25 > reveal) out += ch;
          else out += GLYPHS[(Math.random() * GLYPHS.length) | 0];
        }
        offset += item.text.length;
        item.node.nodeValue = out;
      });
      if (progress < 1) requestAnimationFrame(step);
      else nodes.forEach(function (item) { item.node.nodeValue = item.text; });
    }
    requestAnimationFrame(step);
  }
  var title = document.querySelector(".hero h1");
  if (title) setTimeout(function () { decode(title, 1500); }, firstVisit ? 900 : 200);
  var heroTag = document.querySelector(".hero-tag");
  if (heroTag) setTimeout(function () { decode(heroTag, 1100); }, firstVisit ? 1300 : 400);

  $$("main .eyebrow, main h2, .finale h2, .mechanism-code").forEach(function (el) {
    onView(el, function (t) {
      if (t.tagName === "H2") t.classList.add("fx-sweep");
      else decode(t, t.classList.contains("mechanism-code") ? 1300 : 900);
    }, 0.6);
  });

  /* ================= chapter numerals ================= */
  var numerals = [];
  $$("main .eyebrow").forEach(function (eyebrow) {
    var m = /Chapter\s+(\d+)/i.exec(eyebrow.textContent);
    if (!m) return;
    var host = eyebrow.parentElement;
    if (getComputedStyle(host).position === "static") host.style.position = "relative";
    var num = document.createElement("span");
    num.className = "fx-chapnum";
    num.setAttribute("aria-hidden", "true");
    num.textContent = m[1];
    host.insertBefore(num, eyebrow);
    numerals.push(num);
    onView(num, function (n) { n.classList.add("is-in"); }, 0.2);
  });

  /* ================= reveal staggering ================= */
  [".eye-stats", ".terms", ".grid3", ".learn-ways", ".feat-grid", ".specs", ".obs-views", ".mechanism-list", ".tl"].forEach(function (sel) {
    $$(sel).forEach(function (group) {
      [].slice.call(group.children).forEach(function (child, i) {
        child.style.setProperty("--fx-i", i);
        child.classList.add("fx-stagger");
      });
      onView(group, function (g) { g.classList.add("fx-go"); }, 0.15);
    });
  });

  /* ================= count-up numbers ================= */
  $$(".project-number b, .eye-stat b, .spec b").forEach(function (el) {
    onView(el, function () {
      var node = el.firstChild;
      var match = node && node.nodeType === 3 && /^(\D{0,2})([\d,]*\.?\d+)(.*)$/.exec(node.nodeValue);
      if (!match) return;
      var raw = match[2];
      var target = parseFloat(raw.replace(/,/g, ""));
      if (!isFinite(target) || target === 0) return;
      var decimals = (raw.split(".")[1] || "").length;
      var comma = raw.indexOf(",") >= 0;
      var began = performance.now();
      function tick(now) {
        var p = Math.min(1, (now - began) / 1400);
        var v = target * (1 - Math.pow(1 - p, 4));
        var text = decimals ? v.toFixed(decimals) : String(Math.round(v));
        if (comma) text = Number(text).toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
        node.nodeValue = p < 1 ? match[1] + text + match[3] : match[0];
        if (p < 1) requestAnimationFrame(tick);
      }
      requestAnimationFrame(tick);
    }, 0.8);
  });

  /* ================= scroll beam + numeral parallax ================= */
  var beam = document.createElement("div");
  beam.className = "fx-beam";
  beam.setAttribute("aria-hidden", "true");
  document.body.appendChild(beam);
  var scrollTick = false;
  function onScroll() {
    scrollTick = false;
    var max = document.documentElement.scrollHeight - innerHeight;
    beam.style.transform = "scaleX(" + (max > 0 ? clamp(scrollY / max, 0, 1) : 0).toFixed(4) + ")";
    for (var i = 0; i < numerals.length; i++) {
      var r = numerals[i].parentElement.getBoundingClientRect();
      if (r.bottom < -200 || r.top > innerHeight + 200) continue;
      numerals[i].style.transform = "translate3d(0," + ((r.top - innerHeight * 0.3) * -0.18).toFixed(1) + "px,0)";
    }
  }
  addEventListener("scroll", function () {
    if (!scrollTick) { scrollTick = true; requestAnimationFrame(onScroll); }
  }, { passive: true });
  onScroll();

  /* ================= motto: find → center → focus → understand ================= */
  $$(".motto .steps").forEach(function (steps) {
    onView(steps, function () { steps.classList.add("fx-run"); }, 0.6);
    $$(".step", steps).forEach(function (s, i) { s.style.setProperty("--fx-i", i); });
    $$(".sep", steps).forEach(function (s, i) { s.style.setProperty("--fx-i", i); });
  });

  /* ================= instrument path unlocking ================= */
  $$(".tl").forEach(function (tl) {
    onView(tl, function () { tl.classList.add("fx-unlock"); }, 0.25);
  });

  /* ================= refractor parts fly in ================= */
  var FLY = [[0, 180], [-160, 60], [220, -120], [-240, -60], [200, 40], [160, -200], [-120, -220]];
  $$(".asm-part-g").forEach(function (g) {
    var n = (+g.dataset.part || 1) - 1;
    var off = FLY[n % FLY.length];
    g.style.setProperty("--fx-ox", off[0] + "px");
    g.style.setProperty("--fx-oy", off[1] + "px");
    g.__fxOn = g.classList.contains("on");
    new MutationObserver(function () {
      var on = g.classList.contains("on");
      if (on && !g.__fxOn) {
        g.classList.remove("fx-flash");
        requestAnimationFrame(function () { g.classList.add("fx-flash"); });
      }
      g.__fxOn = on;
    }).observe(g, { attributes: true, attributeFilter: ["class"] });
  });

  /* ================= instrument panels ================= */
  $$(".instrument-tab").forEach(function (tab) {
    tab.addEventListener("click", function () {
      requestAnimationFrame(function () {
        $$("#principles .pr").forEach(function (pr) {
          if (pr.hidden) return;
          pr.classList.remove("fx-swap");
          void pr.offsetWidth;
          pr.classList.add("fx-swap");
        });
      });
    });
  });

  /* ================= hero depth parallax ================= */
  if (finePointer && hero && title) {
    hero.addEventListener("pointermove", function (e) {
      var nx = e.clientX / innerWidth - 0.5;
      var ny = e.clientY / innerHeight - 0.5;
      title.style.setProperty("--fx-ty", (nx * 10).toFixed(2) + "deg");
      title.style.setProperty("--fx-tx", (-ny * 8).toFixed(2) + "deg");
      root.style.setProperty("--fx-px", (nx * 18).toFixed(1) + "px");
      root.style.setProperty("--fx-py", (ny * 12).toFixed(1) + "px");
    }, { passive: true });
    hero.addEventListener("pointerleave", function () {
      title.style.setProperty("--fx-ty", "0deg");
      title.style.setProperty("--fx-tx", "0deg");
      root.style.setProperty("--fx-px", "0px");
      root.style.setProperty("--fx-py", "0px");
    });
  }

  setupTrail(finePointer);
  if (!finePointer) return;

  /* ================= HUD tracks the pointer ================= */
  $$(".hud").forEach(function (hud) {
    var cells = $$("div > span", hud);
    if (cells.length < 4) return;
    var original = cells.map(function (c) { return c.textContent; });
    var visible = false, focus = 0.74, lastMove = 0, raf = 0, az = 214.6, alt = 38.2, taz = az, talt = alt;
    hud.classList.add("fx-hud");
    new IntersectionObserver(function (entries) {
      visible = entries[0].isIntersecting;
      if (visible) { if (!raf) loop(); } else cells.forEach(function (c, i) { c.textContent = original[i]; });
    }).observe(hud);
    addEventListener("pointermove", function (e) {
      if (!visible) return;
      taz = 180 + (e.clientX / innerWidth - 0.5) * 140;
      talt = 72 - (e.clientY / innerHeight) * 62;
      lastMove = performance.now();
      if (!raf) loop();
    }, { passive: true });
    function loop() {
      raf = 0;
      if (!visible) return;
      var still = performance.now() - lastMove > 260;
      az += (taz - az) * 0.12;
      alt += (talt - alt) * 0.12;
      focus += ((still ? 1 : 0.32) - focus) * (still ? 0.035 : 0.12);
      var bars = Math.round(focus * 8);
      cells[0].textContent = az.toFixed(1) + "°";
      cells[1].textContent = (alt >= 0 ? "+" : "") + alt.toFixed(1) + "°";
      cells[2].textContent = "6.0° → " + (6 - focus * 5.2).toFixed(1) + "°";
      cells[3].textContent = "▮▮▮▮▮▮▮▮".slice(0, bars) + "▯▯▯▯▯▯▯▯".slice(0, 8 - bars) + " " + focus.toFixed(2);
      hud.classList.toggle("is-locked", focus > 0.97);
      if (Math.abs(taz - az) > 0.05 || Math.abs(talt - alt) > 0.05 || !still || focus < 0.995) raf = requestAnimationFrame(loop);
    }
  });

  /* ================= dark adaptation on the naked-eye sky ================= */
  $$(".eye-visual").forEach(function (fig) {
    var layer = document.createElement("canvas");
    layer.className = "fx-adapt";
    layer.setAttribute("aria-hidden", "true");
    fig.appendChild(layer);
    var hint = document.createElement("span");
    hint.className = "fx-adapt-hint";
    hint.setAttribute("aria-hidden", "true");
    hint.innerHTML = '<span class="en">Hold still — your eyes adapt to the dark</span><span class="zh">停住鼠标，眼睛会慢慢适应黑暗</span>';
    fig.appendChild(hint);
    var painted = false, radius = 0, target = 0, raf = 0, px = 0, py = 0, inside = false, lastMove = 0;
    function paint() {
      painted = true;
      var b = fig.getBoundingClientRect();
      var d = Math.min(devicePixelRatio || 1, 1.5);
      layer.width = Math.round(b.width * d);
      layer.height = Math.round(b.height * d);
      var c = layer.getContext("2d");
      c.scale(d, d);
      var g = c.createLinearGradient(0, b.height * 0.9, b.width, b.height * 0.1);
      g.addColorStop(0, "rgba(90,110,190,0)");
      g.addColorStop(0.5, "rgba(150,165,230,.16)");
      g.addColorStop(1, "rgba(90,110,190,0)");
      c.fillStyle = g;
      c.fillRect(0, 0, b.width, b.height);
      var s = 77;
      function r() { s = (s * 16807) % 2147483647; return s / 2147483647; }
      for (var i = 0; i < 1400; i++) {
        var x = r() * b.width, y = r() * b.height * 0.84, z = r();
        c.fillStyle = "rgba(" + (z < 0.15 ? "255,220,170" : "215,228,255") + "," + (0.25 + z * 0.6).toFixed(2) + ")";
        var sz = z > 0.97 ? 2 : 1;
        c.fillRect(x, y, sz, sz);
      }
      for (var j = 0; j < 4; j++) {
        var nx = r() * b.width, ny = r() * b.height * 0.7, nr = 30 + r() * 40;
        var ng = c.createRadialGradient(nx, ny, 0, nx, ny, nr);
        ng.addColorStop(0, j % 2 ? "rgba(255,150,170,.22)" : "rgba(140,190,255,.22)");
        ng.addColorStop(1, "rgba(0,0,0,0)");
        c.fillStyle = ng;
        c.fillRect(nx - nr, ny - nr, nr * 2, nr * 2);
      }
    }
    function loop() {
      raf = 0;
      var still = performance.now() - lastMove > 180;
      target = inside ? (still ? Math.min(240, target + 2.2) : Math.max(70, target - 6)) : 0;
      radius += (target - radius) * 0.12;
      fig.style.setProperty("--fx-ar", radius.toFixed(1) + "px");
      fig.style.setProperty("--fx-ax", px.toFixed(1) + "px");
      fig.style.setProperty("--fx-ay", py.toFixed(1) + "px");
      if (inside || radius > 1) raf = requestAnimationFrame(loop);
    }
    fig.addEventListener("pointerenter", function () {
      if (!painted) paint();
      inside = true;
      target = 70;
      fig.classList.add("is-adapting");
      if (!raf) loop();
    });
    fig.addEventListener("pointermove", function (e) {
      var b = fig.getBoundingClientRect();
      px = e.clientX - b.left;
      py = e.clientY - b.top;
      lastMove = performance.now();
    });
    fig.addEventListener("pointerleave", function () {
      inside = false;
      fig.classList.remove("is-adapting");
    });
    addEventListener("resize", function () { painted = false; }, { passive: true });
  });

  /* ================= magnifier on views and diagrams ================= */
  $$(".obs-scope, .cmp-view, .fig, .dyn-stage, .pr-fig, .mechanism-figure").forEach(function (box) {
    var svg = box.querySelector("svg");
    if (!svg) return;
    var lens = null, inner = null, detail = null, zoom = box.classList.contains("obs-scope") ? 2.6 : 2.2, size = 150;
    var lx = 0, ly = 0, looking = false, lensRaf = 0;
    // Scenes rendered by fx-planets.js repaint at the lens zoom instead of being upscaled.
    function paintLens() {
      lensRaf = 0;
      if (!looking || !detail) return;
      var dpr = Math.min(devicePixelRatio || 1, 2);
      var px = Math.round(size * dpr);
      if (detail.width !== px) { detail.width = detail.height = px; }
      var ctx = detail.getContext("2d");
      ctx.clearRect(0, 0, px, px);
      var m = svg.getScreenCTM(), b = box.getBoundingClientRect();
      if (m) box.__fxPaint(ctx, m.a * zoom * dpr, ((m.e - b.left - lx) * zoom + size / 2) * dpr, ((m.f - b.top - ly) * zoom + size / 2) * dpr);
      lensRaf = requestAnimationFrame(paintLens);
    }
    box.classList.add("fx-loupe-host");
    if (getComputedStyle(box).position === "static") box.style.position = "relative";
    function build() {
      lens = document.createElement("div");
      lens.className = "fx-loupe";
      lens.setAttribute("aria-hidden", "true");
      inner = document.createElement("div");
      inner.className = "fx-loupe-inner";
      var clone = svg.cloneNode(true);
      [clone].concat($$("[id]", clone)).forEach(function (n) { n.removeAttribute("id"); });
      inner.appendChild(clone);
      lens.appendChild(inner);
      if (box.__fxPaint) {
        detail = document.createElement("canvas");
        detail.className = "fx-loupe-detail";
        lens.appendChild(detail);
      }
      lens.insertAdjacentHTML("beforeend", "<i></i>");
      box.appendChild(lens);
    }
    box.addEventListener("pointerenter", function () {
      if (!lens) build();
      var b = box.getBoundingClientRect();
      size = clamp(Math.min(b.width, b.height) * 0.42, 110, 190);
      lens.style.width = lens.style.height = size + "px";
      var sb = svg.getBoundingClientRect();
      inner.style.width = sb.width * zoom + "px";
      inner.style.height = sb.height * zoom + "px";
      inner.__ox = sb.left - b.left;
      inner.__oy = sb.top - b.top;
      box.classList.add("is-looking");
      looking = true;
      if (detail && !lensRaf) lensRaf = requestAnimationFrame(paintLens);
    });
    box.addEventListener("pointermove", function (e) {
      if (!lens) return;
      var b = box.getBoundingClientRect();
      var x = e.clientX - b.left, y = e.clientY - b.top;
      lx = x; ly = y;
      lens.style.transform = "translate3d(" + (x - size / 2).toFixed(1) + "px," + (y - size / 2).toFixed(1) + "px,0)";
      inner.style.transform = "translate3d(" + (size / 2 - (x - inner.__ox) * zoom).toFixed(1) + "px," + (size / 2 - (y - inner.__oy) * zoom).toFixed(1) + "px,0)";
    });
    box.addEventListener("pointerleave", function () { box.classList.remove("is-looking"); looking = false; });
  });

  /* ================= assembly stage follows the pointer ================= */
  $$(".asm-stage").forEach(function (stage) {
    var svg = stage.querySelector("svg");
    if (!svg) return;
    stage.addEventListener("pointermove", function (e) {
      var b = stage.getBoundingClientRect();
      var nx = (e.clientX - b.left) / b.width - 0.5, ny = (e.clientY - b.top) / b.height - 0.5;
      svg.style.transform = "perspective(900px) rotateY(" + (nx * 16).toFixed(2) + "deg) rotateX(" + (-ny * 12).toFixed(2) + "deg)";
    });
    stage.addEventListener("pointerleave", function () { svg.style.transform = ""; });
  });

  /* ================= dynamic sky parallax ================= */
  $$(".dyn-stage").forEach(function (stage) {
    var layers = $$("svg > g", stage);
    stage.addEventListener("pointermove", function (e) {
      var b = stage.getBoundingClientRect();
      var nx = (e.clientX - b.left) / b.width - 0.5, ny = (e.clientY - b.top) / b.height - 0.5;
      layers.forEach(function (g, i) {
        var depth = (i + 1) / layers.length;
        g.style.translate = (nx * -26 * depth).toFixed(1) + "px " + (ny * -16 * depth).toFixed(1) + "px";
      });
    });
    stage.addEventListener("pointerleave", function () { layers.forEach(function (g) { g.style.translate = ""; }); });
  });

  /* ================= magnetic buttons ================= */
  $$(".btn, .gnav-play").forEach(function (btn) {
    btn.addEventListener("pointermove", function (e) {
      var b = btn.getBoundingClientRect();
      btn.style.setProperty("--fx-mx", ((e.clientX - (b.left + b.width / 2)) * 0.28).toFixed(1) + "px");
      btn.style.setProperty("--fx-my", ((e.clientY - (b.top + b.height / 2)) * 0.38).toFixed(1) + "px");
    });
    btn.addEventListener("pointerleave", function () {
      btn.style.setProperty("--fx-mx", "0px");
      btn.style.setProperty("--fx-my", "0px");
    });
  });

  /* ================= tilt + spotlight ================= */
  var TILT = ".card, .glass-panel, .obs-card, .cmp-card, .pr, .mechanism-card, .feat, .tl-item, .instrument-tab, .tip-band";
  $$(TILT).forEach(function (el) {
    if (el.closest(".gnav") || el.classList.contains("fx-tilt")) return;
    el.classList.add("fx-tilt");
    if (getComputedStyle(el).position === "static") el.style.position = "relative";
    var spot = document.createElement("span");
    spot.className = "fx-spot";
    var rim = document.createElement("span");
    rim.className = "fx-rim";
    spot.setAttribute("aria-hidden", "true");
    rim.setAttribute("aria-hidden", "true");
    el.appendChild(spot);
    el.appendChild(rim);
    var frame = 0, lastEvent = null;
    var damp = el.querySelector(".fx-loupe-host") ? 0.35 : 1;
    function apply() {
      frame = 0;
      var b = el.getBoundingClientRect();
      var px = (lastEvent.clientX - b.left) / b.width;
      var py = (lastEvent.clientY - b.top) / b.height;
      var max = 9 * Math.min(1, 380 / Math.max(b.width, b.height)) * damp;
      el.style.setProperty("--fx-sx", (px * 100).toFixed(1) + "%");
      el.style.setProperty("--fx-sy", (py * 100).toFixed(1) + "%");
      el.style.setProperty("--fx-ry", ((px - 0.5) * max * 2).toFixed(2) + "deg");
      el.style.setProperty("--fx-rx", (-(py - 0.5) * max * 2).toFixed(2) + "deg");
    }
    el.addEventListener("pointerenter", function () { el.classList.add("fx-hover"); });
    el.addEventListener("pointermove", function (e) {
      lastEvent = e;
      if (!frame) frame = requestAnimationFrame(apply);
    });
    el.addEventListener("pointerleave", function () {
      el.classList.remove("fx-hover");
      el.style.setProperty("--fx-rx", "0deg");
      el.style.setProperty("--fx-ry", "0deg");
    });
  });

  /* ================= reticle cursor that snaps around controls ================= */
  root.classList.add("fx-cursor");
  var reticle = document.createElement("div");
  reticle.className = "fx-reticle is-hidden";
  reticle.innerHTML = '<i class="ring"></i><b class="ticks"></b><s class="k1"></s><s class="k2"></s><s class="k3"></s><s class="k4"></s>';
  var dot = document.createElement("div");
  dot.className = "fx-dot is-hidden";
  [reticle, dot].forEach(function (el) {
    el.setAttribute("aria-hidden", "true");
    document.body.appendChild(el);
  });
  var SNAP = "a, button, summary, label, [role='button'], .chip, .instrument-tab";
  var TEXTUAL = "input:not([type='range']):not([type='checkbox']):not([type='radio']), textarea, select, [contenteditable='true']";
  var cur = { x: innerWidth / 2, y: innerHeight / 2, w: 38, h: 38, r: 19 };
  var pointer = { x: cur.x, y: cur.y, seen: false };
  var snapEl = null, snapRadius = 19, cursorRaf = 0;
  function cursorLoop() {
    cursorRaf = 0;
    var tx = pointer.x, ty = pointer.y, tw = 38, th = 38, tr = 19;
    if (snapEl && snapEl.isConnected) {
      var b = snapEl.getBoundingClientRect();
      var cx = b.left + b.width / 2, cy = b.top + b.height / 2;
      tx = cx + (pointer.x - cx) * 0.12;
      ty = cy + (pointer.y - cy) * 0.12;
      tw = b.width + 14;
      th = b.height + 12;
      tr = Math.min(th / 2, snapRadius + 6);
    }
    cur.x += (tx - cur.x) * 0.24;
    cur.y += (ty - cur.y) * 0.24;
    cur.w += (tw - cur.w) * 0.22;
    cur.h += (th - cur.h) * 0.22;
    cur.r += (tr - cur.r) * 0.22;
    reticle.style.transform = "translate3d(" + (cur.x - cur.w / 2).toFixed(1) + "px," + (cur.y - cur.h / 2).toFixed(1) + "px,0)";
    reticle.style.width = cur.w.toFixed(1) + "px";
    reticle.style.height = cur.h.toFixed(1) + "px";
    reticle.style.borderRadius = cur.r.toFixed(1) + "px";
    var moving = Math.abs(tx - cur.x) + Math.abs(ty - cur.y) + Math.abs(tw - cur.w) + Math.abs(th - cur.h) > 0.3;
    if (moving) cursorRaf = requestAnimationFrame(cursorLoop);
  }
  function kick() { if (!cursorRaf) cursorRaf = requestAnimationFrame(cursorLoop); }
  addEventListener("pointermove", function (e) {
    if (e.pointerType !== "mouse") return;
    pointer.x = e.clientX;
    pointer.y = e.clientY;
    dot.style.transform = "translate3d(" + e.clientX + "px," + e.clientY + "px,0)";
    var target = e.target instanceof Element ? e.target : null;
    var textual = !!(target && target.closest(TEXTUAL));
    var snap = target && !textual ? target.closest(SNAP) : null;
    if (snap && snap.getBoundingClientRect().width > 420) snap = null;
    if (snap !== snapEl) {
      snapEl = snap;
      if (snap) snapRadius = parseFloat(getComputedStyle(snap).borderTopLeftRadius) || 6;
      reticle.classList.toggle("is-snap", !!snap);
    }
    reticle.classList.toggle("is-hidden", textual);
    dot.classList.toggle("is-hidden", textual);
    reticle.classList.toggle("is-loupe", !!(target && target.closest(".fx-loupe-host")));
    if (!pointer.seen) { pointer.seen = true; cur.x = pointer.x; cur.y = pointer.y; }
    kick();
  }, { passive: true });
  addEventListener("scroll", function () { if (snapEl) kick(); }, { passive: true });
  document.addEventListener("pointerleave", function () {
    reticle.classList.add("is-hidden");
    dot.classList.add("is-hidden");
  });
  addEventListener("pointerdown", function () { reticle.classList.add("is-down"); });
  addEventListener("pointerup", function () { reticle.classList.remove("is-down"); });

  /* ================= comet trail + starburst ================= */
  function setupTrail(withTrail) {
    var cv = document.createElement("canvas");
    cv.className = "fx-trail";
    cv.setAttribute("aria-hidden", "true");
    document.body.appendChild(cv);
    var ctx = cv.getContext("2d");
    var dprT = Math.min(devicePixelRatio || 1, 1.25);
    function size() {
      cv.width = Math.round(innerWidth * dprT);
      cv.height = Math.round(innerHeight * dprT);
      ctx.setTransform(dprT, 0, 0, dprT, 0, 0);
    }
    size();
    addEventListener("resize", size, { passive: true });

    function sprite(rgb) {
      var s = document.createElement("canvas");
      s.width = s.height = 48;
      var c = s.getContext("2d");
      var g = c.createRadialGradient(24, 24, 0, 24, 24, 24);
      g.addColorStop(0, "rgba(255,255,255,1)");
      g.addColorStop(0.18, "rgba(" + rgb + ",.9)");
      g.addColorStop(0.5, "rgba(" + rgb + ",.22)");
      g.addColorStop(1, "rgba(" + rgb + ",0)");
      c.fillStyle = g;
      c.fillRect(0, 0, 48, 48);
      return s;
    }
    var SPRITES = [sprite("233,190,110"), sprite("130,170,255"), sprite("255,236,200"), sprite("255,120,150")];
    var parts = [], path = [], raf = 0, last = null, MAX = 360, dirty = null;

    function emit(x, y, n, speed, life, spread) {
      for (var i = 0; i < n && parts.length < MAX; i++) {
        var a = Math.random() * Math.PI * 2;
        var v = speed * (0.25 + Math.random() * 0.75);
        parts.push({
          x: x + (Math.random() - 0.5) * spread, y: y + (Math.random() - 0.5) * spread,
          vx: Math.cos(a) * v, vy: Math.sin(a) * v,
          life: 1, decay: 1 / (life * (0.6 + Math.random() * 0.6) * 60),
          size: 3 + Math.random() * 9, s: SPRITES[Math.random() < 0.08 ? 3 : (Math.random() * 3) | 0],
        });
      }
      wake();
    }
    function wake() { if (!raf) raf = requestAnimationFrame(loop); }

    function loop() {
      raf = 0;
      // Clear only what was painted last frame instead of the whole viewport.
      if (dirty) ctx.clearRect(dirty[0] - 30, dirty[1] - 30, dirty[2] - dirty[0] + 60, dirty[3] - dirty[1] + 60);
      var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
      function grow(x, y, r) {
        if (x - r < minX) minX = x - r;
        if (y - r < minY) minY = y - r;
        if (x + r > maxX) maxX = x + r;
        if (y + r > maxY) maxY = y + r;
      }
      ctx.globalCompositeOperation = "lighter";
      if (path.length > 1) {
        ctx.lineCap = "round";
        for (var i = 1; i < path.length; i++) {
          var p0 = path[i - 1], p1 = path[i], k = i / path.length;
          ctx.strokeStyle = "rgba(255," + Math.round(196 + 44 * k) + "," + Math.round(120 + 90 * k) + "," + (k * k * 0.6).toFixed(3) + ")";
          ctx.lineWidth = k * 3.2;
          ctx.beginPath();
          ctx.moveTo(p0.x, p0.y);
          ctx.lineTo(p1.x, p1.y);
          ctx.stroke();
          grow(p0.x, p0.y, 4);
          grow(p1.x, p1.y, 4);
        }
        for (var a = 0; a < path.length; a++) path[a].age++;
        while (path.length && path[0].age > 14) path.shift();
      }
      for (var j = parts.length - 1; j >= 0; j--) {
        var q = parts[j];
        q.x += q.vx; q.y += q.vy;
        q.vx *= 0.955; q.vy = q.vy * 0.955 + 0.012;
        q.life -= q.decay;
        if (q.life <= 0) { parts.splice(j, 1); continue; }
        var s = q.size * (0.35 + q.life * 0.65);
        ctx.globalAlpha = Math.min(1, q.life * 1.4);
        ctx.drawImage(q.s, q.x - s, q.y - s, s * 2, s * 2);
        grow(q.x, q.y, s);
      }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      var painted = maxX > minX;
      var keep = painted || dirty;
      dirty = painted ? [minX, minY, maxX, maxY] : null;
      if (keep) raf = requestAnimationFrame(loop);
    }

    if (withTrail) {
      addEventListener("pointermove", function (e) {
        if (e.pointerType !== "mouse") return;
        var x = e.clientX, y = e.clientY;
        if (last) {
          var dx = x - last.x, dy = y - last.y;
          var dist = Math.sqrt(dx * dx + dy * dy);
          var n = Math.min(5, Math.floor(dist / 10));
          for (var i = 0; i < n; i++) {
            var t = i / n;
            emit(last.x + dx * t, last.y + dy * t, 1, 0.5 + dist * 0.01, 0.75, 4);
          }
        }
        path.push({ x: x, y: y, age: 0 });
        if (path.length > 22) path.shift();
        last = { x: x, y: y };
        wake();
      }, { passive: true });
    }

    addEventListener("pointerdown", function (e) {
      emit(e.clientX, e.clientY, 46, 7.5, 1.0, 2);
      emit(e.clientX, e.clientY, 14, 2, 1.4, 10);
      var ring = document.createElement("div");
      ring.className = "fx-ring";
      ring.style.setProperty("--x", e.clientX + "px");
      ring.style.setProperty("--y", e.clientY + "px");
      document.body.appendChild(ring);
      setTimeout(function () { ring.remove(); }, 800);
    }, { passive: true });
  }
})();
