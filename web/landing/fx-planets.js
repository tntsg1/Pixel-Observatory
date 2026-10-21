/* Eyepiece detail: the observing views and the chromatic-aberration pair show
   their simple SVG art at rest; when the pointer rests on a view it "comes into
   focus" and a live WebGL rendering takes over — a rotating Jupiter with
   turbulent belts, the Great Red Spot and limb darkening, resolved moons, the
   faint stars a dark-adapted eye picks up, and a cratered Moon whose refractor
   copy splits into red and blue fringes. The magnifier in fx.js repaints the same
   scene at its own zoom through host.__fxPaint, so detail stays sharp inside it. */
(function () {
  "use strict";
  var views = [].slice.call(document.querySelectorAll(".obs-scope"));
  var cmps = [].slice.call(document.querySelectorAll(".cmp-view"));
  if (!views.length && !cmps.length) return;

  /* ---------- one offscreen WebGL renderer for planet / moon discs ---------- */
  var SIZE = 512, MARGIN = 1.12;
  var glc = document.createElement("canvas");
  glc.width = glc.height = SIZE;
  var gl = glc.getContext("webgl", { alpha: true, premultipliedAlpha: true, preserveDrawingBuffer: true, antialias: false });
  if (!gl) return;
  var FS = [
    "precision highp float;",
    "uniform vec2 u_res;uniform float u_rot,u_sharp,u_kind,u_chroma,u_t,u_margin;",
    "float h3(vec3 p){p=fract(p*vec3(.1031,.1030,.0973));p+=dot(p,p.yxz+33.33);return fract((p.x+p.y)*p.z);}",
    "float n3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);",
    " return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),",
    "  mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z);}",
    "float fbm(vec3 p){float v=0.,a=.5;for(int i=0;i<6;i++){float w=i<2?1.:u_sharp;v+=a*w*n3(p);p=p*2.03+vec3(1.7,9.2,3.1);a*=.5;}return v;}",
    "vec3 sph(vec2 uv,float rot){float r2=dot(uv,uv);vec3 n=vec3(uv,sqrt(max(0.,1.-r2)));",
    " float c=cos(rot),s=sin(rot);return vec3(c*n.x+s*n.z,n.y,-s*n.x+c*n.z);}",
    // Jupiter
    "vec3 jup(vec2 uv){vec3 p=sph(uv,u_rot);float mu=sqrt(max(0.,1.-dot(uv,uv)));float lat=uv.y;",
    " float w=fbm(p*3.5+vec3(0.,u_t*.03,0.));float w2=fbm(p*11.+vec3(u_t*.05,0.,0.));",
    " float lw=lat+(w-.5)*.13*(.4+.6*u_sharp)+(w2-.5)*.045*u_sharp;",
    " float b=sin(lw*21.)*.5+.5;float b2=sin(lw*8.6+1.3)*.5+.5;",
    " vec3 cream=vec3(.95,.9,.8),tan=vec3(.82,.63,.44),brown=vec3(.56,.37,.25),white=vec3(.99,.97,.93);",
    " vec3 col=mix(cream,tan,smoothstep(.3,.78,b2));",
    " col=mix(col,brown,smoothstep(.58,.96,b)*smoothstep(.2,.62,b2)*.85);",
    " col=mix(col,white,smoothstep(.82,1.,sin(lw*33.+2.)*.5+.5)*.4*u_sharp);",
    " col*=.88+.24*fbm(vec3(p.x*5.,lw*70.,p.z*5.))*u_sharp;",
    " float lon=atan(p.x,p.z);vec2 g=vec2((lon-.55),(lat+.34)*2.1);float d=length(g*vec2(1.,1.5));",
    " float sw=fbm(vec3(g*9.+vec2(atan(g.y,g.x)*1.5,0.),u_t*.2));",
    " float grs=smoothstep(.17,.1,d+(sw-.5)*.05*u_sharp);",
    " col=mix(col,vec3(.8,.36,.24)*(.85+.3*sw),grs*.9);col=mix(col,vec3(.97,.9,.8),smoothstep(.24,.18,d)*(1.-grs)*.55);",
    " col*=.32+.68*pow(mu,.42);col=mix(col,col*vec3(.86,.84,.98),pow(1.-mu,2.));return col;}",
    // Moon
    "float crater(vec3 p,float sc,out float rim){vec3 c=floor(p*sc);float bowl=0.;rim=0.;",
    " for(int x=-1;x<=1;x++)for(int y=-1;y<=1;y++)for(int z=-1;z<=1;z++){vec3 cc=c+vec3(x,y,z);float hh=h3(cc);",
    "  if(hh>.55){vec3 ctr=(cc+vec3(h3(cc+7.),h3(cc+13.),h3(cc+21.)))/sc;float r=(.25+.35*h3(cc+3.))/sc;",
    "   float d=length(p-ctr)/r;bowl+=smoothstep(1.,.65,d)*.55;rim+=smoothstep(.7,1.,d)*smoothstep(1.35,1.,d);}}",
    " return bowl;}",
    "vec3 moon(vec2 uv){vec3 p=sph(uv,u_rot*.15+.4);vec3 n=vec3(uv,sqrt(max(0.,1.-dot(uv,uv))));",
    " float m=fbm(p*1.5+3.);float maria=smoothstep(.56,.43,m);",
    " vec3 col=mix(vec3(.8,.8,.82),vec3(.42,.43,.48),maria*.85);col*=.9+.2*fbm(p*14.);",
    " float r1,r2,r3;float c1=crater(p,5.,r1);float c2=crater(p,13.,r2);float c3=crater(p,30.,r3);",
    " float cr=c1+c2*(.4+.6*u_sharp)+c3*u_sharp;float rim=r1+r2*(.4+.6*u_sharp)+r3*u_sharp;",
    " col*=1.-cr*.35;col+=rim*.12;",
    " vec3 L=normalize(vec3(-.32,.26,.91));float lam=max(dot(n,L),0.);col*=.12+.98*lam;return col;}",
    "vec4 body(vec2 uv){float r=length(uv);float px=2.4*u_margin/u_res.x;float a=smoothstep(1.,1.-px,r);",
    " if(a<=0.)return vec4(0.);vec3 col=u_kind<.5?jup(uv/max(r,1.)*min(r,1.)):moon(uv/max(r,1.)*min(r,1.));return vec4(col*a,a);}",
    "void main(){vec2 uv=(gl_FragCoord.xy/u_res*2.-1.)*u_margin;",
    " if(u_chroma<.5){gl_FragColor=body(uv);return;}",
    " vec4 G=body(uv);float rl=length(uv*1.02+vec2(.05,0.)),bl=length(uv*1.02-vec2(.05,0.));",
    " float px=4.*u_margin/u_res.x;float rA=smoothstep(1.,1.-px*3.,rl),bA=smoothstep(1.,1.-px*3.,bl);",
    " vec3 col=G.rgb+vec3(.95,.22,.22)*max(rA-G.a,0.)*.9+vec3(.3,.45,1.)*max(bA-G.a,0.)*.95;",
    " col+=G.a*(vec3(.06,-.01,-.03)*smoothstep(.6,1.,length(uv)));",
    " gl_FragColor=vec4(col,max(G.a,max(rA,bA)*.9));}",
  ].join("\n");
  function sh(type, src) {
    var s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  }
  var prog = gl.createProgram();
  try {
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, "attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}"));
    gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FS));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
  } catch (err) {
    if (window.console) console.warn("fx-planets disabled:", err.message);
    return;
  }
  gl.useProgram(prog);
  var buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  var loc = gl.getAttribLocation(prog, "p");
  gl.enableVertexAttribArray(loc);
  gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
  var U = {};
  ["u_res", "u_rot", "u_sharp", "u_kind", "u_chroma", "u_t", "u_margin"].forEach(function (n) { U[n] = gl.getUniformLocation(prog, n); });
  gl.viewport(0, 0, SIZE, SIZE);
  gl.uniform2f(U.u_res, SIZE, SIZE);
  gl.uniform1f(U.u_margin, MARGIN);

  // Each host gets its own cached disc image so two hosts in one frame never share pixels.
  function renderDisc(target, kind, rot, sharp, chroma, t) {
    gl.uniform1f(U.u_kind, kind);
    gl.uniform1f(U.u_rot, rot);
    gl.uniform1f(U.u_sharp, sharp);
    gl.uniform1f(U.u_chroma, chroma);
    gl.uniform1f(U.u_t, t);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    var c = target.getContext("2d");
    c.clearRect(0, 0, SIZE, SIZE);
    c.drawImage(glc, 0, 0);
  }
  function newDisc() {
    var c = document.createElement("canvas");
    c.width = c.height = SIZE;
    return c;
  }

  /* ---------- small 2D helpers in SVG user units ---------- */
  function seeded(seed) { return function () { seed = (seed * 16807) % 2147483647; return seed / 2147483647; }; }
  function starList(seed, n, x0, y0, x1, y1, circle) {
    var r = seeded(seed), out = [];
    while (out.length < n) {
      var x = x0 + r() * (x1 - x0), y = y0 + r() * (y1 - y0);
      if (circle && (x - circle[0]) * (x - circle[0]) + (y - circle[1]) * (y - circle[1]) > circle[2] * circle[2]) continue;
      out.push([x, y, r(), r()]);
    }
    return out;
  }
  function stars(ctx, list, k, tx, ty, alpha, t) {
    for (var i = 0; i < list.length; i++) {
      var s = list[i];
      var a = alpha * (0.25 + 0.75 * s[2]) * (0.75 + 0.25 * Math.sin(t * (1 + s[3] * 3) + i));
      if (a <= 0.01) continue;
      var size = Math.max(0.6, (0.35 + s[3] * 0.7) * k);
      ctx.fillStyle = "rgba(" + (s[3] > 0.85 ? "255,224,180" : "220,230,255") + "," + a.toFixed(3) + ")";
      ctx.fillRect(s[0] * k + tx - size / 2, s[1] * k + ty - size / 2, size, size);
    }
  }
  function moonDot(ctx, x, y, r, k, tx, ty, alpha) {
    var cx = x * k + tx, cy = y * k + ty, rr = Math.max(0.8, r * k);
    var g = ctx.createRadialGradient(cx - rr * 0.35, cy - rr * 0.35, rr * 0.1, cx, cy, rr);
    g.addColorStop(0, "rgba(255,250,240," + alpha + ")");
    g.addColorStop(0.7, "rgba(205,200,190," + alpha + ")");
    g.addColorStop(1, "rgba(120,115,110," + alpha * 0.9 + ")");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(cx, cy, rr, 0, Math.PI * 2);
    ctx.fill();
    var halo = ctx.createRadialGradient(cx, cy, rr, cx, cy, rr * 3);
    halo.addColorStop(0, "rgba(220,230,255," + 0.18 * alpha + ")");
    halo.addColorStop(1, "rgba(220,230,255,0)");
    ctx.fillStyle = halo;
    ctx.fillRect(cx - rr * 3, cy - rr * 3, rr * 6, rr * 6);
  }
  function glow(ctx, x, y, r, k, tx, ty, rgb, alpha) {
    var cx = x * k + tx, cy = y * k + ty, rr = r * k;
    var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, rr);
    g.addColorStop(0, "rgba(" + rgb + "," + alpha + ")");
    g.addColorStop(1, "rgba(" + rgb + ",0)");
    ctx.fillStyle = g;
    ctx.fillRect(cx - rr, cy - rr, rr * 2, rr * 2);
  }
  function disc(ctx, img, x, y, r, k, tx, ty) {
    var s = r * MARGIN * k;
    ctx.drawImage(img, x * k + tx - s, y * k + ty - s, s * 2, s * 2);
  }

  /* ---------- per-view scenes ---------- */
  var EYE_STARS = starList(31, 260, 4, 4, 296, 262);
  var FINDER_STARS = starList(57, 120, 20, 20, 280, 280, [150, 150, 130]);
  var SCOPE_STARS = starList(83, 40, 20, 20, 280, 280, [150, 150, 130]);
  var SCENES = [
    {
      coarse: function (svg) { return svg.querySelectorAll('circle[cx="196"]'); },
      paint: function (ctx, k, tx, ty, st) {
        stars(ctx, EYE_STARS, k, tx, ty, st.sharp, st.t);
        glow(ctx, 196, 120, 9, k, tx, ty, "255,226,170", 0.5);
        moonDot(ctx, 196, 120, 1.5, k, tx, ty, 1);
      },
    },
    {
      kind: 0,
      coarse: function (svg) { return svg.querySelectorAll('circle[cx="168"]'); },
      paint: function (ctx, k, tx, ty, st) {
        stars(ctx, FINDER_STARS, k, tx, ty, st.sharp, st.t);
        glow(ctx, 168, 132, 14, k, tx, ty, "255,226,170", 0.35);
        disc(ctx, st.img, 168, 132, 4.6, k, tx, ty);
        [[150, 1], [158, 0.85], [178, 0.95], [187, 0.75]].forEach(function (m) { moonDot(ctx, m[0], 132, 0.75 * m[1], k, tx, ty, st.sharp); });
      },
    },
    {
      kind: 0,
      coarse: function (svg) { return svg.querySelectorAll(".seeing-wobble"); },
      paint: function (ctx, k, tx, ty, st) {
        stars(ctx, SCOPE_STARS, k, tx, ty, st.sharp, st.t);
        var wob = (1 - st.sharp) * 1.4;
        var ox = Math.sin(st.t * 7.3) * wob, oy = Math.cos(st.t * 5.1) * wob;
        glow(ctx, 150 + ox, 150 + oy, 62, k, tx, ty, "255,220,170", 0.12);
        disc(ctx, st.img, 150 + ox, 150 + oy, 46, k, tx, ty);
        [[70, 2.4], [104, 2], [206, 2.2], [238, 1.8]].forEach(function (m) { moonDot(ctx, m[0] + ox, 150 + oy, m[1], k, tx, ty, 1); });
      },
    },
  ];
  var CMP = [
    { kind: 1, chroma: 1, paint: function (ctx, k, tx, ty, st) { disc(ctx, st.img, 200, 150, 59, k, tx, ty); } },
    { kind: 1, chroma: 0, paint: function (ctx, k, tx, ty, st) { glow(ctx, 200, 150, 80, k, tx, ty, "220,230,255", 0.1); disc(ctx, st.img, 200, 150, 59, k, tx, ty); } },
  ];

  var fine = matchMedia("(hover: hover) and (pointer: fine)").matches;
  var active = [];
  var raf = 0, start = performance.now();

  function setup(host, scene) {
    var svg = host.querySelector("svg");
    if (!svg) return;
    if (scene.coarse === undefined) {
      scene.coarse = function (s) { return s.querySelectorAll(":scope > circle, :scope > g"); };
    }
    [].forEach.call(scene.coarse(svg), function (el) { el.classList.add("fx-coarse"); });
    if (getComputedStyle(host).position === "static") host.style.position = "relative";
    var overlay = document.createElement("canvas");
    overlay.className = "fx-detail";
    overlay.setAttribute("aria-hidden", "true");
    host.appendChild(overlay);
    var st = { host: host, svg: svg, scene: scene, overlay: overlay, sharp: 0, target: 0, t: 0, img: scene.kind !== undefined ? newDisc() : null, stamp: -1 };
    host.__fxPaint = function (ctx, k, tx, ty) { scene.paint(ctx, k, tx, ty, st); };
    host.__fxDetail = st;
    function focus(on) {
      st.target = on ? 1 : 0;
      host.classList.toggle("fx-focus", on);
      if (active.indexOf(st) < 0) active.push(st);
      if (!raf) raf = requestAnimationFrame(loop);
    }
    if (fine) {
      host.addEventListener("pointerenter", function () { focus(true); });
      host.addEventListener("pointerleave", function () { focus(false); });
    } else {
      new IntersectionObserver(function (entries) { focus(entries[0].intersectionRatio > 0.6); }, { threshold: [0, 0.6, 1] }).observe(host);
    }
  }

  function paintOverlay(st) {
    var hr = st.host.getBoundingClientRect();
    var dpr = Math.min(devicePixelRatio || 1, 2);
    var w = Math.round(hr.width * dpr), h = Math.round(hr.height * dpr);
    if (st.overlay.width !== w || st.overlay.height !== h) { st.overlay.width = w; st.overlay.height = h; }
    var ctx = st.overlay.getContext("2d");
    ctx.clearRect(0, 0, w, h);
    var m = st.svg.getScreenCTM();
    if (!m) return;
    st.scene.paint(ctx, m.a * dpr, (m.e - hr.left) * dpr, (m.f - hr.top) * dpr, st);
  }

  function loop(now) {
    raf = 0;
    var t = (now - start) / 1000;
    for (var i = active.length - 1; i >= 0; i--) {
      var st = active[i];
      var speed = st.target ? 0.035 : 0.09;
      st.sharp += (st.target - st.sharp) * speed;
      if (Math.abs(st.target - st.sharp) < 0.003) st.sharp = st.target;
      st.t = t;
      var eased = st.sharp * st.sharp * (3 - 2 * st.sharp);
      if (st.img) renderDisc(st.img, st.scene.kind, t * 0.09, (0.15 + 0.85 * eased) * (st.scene.chroma ? 0.35 : 1), st.scene.chroma || 0, t);
      st.overlay.style.opacity = Math.min(1, eased * 1.6).toFixed(3);
      var blur = (1 - eased) * 3 + (st.scene.chroma ? 0.7 : 0);
      st.overlay.style.filter = blur > 0.05 ? "blur(" + blur.toFixed(2) + "px)" : "none";
      paintOverlay(st);
      if (st.sharp === 0 && !st.target) {
        st.overlay.getContext("2d").clearRect(0, 0, st.overlay.width, st.overlay.height);
        active.splice(i, 1);
      }
    }
    if (active.length) raf = requestAnimationFrame(loop);
  }

  views.forEach(function (host, i) { if (SCENES[i]) setup(host, SCENES[i]); });
  cmps.forEach(function (host, i) { if (CMP[i]) setup(host, CMP[i]); });

  // The original SVG clips Jupiter's belts with a CSS circle() measured from the
  // belts' own box, which cut them away entirely; use a user-space clipPath.
  var belt = views[2] && views[2].querySelector('.seeing-wobble g[clip-path]');
  if (belt) {
    var ns = "http://www.w3.org/2000/svg";
    var svg = views[2].querySelector("svg");
    var cp = document.createElementNS(ns, "clipPath");
    cp.setAttribute("id", "fxJupiterClip");
    var c = document.createElementNS(ns, "circle");
    c.setAttribute("cx", "150"); c.setAttribute("cy", "150"); c.setAttribute("r", "46");
    cp.appendChild(c);
    svg.insertBefore(cp, svg.firstChild);
    belt.setAttribute("clip-path", "url(#fxJupiterClip)");
  }
})();
