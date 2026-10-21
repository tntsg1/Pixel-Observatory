/* Landing-page effects: WebGL galaxy + nebula in the hero and finale, aperture
   intro, decoding titles, telescope-reticle cursor with a comet trail, magnetic
   buttons, tilting spotlight cards and a scroll beam. Everything degrades to the
   original page when WebGL, a fine pointer or motion are unavailable. */
(function () {
  "use strict";
  var root = document.documentElement;
  /* Windows "Animation effects: off" also reports reduced motion, which would
     hide the whole layer for many desktop visitors. Keep the ambient galaxy and
     pointer feedback, but drop the intro flash and the text scrambling. */
  var calm = matchMedia("(prefers-reduced-motion: reduce)").matches && !/[?&]fx=full(&|$)/.test(location.search);
  root.classList.add("fx-on");
  if (calm) root.classList.add("fx-calm");

  var finePointer = matchMedia("(hover: hover) and (pointer: fine)").matches;
  var smallScreen = Math.min(screen.width, screen.height) < 700;
  var lowPower = smallScreen || (navigator.hardwareConcurrency || 8) <= 4;
  var mouse = { x: innerWidth / 2, y: innerHeight / 2, seen: false };

  function rand(seed) {
    return function () {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    };
  }
  function gauss(r) {
    return (r() + r() + r() + r() - 2) * 0.5;
  }

  /* ================= WebGL galaxy ================= */
  var NEBULA_VS = "attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}";
  var NEBULA_FS = [
    "precision highp float;",
    "uniform vec2 uRes;uniform float uTime;uniform vec2 uMouse;uniform float uHover;uniform float uIntro;",
    "uniform vec3 uShock;uniform vec3 uTintA;uniform vec3 uTintB;",
    "float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}",
    "float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);",
    " return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}",
    "float fbm(vec2 p){float v=0.,a=.5;mat2 m=mat2(1.6,1.2,-1.2,1.6);",
    " for(int i=0;i<5;i++){v+=a*n(p);p=m*p;a*=.5;}return v;}",
    "void main(){",
    " vec2 uv=gl_FragCoord.xy/uRes;float asp=uRes.x/uRes.y;",
    " vec2 p=uv*2.-1.;p.x*=asp;vec2 m=uMouse;m.x*=asp;",
    " vec2 dm=p-m;float r=length(dm);",
    " p-=dm/(r*r+.035)*.018*uHover;",
    " vec2 sd=p-vec2(uShock.x*asp,uShock.y);float sr=length(sd);",
    " float sw=exp(-pow((sr-uShock.z*1.9)*7.,2.))*(1.-uShock.z);",
    " p+=normalize(sd+1e-4)*sw*.06;",
    " float t=uTime*.018;",
    " vec2 q=vec2(fbm(p*1.25+t),fbm(p*1.25+vec2(5.2,1.3)-t));",
    " vec2 w=vec2(fbm(p*1.5+q*2.1+vec2(1.7,9.2)+t*1.4),fbm(p*1.5+q*2.1+vec2(8.3,2.8)-t));",
    " float f=fbm(p*1.7+w*2.3);",
    " float band=exp(-pow((p.y+p.x*.38-.05)*1.25,2.));",
    " vec3 c=mix(vec3(.012,.018,.05),uTintA*.42,smoothstep(.25,.85,f));",
    " c=mix(c,uTintB*.55,smoothstep(.5,1.15,length(w))*.75);",
    " c+=vec3(1.,.78,.45)*pow(max(f-.48,0.),2.2)*2.6;",
    " c*=.28+1.05*band;",
    " float glow=uHover*(.028/(r+.07));",
    " c+=vec3(1.,.8,.5)*glow;",
    " c+=vec3(1.,.88,.66)*exp(-pow((r-.085)*55.,2.))*.35*uHover;",
    " c+=vec3(1.,.85,.6)*sw*.35;",
    " float vig=smoothstep(1.65,.35,length((uv-.5)*vec2(asp,1.)*1.2));",
    " gl_FragColor=vec4(c*vig*uIntro,1.);",
    "}",
  ].join("\n");
  var BLIT_FS = "precision mediump float;uniform sampler2D uTex;uniform vec2 uRes;void main(){gl_FragColor=texture2D(uTex,gl_FragCoord.xy/uRes);}";
  var STAR_VS = [
    "attribute vec4 aData;attribute vec3 aColor;",
    "uniform float uTime,uIntro,uAspect,uScroll,uPixel,uHover,uSpin,uFit;",
    "uniform vec2 uMouse,uTilt,uCenter;uniform vec3 uShock;",
    "varying vec3 vColor;varying float vAlpha;",
    "void main(){",
    " float r=aData.x,seed=aData.w;",
    " float e=uIntro;",
    " float rr=r*mix(.015,1.,e);",
    " float ang=aData.y+uTime*uSpin/(.22+r)+(1.-e)*(1.-e)*9./(.3+r);",
    " vec3 p=vec3(cos(ang)*rr,aData.z*(.3+.7*e),sin(ang)*rr);",
    " float ax=.98+uTilt.y*.22-uScroll*.55;float cx=cos(ax),sx=sin(ax);",
    " p=vec3(p.x,p.y*cx-p.z*sx,p.y*sx+p.z*cx);",
    " float ay=uTilt.x*.38-.35;float cy=cos(ay),sy=sin(ay);",
    " p=vec3(p.x*cy+p.z*sy,p.y,-p.x*sy+p.z*cy);",
    " float ar=-.32;p.xy=mat2(cos(ar),sin(ar),-sin(ar),cos(ar))*p.xy;",
    " float z=2.35-uScroll*.9+p.z;",
    " vec2 sp=p.xy/z*1.75*uFit;sp.x/=uAspect;sp+=uCenter;",
    " vec2 d=sp-uMouse;d.x*=uAspect;float dist=length(d);",
    " float f=exp(-dist*dist*22.)*uHover;",
    " vec2 disp=(vec2(-d.y,d.x)*.75-d*.42)*f*.3;disp.x/=uAspect;",
    " vec2 sd=sp-uShock.xy;sd.x*=uAspect;float sr=length(sd);",
    " float ring=exp(-pow((sr-uShock.z*1.9)*8.,2.))*(1.-uShock.z);",
    " vec2 sdisp=normalize(sd+1e-5)*ring*.09;sdisp.x/=uAspect;",
    " gl_Position=vec4(sp+disp+sdisp,0.,1.);",
    " float s=(.9+seed*seed*seed*4.2)*uPixel/z;",
    " gl_PointSize=s*(1.+f*1.6+ring*2.2);",
    " float tw=.62+.38*sin(uTime*(.8+seed*2.6)+seed*61.);",
    " vColor=aColor*(1.+f*2.2+ring*2.5);",
    " vAlpha=tw*smoothstep(0.,.2,e)*clamp(2./z,0.,1.2);",
    "}",
  ].join("\n");
  var STAR_FS = [
    "precision mediump float;varying vec3 vColor;varying float vAlpha;",
    "void main(){vec2 c=gl_PointCoord-.5;float d=length(c);",
    " float a=smoothstep(.5,0.,d);a=a*a*a+smoothstep(.12,0.,d)*.6;",
    " gl_FragColor=vec4(vColor*a*vAlpha,1.);}",
  ].join("\n");

  function compile(gl, vs, fs) {
    function sh(type, src) {
      var s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      return s;
    }
    var prog = gl.createProgram();
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, vs));
    gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, fs));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
    var u = {};
    var count = gl.getProgramParameter(prog, gl.ACTIVE_UNIFORMS);
    for (var i = 0; i < count; i++) {
      var name = gl.getActiveUniform(prog, i).name;
      u[name] = gl.getUniformLocation(prog, name);
    }
    return { prog: prog, u: u };
  }

  function Galaxy(host, opts) {
    var canvas = document.createElement("canvas");
    canvas.className = "fx-gl";
    canvas.setAttribute("aria-hidden", "true");
    var gl = canvas.getContext("webgl", { alpha: false, antialias: false, premultipliedAlpha: false, powerPreference: "high-performance" });
    if (!gl) return null;
    var info = gl.getExtension("WEBGL_debug_renderer_info");
    var renderer = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : "";
    if (/swiftshader|llvmpipe|software|basic render/i.test(renderer) && !/[?&]fx=full(&|$)/.test(location.search)) return null;
    host.insertBefore(canvas, host.firstChild);

    var nebula, blit, stars;
    try {
      nebula = compile(gl, NEBULA_VS, NEBULA_FS);
      blit = compile(gl, NEBULA_VS, BLIT_FS);
      stars = compile(gl, STAR_VS, STAR_FS);
    } catch (err) {
      canvas.remove();
      return null;
    }

    var quad = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, quad);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);

    var count = opts.count;
    var data = new Float32Array(count * 4);
    var color = new Float32Array(count * 3);
    var r = rand(opts.seed);
    var arms = opts.arms;
    for (var i = 0; i < count; i++) {
      var kind = r();
      var core = kind < 0.2;
      var disk = !core && kind < 0.45;
      var radius = core ? Math.abs(gauss(r)) * 0.32 : Math.pow(r(), disk ? 0.7 : 0.9) * opts.radius + 0.06;
      var arm = Math.floor(r() * arms);
      var spread = gauss(r) * (0.9 / (radius * 1.6 + 0.7));
      var angle = core || disk ? r() * Math.PI * 2 : (arm / arms) * Math.PI * 2 + radius * opts.wind + spread;
      if (!core) radius = Math.max(0.04, radius + gauss(r) * 0.07);
      var height = gauss(r) * (core ? 0.09 : 0.035 * (1.4 - radius / opts.radius));
      data.set([radius, angle, height, r()], i * 4);
      var k = Math.min(1, radius / opts.radius);
      var c;
      var pick = r();
      if (core || k < 0.12) c = [1.0, 0.82, 0.55];
      else if (pick < 0.06) c = [1.0, 0.42, 0.55];
      else if (pick < 0.22) c = [1.0, 0.78, 0.48];
      else c = [0.45 + 0.25 * (1 - k), 0.6 + 0.2 * (1 - k), 1.0];
      var b = (core ? 0.34 : disk ? 0.16 : 0.36) * opts.brightness * (0.6 + r() * 0.6);
      color.set([c[0] * b, c[1] * b, c[2] * b], i * 3);
    }
    var dataBuf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, dataBuf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
    var colorBuf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, colorBuf);
    gl.bufferData(gl.ARRAY_BUFFER, color, gl.STATIC_DRAW);
    var aData = gl.getAttribLocation(stars.prog, "aData");
    var aColor = gl.getAttribLocation(stars.prog, "aColor");

    var fbo = gl.createFramebuffer();
    var tex = gl.createTexture();
    var W = 0, H = 0, NW = 0, NH = 0, dpr = 1, quality = 1, drawCount = count;
    function resize() {
      var rect = host.getBoundingClientRect();
      dpr = Math.min(devicePixelRatio || 1, lowPower ? 1 : 1.5);
      W = Math.max(2, Math.round(rect.width * dpr));
      H = Math.max(2, Math.round(rect.height * dpr));
      canvas.width = W;
      canvas.height = H;
      var scale = (lowPower ? 0.35 : 0.5) * quality;
      NW = Math.max(2, Math.round(W * scale));
      NH = Math.max(2, Math.round(H * scale));
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, NW, NH, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    }
    resize();
    addEventListener("resize", resize, { passive: true });

    var state = {
      mx: 0, my: 0, tmx: 0, tmy: 0, hover: 0, thover: 0,
      tiltX: 0, tiltY: 0, shock: [0, 0, 1], introStart: 0, visible: false, raf: 0,
    };
    var start = performance.now();
    var slowFrames = 0, sampled = 0, lastNow = 0;

    function local(clientX, clientY) {
      var rect = canvas.getBoundingClientRect();
      return {
        x: ((clientX - rect.left) / rect.width) * 2 - 1,
        y: 1 - ((clientY - rect.top) / rect.height) * 2,
        inside: clientX >= rect.left && clientX <= rect.right && clientY >= rect.top && clientY <= rect.bottom,
      };
    }
    addEventListener("pointermove", function (e) {
      var l = local(e.clientX, e.clientY);
      state.tmx = l.x;
      state.tmy = l.y;
      state.thover = l.inside ? 1 : 0;
    }, { passive: true });
    document.addEventListener("pointerleave", function () { state.thover = 0; });
    host.addEventListener("pointerdown", function (e) {
      var l = local(e.clientX, e.clientY);
      state.shock = [l.x, l.y, 0];
    });

    function uniforms(prog, t) {
      var u = prog.u;
      if (u.uRes) gl.uniform2f(u.uRes, prog === nebula ? NW : W, prog === nebula ? NH : H);
      if (u.uTime) gl.uniform1f(u.uTime, t);
      if (u.uMouse) gl.uniform2f(u.uMouse, state.mx, state.my);
      if (u.uHover) gl.uniform1f(u.uHover, state.hover);
      if (u.uShock) gl.uniform3f(u.uShock, state.shock[0], state.shock[1], state.shock[2]);
    }

    function frame(now) {
      state.raf = 0;
      if (!state.visible || document.hidden) return;
      var t = (now - start) / 1000;
      if (lastNow && quality > 0.5 && sampled < 240) {
        sampled++;
        if (now - lastNow > 34) slowFrames++;
        if (sampled > 60 && slowFrames / sampled > 0.5) {
          quality = 0.5;
          drawCount = Math.floor(count * 0.5);
          resize();
        }
      }
      lastNow = now;
      var intro = Math.min(1, Math.max(0, (t - opts.delay) / opts.introTime));
      var eased = 1 - Math.pow(1 - intro, 4);
      state.mx += (state.tmx - state.mx) * 0.12;
      state.my += (state.tmy - state.my) * 0.12;
      state.hover += (state.thover - state.hover) * 0.06;
      state.tiltX += (state.tmx * state.hover - state.tiltX) * 0.04;
      state.tiltY += (state.tmy * state.hover - state.tiltY) * 0.04;
      if (state.shock[2] < 1) state.shock[2] = Math.min(1, state.shock[2] + 0.014);
      var rect = host.getBoundingClientRect();
      var scroll = Math.max(0, Math.min(1, -rect.top / Math.max(1, rect.height)));

      gl.disable(gl.BLEND);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.viewport(0, 0, NW, NH);
      gl.useProgram(nebula.prog);
      uniforms(nebula, t);
      gl.uniform1f(nebula.u.uIntro, Math.min(1, eased * 1.15));
      gl.uniform3fv(nebula.u.uTintA, opts.tintA);
      gl.uniform3fv(nebula.u.uTintB, opts.tintB);
      gl.bindBuffer(gl.ARRAY_BUFFER, quad);
      gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
      gl.drawArrays(gl.TRIANGLES, 0, 3);

      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.viewport(0, 0, W, H);
      gl.useProgram(blit.prog);
      gl.uniform2f(blit.u.uRes, W, H);
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      gl.disableVertexAttribArray(0);

      gl.enable(gl.BLEND);
      gl.blendFunc(gl.ONE, gl.ONE);
      gl.useProgram(stars.prog);
      uniforms(stars, t);
      gl.uniform1f(stars.u.uIntro, eased);
      gl.uniform1f(stars.u.uAspect, W / H);
      gl.uniform1f(stars.u.uScroll, scroll);
      gl.uniform1f(stars.u.uPixel, dpr * opts.pointScale * Math.min(1.4, Math.max(0.7, H / dpr / 820)));
      gl.uniform1f(stars.u.uSpin, opts.spin);
      gl.uniform1f(stars.u.uFit, Math.min(1, Math.max(0.55, (W / H) / 1.1)));
      gl.uniform2f(stars.u.uTilt, state.tiltX, state.tiltY);
      gl.uniform2fv(stars.u.uCenter, opts.center);
      gl.bindBuffer(gl.ARRAY_BUFFER, dataBuf);
      gl.enableVertexAttribArray(aData);
      gl.vertexAttribPointer(aData, 4, gl.FLOAT, false, 0, 0);
      gl.bindBuffer(gl.ARRAY_BUFFER, colorBuf);
      gl.enableVertexAttribArray(aColor);
      gl.vertexAttribPointer(aColor, 3, gl.FLOAT, false, 0, 0);
      gl.drawArrays(gl.POINTS, 0, drawCount);
      gl.disableVertexAttribArray(aData);
      gl.disableVertexAttribArray(aColor);

      if (!canvas.classList.contains("is-live")) canvas.classList.add("is-live");
      state.raf = requestAnimationFrame(frame);
    }
    function wake() {
      lastNow = 0;
      if (!state.raf && state.visible && !document.hidden) state.raf = requestAnimationFrame(frame);
    }
    new IntersectionObserver(function (entries) {
      state.visible = entries[0].isIntersecting;
      if (state.visible && opts.restartIntro && !state.played) {
        state.played = true;
        start = performance.now();
      }
      wake();
    }).observe(host);
    document.addEventListener("visibilitychange", wake);
    canvas.addEventListener("webglcontextlost", function (e) { e.preventDefault(); canvas.remove(); });
    return canvas;
  }

  var hero = document.querySelector(".hero");
  var finale = document.querySelector(".finale");
  var firstVisit = scrollY < 40 && !calm;
  try {
    if (sessionStorage.getItem("fx-intro-seen")) firstVisit = false;
    sessionStorage.setItem("fx-intro-seen", "1");
  } catch (e) {}

  if (hero) {
    Galaxy(hero, {
      count: lowPower ? 12000 : 34000, seed: 1337, arms: 3, radius: 1.35, wind: 3.6,
      brightness: 2.1, pointScale: 3.2, spin: 0.035, delay: firstVisit ? 0.55 : 0, introTime: firstVisit ? 2.6 : 1.4,
      center: [0, 0.04], tintA: [0.32, 0.45, 1.0], tintB: [1.0, 0.62, 0.28],
    });
  }
  if (finale) {
    Galaxy(finale, {
      count: lowPower ? 8000 : 22000, seed: 4242, arms: 2, radius: 1.25, wind: 4.4,
      brightness: 2.2, pointScale: 3.0, spin: 0.06, delay: 0, introTime: 2.2, restartIntro: true,
      center: [0, -0.06], tintA: [0.55, 0.32, 0.95], tintB: [1.0, 0.7, 0.32],
    });
  }

  /* ================= aperture intro ================= */
  if (firstVisit && hero) {
    var iris = document.createElement("div");
    iris.className = "fx-iris";
    iris.setAttribute("aria-hidden", "true");
    document.body.appendChild(iris);
    iris.addEventListener("animationend", function (e) { if (e.target === iris && e.animationName === "fxIris") iris.remove(); });
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

  var headObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;
      headObserver.unobserve(entry.target);
      if (entry.target.tagName === "H2") entry.target.classList.add("fx-sweep");
      else decode(entry.target, 900);
    });
  }, { threshold: 0.6 });
  document.querySelectorAll("main .eyebrow, main h2, .finale h2").forEach(function (el) { headObserver.observe(el); });

  /* ================= count-up numbers ================= */
  var countObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;
      countObserver.unobserve(entry.target);
      var el = entry.target;
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
    });
  }, { threshold: 0.8 });
  document.querySelectorAll(".project-number b, .eye-stat b, .spec b").forEach(function (el) { countObserver.observe(el); });

  /* ================= scroll beam ================= */
  var beam = document.createElement("div");
  beam.className = "fx-beam";
  beam.setAttribute("aria-hidden", "true");
  document.body.appendChild(beam);
  var beamTicking = false;
  function updateBeam() {
    var max = document.documentElement.scrollHeight - innerHeight;
    beam.style.transform = "scaleX(" + (max > 0 ? Math.min(1, scrollY / max) : 0) + ")";
    beamTicking = false;
  }
  addEventListener("scroll", function () {
    if (!beamTicking) { beamTicking = true; requestAnimationFrame(updateBeam); }
  }, { passive: true });
  updateBeam();

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

  if (!finePointer) {
    /* Touch: keep the tap burst, skip cursor and hover effects. */
    setupTrail(false);
    return;
  }

  /* ================= magnetic buttons ================= */
  document.querySelectorAll(".btn, .gnav-play").forEach(function (btn) {
    btn.addEventListener("pointermove", function (e) {
      var b = btn.getBoundingClientRect();
      var dx = e.clientX - (b.left + b.width / 2);
      var dy = e.clientY - (b.top + b.height / 2);
      btn.style.setProperty("--fx-mx", (dx * 0.28).toFixed(1) + "px");
      btn.style.setProperty("--fx-my", (dy * 0.38).toFixed(1) + "px");
    });
    btn.addEventListener("pointerleave", function () {
      btn.style.setProperty("--fx-mx", "0px");
      btn.style.setProperty("--fx-my", "0px");
    });
  });

  /* ================= tilt + spotlight ================= */
  var TILT = ".card, .glass-panel, .obs-card, .cmp-card, .pr, .mechanism-card, .feat, .tl-item, .instrument-tab, .tip-band";
  document.querySelectorAll(TILT).forEach(function (el) {
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
    function apply() {
      frame = 0;
      var b = el.getBoundingClientRect();
      var px = (lastEvent.clientX - b.left) / b.width;
      var py = (lastEvent.clientY - b.top) / b.height;
      var max = 9 * Math.min(1, 380 / Math.max(b.width, b.height));
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

  /* ================= reticle cursor ================= */
  root.classList.add("fx-cursor");
  var reticle = document.createElement("div");
  reticle.className = "fx-reticle is-hidden";
  reticle.innerHTML = "<i></i><b></b>";
  var dot = document.createElement("div");
  dot.className = "fx-dot is-hidden";
  [reticle, dot].forEach(function (el) {
    el.setAttribute("aria-hidden", "true");
    document.body.appendChild(el);
  });
  var rx = mouse.x, ry = mouse.y, cursorRaf = 0;
  var TARGETS = "a, button, summary, label, [role='button'], input[type='range'], .card, .chip, .instrument-tab, .journey-slide";
  var TEXTUAL = "input:not([type='range']):not([type='checkbox']):not([type='radio']), textarea, select, [contenteditable='true']";
  function cursorLoop() {
    rx += (mouse.x - rx) * 0.2;
    ry += (mouse.y - ry) * 0.2;
    reticle.style.transform = "translate3d(" + rx.toFixed(1) + "px," + ry.toFixed(1) + "px,0)";
    if (Math.abs(mouse.x - rx) > 0.1 || Math.abs(mouse.y - ry) > 0.1) cursorRaf = requestAnimationFrame(cursorLoop);
    else cursorRaf = 0;
  }
  addEventListener("pointermove", function (e) {
    if (e.pointerType !== "mouse") return;
    mouse.x = e.clientX;
    mouse.y = e.clientY;
    dot.style.transform = "translate3d(" + e.clientX + "px," + e.clientY + "px,0)";
    var target = e.target instanceof Element ? e.target : null;
    var textual = target && target.closest(TEXTUAL);
    reticle.classList.toggle("is-hidden", !!textual);
    dot.classList.toggle("is-hidden", !!textual);
    reticle.classList.toggle("is-target", !!(target && target.closest(TARGETS)));
    if (!mouse.seen) { mouse.seen = true; rx = mouse.x; ry = mouse.y; }
    if (!cursorRaf) cursorRaf = requestAnimationFrame(cursorLoop);
  }, { passive: true });
  document.addEventListener("pointerleave", function () {
    reticle.classList.add("is-hidden");
    dot.classList.add("is-hidden");
  });
  addEventListener("pointerdown", function () { reticle.classList.add("is-down"); });
  addEventListener("pointerup", function () { reticle.classList.remove("is-down"); });

  setupTrail(true);

  /* ================= comet trail + starburst ================= */
  function setupTrail(withTrail) {
    var cv = document.createElement("canvas");
    cv.className = "fx-trail";
    cv.setAttribute("aria-hidden", "true");
    document.body.appendChild(cv);
    var ctx = cv.getContext("2d");
    var dprT = Math.min(devicePixelRatio || 1, 1.5);
    function size() {
      cv.width = Math.round(innerWidth * dprT);
      cv.height = Math.round(innerHeight * dprT);
      ctx.setTransform(dprT, 0, 0, dprT, 0, 0);
    }
    size();
    addEventListener("resize", size, { passive: true });

    function sprite(rgb) {
      var s = document.createElement("canvas");
      s.width = s.height = 64;
      var c = s.getContext("2d");
      var g = c.createRadialGradient(32, 32, 0, 32, 32, 32);
      g.addColorStop(0, "rgba(255,255,255,1)");
      g.addColorStop(0.18, "rgba(" + rgb + ",.9)");
      g.addColorStop(0.5, "rgba(" + rgb + ",.22)");
      g.addColorStop(1, "rgba(" + rgb + ",0)");
      c.fillStyle = g;
      c.fillRect(0, 0, 64, 64);
      return s;
    }
    var SPRITES = [sprite("233,190,110"), sprite("130,170,255"), sprite("255,236,200"), sprite("255,120,150")];
    var parts = [];
    var path = [];
    var raf = 0, last = null;
    var MAX = 420;

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
      ctx.clearRect(0, 0, innerWidth, innerHeight);
      ctx.globalCompositeOperation = "lighter";
      if (path.length > 1) {
        for (var i = 1; i < path.length; i++) {
          var p0 = path[i - 1], p1 = path[i];
          var k = i / path.length;
          ctx.strokeStyle = "rgba(255," + Math.round(196 + 44 * k) + "," + Math.round(120 + 90 * k) + "," + (k * k * 0.6).toFixed(3) + ")";
          ctx.lineWidth = k * 3.2;
          ctx.lineCap = "round";
          ctx.beginPath();
          ctx.moveTo(p0.x, p0.y);
          ctx.lineTo(p1.x, p1.y);
          ctx.stroke();
        }
        path.forEach(function (p) { p.age++; });
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
      }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      if (parts.length || path.length > 1) raf = requestAnimationFrame(loop);
    }

    if (withTrail) {
      addEventListener("pointermove", function (e) {
        if (e.pointerType !== "mouse") return;
        var x = e.clientX, y = e.clientY;
        if (last) {
          var dx = x - last.x, dy = y - last.y;
          var dist = Math.sqrt(dx * dx + dy * dy);
          var n = Math.min(6, Math.floor(dist / 9));
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
