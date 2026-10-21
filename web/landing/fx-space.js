/* Landing-page star-dust layer. One fixed WebGL canvas behind the whole page:
   ~30k particles whose positions are computed in the vertex shader, plus a
   low-resolution nebula pass. As each chapter reaches the middle of the screen
   the dust morphs into that chapter's subject: galaxy (hero/finale),
   constellations (naked eye), light converging through a lens (assembly/optics,
   splitting into colours for chromatic aberration), eyepiece fields with
   Jupiter (observing), star trails (living sky), eight orbits (instrument path),
   a FAST-style dish (principles), the celestial sphere (difference) and Saturn
   (story). The pointer is a gravity well, clicks send a shockwave, fast scrolling
   stretches stars into warp streaks. Without usable WebGL nothing is added. */
(function () {
  "use strict";
  var root = document.documentElement;
  var force = /[?&]fx=full(&|$)/.test(location.search);
  var calm = /[?&]fx=calm(&|$)/.test(location.search); // always full motion, like the Stellar Ascension page
  var small = Math.min(screen.width, screen.height) < 700;
  var lowPower = small || (navigator.hardwareConcurrency || 8) <= 4;

  var canvas = document.createElement("canvas");
  canvas.className = "fx-space";
  canvas.setAttribute("aria-hidden", "true");
  var gl = canvas.getContext("webgl", { alpha: false, antialias: false, premultipliedAlpha: false, powerPreference: "high-performance" });
  if (!gl) return;
  var info = gl.getExtension("WEBGL_debug_renderer_info");
  var renderer = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : "";
  if (/swiftshader|llvmpipe|software|basic render/i.test(renderer) && !force) return;
  if (gl.getParameter(gl.MAX_VERTEX_ATTRIBS) < 8) return;

  var FORMATIONS = 12; // 1..12; formation 0 (open star field) takes whatever weight is left

  var VS = [
    "precision highp float;",
    "attribute vec4 a_r1;attribute vec4 a_r2;attribute vec4 a_gal;attribute vec3 a_gcol;attribute vec4 a_con;",
    "uniform float u_time,u_aspect,u_fit,u_pix,u_intro,u_scroll,u_vel,u_hover,u_bright,u_chroma,u_scale;",
    "uniform float u_w[" + FORMATIONS + "];",
    "uniform vec2 u_mouse,u_tilt;uniform vec3 u_pulse[4];",
    "varying vec3 v_col;varying float v_a;varying float v_streak;",
    "const float TAU=6.2831853;",
    "vec2 rot(vec2 v,float a){float c=cos(a),s=sin(a);return vec2(c*v.x-s*v.y,s*v.x+c*v.y);}",
    "float hash(float n){return fract(sin(n*12.9898)*43758.5453);}",
    "vec3 proj(vec3 p){p.xy*=u_scale;p.yz=rot(p.yz,u_tilt.y*.22);p.xz=rot(p.xz,u_tilt.x*.32);",
    " float zc=2.6-p.z;return vec3(p.xy/zc*1.75*u_fit*vec2(1./u_aspect,1.),zc);}",
    "vec3 jit(){return vec3(a_r1.y,a_r1.z,a_r2.x)-.5;}",

    // 0 · open star field, in screen space with depth parallax
    "vec3 f0(out vec3 C,out float S){float dp=a_r1.z;float zc=mix(3.6,1.6,dp);",
    " float y=mod(a_r1.y*2.6+u_scroll*(.22+.7*dp)+u_time*.004*(.3+dp),2.6)-1.3;",
    " float x=(a_r1.x*2.-1.)*1.08+sin(u_time*.05+a_r2.x*TAU)*.004;",
    " C=mix(vec3(.72,.8,1.),vec3(1.,.84,.6),step(.86,a_r2.y))*(.3+.6*a_r2.z*a_r2.z);S=.55+dp*.9;return vec3(x,y,zc);}",

    // 1 · spiral galaxy (arms precomputed on the CPU)
    "vec3 f1(out vec3 C,out float S){float r=a_gal.x;float rr=r*mix(.015,1.,u_intro);",
    " float ang=a_gal.y+u_time*.035/(.22+r)+(1.-u_intro)*(1.-u_intro)*9./(.3+r);",
    " vec3 p=vec3(cos(ang)*rr,a_gal.z*(.3+.7*u_intro),sin(ang)*rr);",
    " p.yz=rot(p.yz,.98);p.xz=rot(p.xz,.35);p.xy=rot(p.xy,-.32);",
    " C=a_gcol;S=1.;vec3 q=proj(p);q.y+=.04;return q;}",

    // 2 · constellations (positions precomputed on the CPU, w = brightness)
    "vec3 f2(out vec3 C,out float S){vec3 p=a_con.xyz;p.xy=rot(p.xy,u_time*.006);",
    " float tw=.7+.3*sin(u_time*(1.+a_r2.x*3.)+a_r2.y*50.);",
    " C=mix(vec3(.5,.64,1.)*.55,vec3(1.,.9,.7),a_con.w)*(.22+.95*a_con.w)*tw;S=.6+a_con.w*1.9;return proj(p);}",

    // 3 · parallel light through an objective lens to a focus (u_chroma splits colours)
    "vec3 f3(out vec3 C,out float S){float lx=-.35;float k=a_r2.w;float w=a_r2.x;",
    " float fx=.95+u_chroma*(w-.5)*.8;vec3 p;",
    " if(k<.12){float rr=sqrt(a_r1.x)*.66;float th=a_r1.y*TAU;",
    "  p=vec3(lx+(a_r1.z*2.-1.)*.09*(1.-rr*rr/.44),cos(th)*rr,sin(th)*rr);C=vec3(.55,.72,1.)*.5;S=.85;}",
    " else if(k<.19){p=vec3(fx,0.,0.)+jit()*.07;",
    "  vec3 sc=clamp(vec3(1.5-w*2.5,1.-abs(w-.5)*2.4,w*2.5-1.)+.15,0.,1.);C=mix(vec3(1.,.9,.7),sc,u_chroma)*1.2;S=1.7;}",
    " else{float ph=fract(a_r1.y+u_time*.07*(.7+.3*a_r2.y));float x=mix(-2.4,2.4,ph);",
    "  float beam=floor(a_r1.x*9.);vec2 o=vec2((beam/8.*2.-1.)*.62,(a_r1.w-.5)*.035);",
    "  float s=x<lx?1.:1.-(x-lx)/(fx-lx);p=vec3(x,o.x*s,o.y*s);",
    "  vec3 sc=clamp(vec3(1.5-w*2.5,1.-abs(w-.5)*2.4,w*2.5-1.)+.15,0.,1.);",
    "  C=mix(vec3(1.,.86,.62),sc,u_chroma)*(.5+.4*a_r1.z)*smoothstep(0.,.08,ph)*smoothstep(1.,.9,ph);S=.85;}",
    " p.xz=rot(p.xz,-.25);return proj(p);}",

    // 4 · eyepiece fields of view with Jupiter and the Galilean moons
    "vec3 f4(out vec3 C,out float S){float k=a_r2.w;vec3 p;",
    " if(k<.42){float ri=floor(a_r1.x*3.);float R=ri<.5?1.3:(ri<1.5?.78:.36);",
    "  float a=a_r1.y*TAU+u_time*.04*(ri-1.);R+=(a_r1.z-.5)*.018;",
    "  p=vec3(cos(a)*R,sin(a)*R,0.);C=vec3(1.,.8,.5)*(.28+.2*ri);S=.8;}",
    " else if(k<.5){float l=mix(.42,1.3,a_r1.x)*(a_r1.z<.5?-1.:1.);",
    "  p=a_r1.y<.5?vec3(l,0.,0.):vec3(0.,l,0.);C=vec3(.7,.8,1.)*.3;S=.6;}",
    " else if(k<.82){float rr=sqrt(a_r1.x)*.2;float a=a_r1.y*TAU;vec2 q=vec2(cos(a),sin(a))*rr;",
    "  float lat=q.y/.2,lon=q.x/.2;float band=sin(lat*9.+sin(lon*3.+u_time*.3)*.4);",
    "  C=mix(vec3(.85,.6,.4),vec3(1.,.93,.8),band*.5+.5);",
    "  float sx=fract(u_time*.03)*2.4-1.2;C=mix(C,vec3(.95,.38,.24),exp(-pow(lon-sx,2.)*30.-pow(lat+.38,2.)*110.));",
    "  C*=.35+.85*sqrt(max(0.,1.-rr*rr/.04));S=1.15;p=vec3(q,0.);}",
    " else if(k<.88){float mi=floor(a_r1.x*4.);float A=.3+mi*.13;",
    "  p=vec3(A*sin(u_time*.36/(mi+1.)+mi*1.7),0.,0.)+jit()*.014;C=vec3(1.,.95,.85)*1.1;S=1.3;}",
    " else{p=vec3(a_r1.x*2.-1.,a_r1.y*2.-1.,0.)*1.15;C=vec3(.9,.93,1.)*.4*a_r1.z;S=.7;}",
    " return proj(p);}",

    // 5 · star trails around the celestial pole (75 particles share one trail)
    "vec3 f5(out vec3 C,out float S){float id=floor(a_r1.x*190.);",
    " float R=.12+sqrt(hash(id))*2.9;float head=hash(id+7.)*TAU+u_time*.03;",
    " float tail=a_r2.x*(.55+hash(id+3.)*.9);float a=head-tail;",
    " vec3 p=vec3(vec2(0.,1.05)+vec2(cos(a),sin(a))*R,(hash(id+5.)-.5)*.3);",
    " float hc=hash(id+11.);vec3 sc=hc<.3?vec3(.62,.74,1.):hc<.55?vec3(1.,.78,.52):vec3(.95,.95,1.);",
    " C=sc*(.2+.8*(1.-a_r2.x))*(.5+.5*hash(id+13.))*.8;S=.6+.6*(1.-a_r2.x);return proj(p);}",

    // 6 · eight orbits (one per instrument) around a sun
    "vec3 f6(out vec3 C,out float S){float i=floor(a_r1.x*8.);float R=.28+i*.19;float k=a_r2.w;vec3 p;",
    " if(k<.6){float a=a_r1.y*TAU;p=vec3(cos(a)*R,(a_r1.z-.5)*.008,sin(a)*R);C=vec3(.55,.68,1.)*.36;S=.62;}",
    " else if(k<.9){float a=u_time*.25/pow(R,1.5)+hash(i)*TAU;",
    "  p=vec3(cos(a)*R,0.,sin(a)*R)+normalize(jit()+1e-4)*pow(a_r2.y,2.)*(.022+.01*mod(i,3.));",
    "  C=(.72+.28*cos(TAU*(vec3(0.,.1,.22)+i*.19)))*vec3(1.,.9,.8)*1.2;S=1.25;}",
    " else{p=jit()*.13;C=vec3(1.,.8,.45)*1.25;S=1.5;}",
    " p.yz=rot(p.yz,.5);return proj(p);}",

    // 7 · FAST-style dish: grid, falling rays reflected to the feed, cables
    "vec3 f7(out vec3 C,out float S){float k=a_r2.w;float Rm=1.25,f=.55;vec3 p;vec3 feed=vec3(0.,f-.5,0.);",
    " if(k<.55){float x,z;if(a_r1.x<.5){float ri=ceil(a_r1.y*8.)/8.*Rm;float a=a_r1.z*TAU;x=cos(a)*ri;z=sin(a)*ri;}",
    "  else{float a=floor(a_r1.y*24.)/24.*TAU;float rr=a_r1.z*Rm;x=cos(a)*rr;z=sin(a)*rr;}",
    "  p=vec3(x,(x*x+z*z)/(4.*f)-.5,z);C=vec3(.6,.75,1.)*.55;S=.7;}",
    " else if(k<.75){float rr=sqrt(a_r1.x)*Rm;float a=a_r1.y*TAU;vec3 d=vec3(cos(a)*rr,rr*rr/(4.*f)-.5,sin(a)*rr);",
    "  float ph=fract(a_r1.z+u_time*.12);p=ph<.6?vec3(d.x,mix(1.5,d.y,ph/.6),d.z):mix(d,feed,(ph-.6)/.4);",
    "  C=vec3(1.,.82,.5)*.55*smoothstep(0.,.1,ph);S=.75;}",
    " else if(k<.85){p=feed+jit()*.07;C=vec3(1.,.9,.7)*1.2;S=1.4;}",
    " else{float c=floor(a_r1.y*6.)/6.*TAU;vec3 top=vec3(cos(c)*Rm*1.08,.55,sin(c)*Rm*1.08);",
    "  p=mix(top,feed,a_r1.x);C=vec3(.7,.8,1.)*.3;S=.6;}",
    " p.xz=rot(p.xz,u_time*.05);p.yz=rot(p.yz,.35);p.y-=.1;return proj(p);}",

    // 8 · celestial sphere: alt-az grid, ecliptic and stars, turning on a tilted pole
    "vec3 f8(out vec3 C,out float S){float k=a_r2.w;float lat,lon;C=vec3(.55,.7,1.)*.42;S=.7;",
    " if(k<.35){lat=(floor(a_r1.x*11.)-5.)*.2618;lon=a_r1.y*TAU;}",
    " else if(k<.6){lon=floor(a_r1.x*12.)/12.*TAU;lat=(a_r1.y-.5)*3.1416;}",
    " else if(k<.7){lon=a_r1.y*TAU;lat=sin(lon)*.408;C=vec3(1.,.8,.48)*.7;S=.9;}",
    " else{lat=asin(a_r1.x*2.-1.);lon=a_r1.y*TAU;C=vec3(1.,.95,.88)*(.3+.9*a_r1.z*a_r1.z);S=.8+a_r1.z*1.2;}",
    " vec3 p=1.2*vec3(cos(lat)*cos(lon),sin(lat),cos(lat)*sin(lon));",
    " p.xz=rot(p.xz,u_time*.04);p.yz=rot(p.yz,.6);C*=.35+.65*smoothstep(-1.2,1.2,p.z);return proj(p);}",

    // 9 · Saturn and its rings with the Cassini division
    "vec3 f9(out vec3 C,out float S){float k=a_r2.w;vec3 p;",
    " if(k<.35){float y=a_r1.x*2.-1.;float a=a_r1.y*TAU;float r=sqrt(1.-y*y);p=vec3(cos(a)*r,y*.9,sin(a)*r)*.42;",
    "  C=mix(vec3(.85,.7,.45),vec3(1.,.9,.7),.5+.5*sin(y*14.))*.75;S=1.;}",
    " else{float rr=mix(.62,1.2,a_r1.x);if(rr>.92&&rr<.97)rr+=.06;float a=a_r1.y*TAU+u_time*.2/pow(rr,1.5);",
    "  p=vec3(cos(a)*rr,(a_r1.z-.5)*.006,sin(a)*rr);C=vec3(1.,.88,.66)*(.25+.35*sin(rr*40.)*sin(rr*40.));S=.75;}",
    " p.yz=rot(p.yz,.42);p.xy=rot(p.xy,-.25);return proj(p);}",

    // shared Newtonian tube: axis along x, open end at -x, focuser on top
    "vec3 newt(float k,out vec3 C,out float S){float L=1.25,R=.42;vec3 p;",
    " if(k<.3){if(a_r1.x<.55){float x=mix(-L,L,floor(a_r1.y*7.)/6.);float a=a_r1.z*TAU;p=vec3(x,cos(a)*R,sin(a)*R);}",
    "  else{float a=floor(a_r1.y*10.)/10.*TAU;p=vec3(mix(-L,L,a_r1.z),cos(a)*R,sin(a)*R);}C=vec3(.55,.7,1.)*.75;S=.8;}",
    " else if(k<.45){float rr=sqrt(a_r1.x)*.38;float a=a_r1.y*TAU;p=vec3(L-.08-rr*rr*.6,cos(a)*rr,sin(a)*rr);C=vec3(.6,.8,1.)*1.2;S=1.;}",
    " else if(k<.5){float u=(a_r1.x*2.-1.)*.13,v=(a_r1.y*2.-1.)*.1;p=vec3(-.85,0.,0.)+u*vec3(.7071,-.7071,0.)+vec3(0.,0.,v);C=vec3(.75,.88,1.);S=.95;}",
    " else if(k<.56){float a=a_r1.y*TAU;p=vec3(-.85+cos(a)*.07,mix(R,R+.26,a_r1.x),sin(a)*.07);C=vec3(.95,.8,.55)*.65;S=.8;}",
    " else{float bm=floor(a_r1.x*6.);float ang=bm/6.*TAU+.3;vec2 o=vec2(cos(ang),sin(ang))*.3;",
    "  float ph=fract(a_r1.y+u_time*.09);float xm=L-.08-.054;",
    "  vec3 a0=vec3(-2.2,o.x,o.y),a1=vec3(xm,o.x,o.y),a2=vec3(-.85,0.,0.),a3=vec3(-.85,R+.26,0.);",
    "  float l1=xm+2.2,l2=length(a2-a1),l3=R+.26,d=ph*(l1+l2+l3);",
    "  p=d<l1?mix(a0,a1,d/l1):d<l1+l2?mix(a1,a2,(d-l1)/l2):mix(a2,a3,(d-l1-l2)/l3);",
    "  C=vec3(1.,.82,.5)*(.8+.4*a_r1.z)*smoothstep(0.,.05,ph);S=.9;}",
    " return p;}",

    // 10 · Newtonian reflector
    "vec3 f10(out vec3 C,out float S){vec3 p=newt(a_r2.w,C,S);",
    " p.xz=rot(p.xz,.28+sin(u_time*.15)*.3);p.yz=rot(p.yz,.22);return proj(p);}",

    // 11 · Dobsonian: the tube on a rocker box over a ground board
    "vec3 f11(out vec3 C,out float S){float k=a_r2.w;vec3 p;",
    " if(k<.72){p=newt(k/.72,C,S)*.82;p.xy=rot(p.xy,-.6);p.y+=.3;}",
    " else if(a_r1.z<.22){float a=a_r1.y*TAU;p=vec3(cos(a)*.78,-.9,sin(a)*.78);C=vec3(1.,.75,.45)*.65;S=.8;}",
    " else{float e=floor(a_r1.x*12.);float ax=floor(e/4.);float m=mod(e,4.);vec3 h=vec3(.34,.3,.42);",
    "  float s1=mod(m,2.)<.5?-1.:1.,s2=m<1.5?-1.:1.;float t=mix(-1.,1.,a_r1.y);",
    "  vec3 q=ax<.5?vec3(t,s1,s2):ax<1.5?vec3(s1,t,s2):vec3(s1,s2,t);p=q*h+vec3(0.,-.56,0.);",
    "  C=vec3(1.,.72,.42)*.85;S=.9;}",
    " p.xz=rot(p.xz,.45+sin(u_time*.15)*.35);p.yz=rot(p.yz,.2);return proj(p);}",

    // 12 · James Webb: 18 hexagonal segments, secondary on a tripod, five-layer sunshield
    "vec3 f12(out vec3 C,out float S){float k=a_r2.w;vec3 p;float s=.2;",
    " if(k<.5){float i=floor(a_r1.x*18.);float ang,dist;",
    "  if(i<6.){ang=i*1.0472;dist=1.732*s;}",
    "  else{float j=i-6.;float jj=floor(j/2.);if(mod(j,2.)<.5){ang=jj*1.0472;dist=3.464*s;}else{ang=jj*1.0472+.5236;dist=3.*s;}}",
    "  vec2 c=vec2(cos(ang),sin(ang))*dist;float q=floor(a_r1.y*6.);float a=a_r1.z,b=a_r2.x;if(a+b>1.){a=1.-a;b=1.-b;}",
    "  float r=s*.94;vec2 v1=vec2(cos(q*1.0472+.5236),sin(q*1.0472+.5236))*r,v2=vec2(cos(q*1.0472+1.5708),sin(q*1.0472+1.5708))*r;",
    "  vec2 xy=c+a*v1+b*v2;p=vec3(xy,-dot(xy,xy)*.12);",
    "  float edge=1.-max(a+b,max(a,b));C=vec3(1.,.78,.38)*(.75+.4*a_r1.w)*(1.+.8*smoothstep(.12,0.,abs(a+b-1.)));S=.9;}",
    " else if(k<.56){float rr=sqrt(a_r1.x)*.1;float a=a_r1.y*TAU;p=vec3(cos(a)*rr,sin(a)*rr,.95);C=vec3(1.,.88,.6)*1.1;S=1.1;}",
    " else if(k<.66){float c=floor(a_r1.y*3.)/3.*TAU+1.5708;vec3 base=vec3(cos(c)*.95,sin(c)*.95,-.08);",
    "  p=mix(base,vec3(0.,0.,.95),a_r1.x);C=vec3(.7,.8,1.)*.35;S=.65;}",
    " else{float l=floor(a_r1.x*5.);float y=-.78-l*.07;vec2 d;",
    "  if(a_r1.y<.62){float e=floor(a_r1.z*4.);float t=a_r2.x;vec2 A=e<.5?vec2(1.6,0.):e<1.5?vec2(0.,.95):e<2.5?vec2(-1.6,0.):vec2(0.,-.95);",
    "   vec2 B=e<.5?vec2(0.,.95):e<1.5?vec2(-1.6,0.):e<2.5?vec2(0.,-.95):vec2(1.6,0.);d=mix(A,B,t);}",
    "  else{float u=a_r1.z*2.-1.,v=a_r2.x*2.-1.;float m=abs(u)+abs(v);if(m>1.){u/=m;v/=m;}d=vec2(u*1.6,v*.95);}",
    "  d*=1.-l*.07;p=vec3(d.x,y,d.y+.25);C=vec3(.9,.72,.95)*(.42+.12*(4.-l));S=.75;}",
    " p.yz=rot(p.yz,-.3);p.xz=rot(p.xz,sin(u_time*.15)*.6);return proj(p);}",

    "void main(){",
    " vec3 C0;float S0;vec3 P0=f0(C0,S0);",
    " float d=a_r2.z;float keep=step(.18,fract(a_r2.y*7.13));",
    " vec3 Pm=vec3(0.),Cm=vec3(0.);float Sm=0.,sw=0.;vec3 Pi,Ci;float Si,wi;",
  ];
  for (var i = 1; i <= FORMATIONS; i++) {
    VS.push(
      " if(u_w[" + (i - 1) + "]>.001){wi=smoothstep(d*.4,d*.4+.6,u_w[" + (i - 1) + "])*keep;" +
        "if(wi>0.){Pi=f" + i + "(Ci,Si);Pm+=wi*Pi;Cm+=wi*Ci;Sm+=wi*Si;sw+=wi;}}"
    );
  }
  VS.push(
    " if(sw>1.){Pm/=sw;Cm/=sw;Sm/=sw;sw=1.;}Sm*=1.55;Cm*=1.25;",
    " vec3 P=P0*(1.-sw)+Pm;vec3 C=C0*(1.-sw)+Cm;float S=S0*(1.-sw)+Sm;",
    " vec2 sp=P.xy;vec2 dm=sp-u_mouse;dm.x*=u_aspect;float dist=length(dm);",
    " float f=exp(-dist*dist*14.)*u_hover;vec2 rd=rot(dm,f*1.7)*(1.-f*.38);rd.x/=u_aspect;sp=u_mouse+rd;",
    " float glow=0.;",
    " for(int i=0;i<4;i++){vec3 pu=u_pulse[i];if(pu.z<1.){vec2 q=sp-pu.xy;q.x*=u_aspect;float r=length(q);",
    "  float ring=exp(-pow((r-pu.z*1.6)*8.,2.))*(1.-pu.z);vec2 n=normalize(q+1e-5)*ring*.08;n.x/=u_aspect;sp+=n;glow+=ring;}}",
    " v_streak=clamp(abs(u_vel)*90./P.z,0.,4.);",
    " gl_Position=vec4(sp,0.,1.);",
    " gl_PointSize=(.9+a_r1.w*a_r1.w*a_r1.w*3.2)*S*u_pix/P.z*(1.+f*1.4+glow*2.)*(1.+v_streak);",
    " v_col=C*u_bright*(1.+f*2.2+glow*2.4);",
    " v_a=(.65+.35*sin(u_time*(.8+a_r2.x*2.6)+a_r2.y*61.))*clamp(2.2/P.z,0.,1.2);",
    "}"
  );
  VS = VS.join("\n");

  var FS = [
    "precision mediump float;varying vec3 v_col;varying float v_a;varying float v_streak;",
    "void main(){vec2 c=gl_PointCoord-.5;c.x*=1.+v_streak;float d=length(c);",
    " float a=smoothstep(.5,0.,d);a=a*a*a+smoothstep(.12,0.,d)*.6;",
    " gl_FragColor=vec4(v_col*a*v_a/(1.+v_streak*.6),1.);}",
  ].join("\n");

  var QUAD_VS = "attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}";
  var NEB_FS = [
    "precision highp float;",
    "uniform vec2 u_res;uniform float u_time,u_neb,u_hover,u_scroll;uniform vec2 u_mouse;uniform vec3 u_ta,u_tb,u_pulse;",
    "float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}",
    "float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);",
    " return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}",
    "float fbm(vec2 p){float v=0.,a=.5;mat2 m=mat2(1.6,1.2,-1.2,1.6);for(int i=0;i<5;i++){v+=a*n(p);p=m*p;a*=.5;}return v;}",
    "void main(){vec2 uv=gl_FragCoord.xy/u_res;float asp=u_res.x/u_res.y;",
    " vec2 p=uv*2.-1.;p.x*=asp;vec2 m=u_mouse;m.x*=asp;vec2 dm=p-m;float r=length(dm);",
    " p-=dm/(r*r+.035)*.018*u_hover;",
    " vec2 sd=p-vec2(u_pulse.x*asp,u_pulse.y);float sr=length(sd);float sw=exp(-pow((sr-u_pulse.z*1.9)*7.,2.))*(1.-u_pulse.z);",
    " p+=normalize(sd+1e-4)*sw*.06;p.y+=u_scroll*.18;",
    " float t=u_time*.018;vec2 q=vec2(fbm(p*1.25+t),fbm(p*1.25+vec2(5.2,1.3)-t));",
    " vec2 w=vec2(fbm(p*1.5+q*2.1+vec2(1.7,9.2)+t*1.4),fbm(p*1.5+q*2.1+vec2(8.3,2.8)-t));",
    " float f=fbm(p*1.7+w*2.3);float band=exp(-pow((p.y+p.x*.38-.05)*1.25,2.));",
    " vec3 c=mix(vec3(.012,.018,.05),u_ta*.42,smoothstep(.25,.85,f));",
    " c=mix(c,u_tb*.55,smoothstep(.5,1.15,length(w))*.75);",
    " c+=vec3(1.,.78,.45)*pow(max(f-.48,0.),2.2)*2.6;c*=.28+1.05*band;",
    " c=mix(vec3(.012,.018,.05)*.6,c,u_neb);",
    " c+=vec3(1.,.8,.5)*u_hover*.028/(r+.07)*(.4+.6*u_neb);",
    " c+=vec3(1.,.88,.66)*exp(-pow((r-.085)*55.,2.))*.35*u_hover;c+=vec3(1.,.85,.6)*sw*.3;",
    " float vig=smoothstep(1.65,.35,length((uv-.5)*vec2(asp,1.)*1.2));",
    " gl_FragColor=vec4(c*mix(1.,vig,.7),1.);}",
  ].join("\n");
  var BLIT_FS = "precision mediump float;uniform sampler2D u_tex;uniform vec2 u_res;void main(){gl_FragColor=texture2D(u_tex,gl_FragCoord.xy/u_res);}";

  function compile(vs, fs) {
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
    gl.bindAttribLocation(prog, 0, vs === QUAD_VS ? "p" : "a_r1");
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
    var u = {};
    var count = gl.getProgramParameter(prog, gl.ACTIVE_UNIFORMS);
    for (var i = 0; i < count; i++) {
      var name = gl.getActiveUniform(prog, i).name.replace(/\[0\]$/, "");
      u[name] = gl.getUniformLocation(prog, name);
    }
    return { prog: prog, u: u };
  }
  var stars, neb, blit;
  try {
    stars = compile(VS, FS);
    neb = compile(QUAD_VS, NEB_FS);
    blit = compile(QUAD_VS, BLIT_FS);
  } catch (err) {
    if (window.console) console.warn("fx-space disabled:", err.message);
    return;
  }

  /* ---------- particle data ---------- */
  var COUNT = lowPower ? 14000 : 32000;
  var seed = 9001;
  function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647; }
  function gauss() { return (rnd() + rnd() + rnd() + rnd() - 2) * 0.5; }

  var r1 = new Float32Array(COUNT * 4), r2 = new Float32Array(COUNT * 4);
  var gal = new Float32Array(COUNT * 4), gcol = new Float32Array(COUNT * 3), con = new Float32Array(COUNT * 4);

  // Constellations in a 4 x 2.2 sky (x right, y up), each a list of stars and lines.
  var SKY = [
    { s: [[-1.55, .55], [-1.32, .62], [-1.12, .58], [-.95, .5], [-.82, .3], [-.6, .34], [-.62, .6]], l: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 3]] }, // Big Dipper
    { s: [[.1, .2], [.48, .25], [.18, -.15], [.27, -.17], [.36, -.19], [.12, -.55], [.5, -.5], [.27, -.38]], l: [[0, 2], [1, 4], [2, 3], [3, 4], [2, 5], [4, 6], [3, 7]] }, // Orion
    { s: [[1.0, .72], [1.18, .55], [1.36, .68], [1.55, .52], [1.74, .66]], l: [[0, 1], [1, 2], [2, 3], [3, 4]] }, // Cassiopeia
    { s: [[-1.3, -.35], [-1.3, -.62], [-1.3, -.9], [-1.55, -.55], [-1.05, -.7]], l: [[0, 1], [1, 2], [3, 1], [1, 4]] }, // Cygnus
    { s: [[1.05, -.25], [1.25, -.18], [1.42, -.3], [1.4, -.55], [1.65, -.62], [1.2, -.6]], l: [[0, 1], [1, 2], [2, 3], [3, 4], [3, 5], [5, 0]] }, // Leo
  ];
  var nodes = [], segs = [];
  SKY.forEach(function (c) {
    var base = nodes.length;
    c.s.forEach(function (p) { nodes.push(p); });
    c.l.forEach(function (l) { segs.push([nodes[base + l[0]], nodes[base + l[1]]]); });
  });

  for (var i = 0; i < COUNT; i++) {
    for (var k = 0; k < 4; k++) { r1[i * 4 + k] = rnd(); r2[i * 4 + k] = rnd(); }

    var kind = rnd();
    var core = kind < 0.2, disk = !core && kind < 0.45;
    var radius = core ? Math.abs(gauss()) * 0.32 : Math.pow(rnd(), disk ? 0.7 : 0.9) * 1.35 + 0.06;
    var arm = Math.floor(rnd() * 3);
    var spread = gauss() * (0.9 / (radius * 1.6 + 0.7));
    var angle = core || disk ? rnd() * Math.PI * 2 : (arm / 3) * Math.PI * 2 + radius * 3.6 + spread;
    if (!core) radius = Math.max(0.04, radius + gauss() * 0.07);
    var height = gauss() * (core ? 0.09 : 0.035 * (1.4 - radius / 1.35));
    gal.set([radius, angle, height, 0], i * 4);
    var kk = Math.min(1, radius / 1.35), pick = rnd(), c;
    if (core || kk < 0.12) c = [1.0, 0.82, 0.55];
    else if (pick < 0.06) c = [1.0, 0.42, 0.55];
    else if (pick < 0.22) c = [1.0, 0.78, 0.48];
    else c = [0.45 + 0.25 * (1 - kk), 0.6 + 0.2 * (1 - kk), 1.0];
    var b = (core ? 0.34 : disk ? 0.16 : 0.36) * 2.1 * (0.6 + rnd() * 0.6);
    gcol.set([c[0] * b, c[1] * b, c[2] * b], i * 3);

    var role = rnd();
    if (role < 0.05) {
      var nd = nodes[Math.floor(rnd() * nodes.length)];
      con.set([nd[0] + gauss() * 0.008, nd[1] + gauss() * 0.008, gauss() * 0.02, 1], i * 4);
    } else if (role < 0.32) {
      var sg = segs[Math.floor(rnd() * segs.length)], t = rnd();
      con.set([sg[0][0] + (sg[1][0] - sg[0][0]) * t, sg[0][1] + (sg[1][1] - sg[0][1]) * t, 0, 0.32], i * 4);
    } else {
      con.set([(rnd() * 2 - 1) * 2.1, (rnd() * 2 - 1) * 1.15, (rnd() * 2 - 1) * 0.4, 0.06 * rnd()], i * 4);
    }
  }

  function buffer(data, name, size) {
    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
    return { buf: buf, loc: gl.getAttribLocation(stars.prog, name), size: size };
  }
  var attribs = [buffer(r1, "a_r1", 4), buffer(r2, "a_r2", 4), buffer(gal, "a_gal", 4), buffer(gcol, "a_gcol", 3), buffer(con, "a_con", 4)];
  var quad = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, quad);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);

  document.body.insertBefore(canvas, document.body.firstChild);
  root.classList.add("fx-space-on");
  window.__fxSpace = true;

  /* ---------- sizing ---------- */
  var fbo = gl.createFramebuffer(), tex = gl.createTexture();
  var W = 2, H = 2, NW = 2, NH = 2, dpr = 1, quality = 1, drawCount = COUNT;
  function resize() {
    dpr = Math.min(devicePixelRatio || 1, lowPower ? 1 : 1.25);
    W = Math.max(2, Math.round(innerWidth * dpr));
    H = Math.max(2, Math.round(innerHeight * dpr));
    canvas.width = W;
    canvas.height = H;
    var scale = (lowPower ? 0.3 : 0.42) * quality;
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
  var resizeTimer = 0;
  addEventListener("resize", function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(resize, 120);
  }, { passive: true });

  /* ---------- chapters → formations ---------- */
  // [selector, formation (0 = open field), nebula strength, tint A, tint B, brightness, child to exclude]
  var REGIONS = [
    ["#top", 1, 1, [0.32, 0.45, 1.0], [1.0, 0.62, 0.28], 1],
    ["#eye", 2, 0.42, [0.25, 0.35, 0.9], [0.5, 0.4, 0.9], 1.45],
    ["#assemble", 3, 0.3, [0.3, 0.45, 1.0], [1.0, 0.7, 0.35], 1.45],
    ["#optics", 3, 0.32, [0.25, 0.5, 1.0], [0.4, 0.8, 1.0], 1.45, "#reflector"],
    ["#reflector", 3, 0.38, [0.9, 0.25, 0.35], [0.25, 0.45, 1.0], 1.45],
    ["#observe", 4, 0.3, [0.45, 0.4, 0.9], [1.0, 0.7, 0.4], 1.45],
    ["#sky-live", 5, 0.4, [0.2, 0.3, 0.85], [0.35, 0.55, 1.0], 1.45],
    ["#path", 6, 0.3, [0.4, 0.45, 1.0], [1.0, 0.65, 0.35], 1.45, "#principles"],
    ["#principles", 7, 0.3, [0.3, 0.5, 1.0], [1.0, 0.7, 0.4], 1.45],
    ["#difference", 8, 0.36, [0.5, 0.35, 0.95], [0.3, 0.6, 1.0], 1.45],
    ["#story", 9, 0.4, [0.9, 0.6, 0.35], [0.6, 0.4, 0.9], 1.45],
    ["#features", 0, 0.35, [0.4, 0.4, 1.0], [1.0, 0.65, 0.35], 1.45],
    ["#join", 1, 1, [0.55, 0.32, 0.95], [1.0, 0.7, 0.32], 1],
  ].map(function (r) {
    var scale = { 0: 1, 1: 1, 2: 1.45, 3: 1.55, 4: 1.65, 5: 1.05, 6: 1.75, 7: 1.55, 8: 1.6, 9: 1.7 }[r[1]];
    return { el: document.querySelector(r[0]), f: r[1], dyn: r[0] === "#principles", neb: r[2], ta: r[3], tb: r[4], bright: r[5], scale: scale, ex: r[6] ? document.querySelector(r[6]) : null, isReflector: r[0] === "#reflector" };
  }).filter(function (r) { return r.el; });

  // The principles chapter follows its instrument tabs: Newtonian, Dobsonian, Webb, FAST.
  var INSTRUMENTS = [10, 11, 12, 7];
  var tabs = [].slice.call(document.querySelectorAll(".instrument-tab"));
  function instrument() {
    for (var i = 0; i < tabs.length; i++) if (tabs[i].getAttribute("aria-pressed") === "true") return INSTRUMENTS[i] || 7;
    return INSTRUMENTS[0];
  }
  var curW = new Float32Array(FORMATIONS), tgtW = new Float32Array(FORMATIONS);
  var look = { neb: 1, ta: [0.32, 0.45, 1.0], tb: [1.0, 0.62, 0.28], bright: 1, chroma: 0, scale: 1 };
  var tgt = { neb: 1, ta: [0, 0, 0], tb: [0, 0, 0], bright: 1, chroma: 0, scale: 1 };
  function overlap(el, b0, b1) {
    var r = el.getBoundingClientRect();
    return Math.max(0, Math.min(r.bottom, b1) - Math.max(r.top, b0));
  }
  function measure() {
    var b0 = innerHeight * 0.3, b1 = innerHeight * 0.7, span = b1 - b0;
    var i, total = 0, reflector = 0, rays = 0;
    for (i = 0; i < FORMATIONS; i++) tgtW[i] = 0;
    tgt.neb = 0; tgt.bright = 0; tgt.scale = 0;
    tgt.ta = [0, 0, 0]; tgt.tb = [0, 0, 0];
    REGIONS.forEach(function (r) {
      var o = overlap(r.el, b0, b1);
      if (r.ex) o -= overlap(r.ex, b0, b1);
      o = Math.max(0, o) / span;
      if (!o) return;
      total += o;
      var f = r.dyn ? instrument() : r.f;
      if (f) tgtW[f - 1] += o;
      if (r.dyn) r.scale = f === 7 ? 1.55 : 1.12;
      if (r.f === 3) { rays += o; if (r.isReflector) reflector += o; }
      tgt.neb += r.neb * o;
      tgt.bright += r.bright * o;
      tgt.scale += r.scale * o;
      for (var c = 0; c < 3; c++) { tgt.ta[c] += r.ta[c] * o; tgt.tb[c] += r.tb[c] * o; }
    });
    if (total > 0) {
      tgt.neb /= total; tgt.bright /= total; tgt.scale /= total;
      for (var c = 0; c < 3; c++) { tgt.ta[c] /= total; tgt.tb[c] /= total; }
      var sum = 0;
      for (i = 0; i < FORMATIONS; i++) sum += tgtW[i];
      if (sum > 1) for (i = 0; i < FORMATIONS; i++) tgtW[i] /= sum;
    } else {
      tgt.neb = look.neb; tgt.bright = look.bright; tgt.scale = look.scale; tgt.ta = look.ta.slice(); tgt.tb = look.tb.slice();
    }
    tgt.chroma = rays > 0 ? reflector / rays : look.chroma;
  }

  /* ---------- input ---------- */
  var mouse = { x: 0, y: 0, tx: 0, ty: 2, hover: 0, thover: 0, tiltX: 0, tiltY: 0 };
  var pulses = [[0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1]], pulseIdx = 0, nebPulse = [0, 0, 1];
  function toNdc(e) { return [(e.clientX / innerWidth) * 2 - 1, 1 - (e.clientY / innerHeight) * 2]; }
  addEventListener("pointermove", function (e) {
    var p = toNdc(e);
    mouse.tx = p[0]; mouse.ty = p[1];
    mouse.thover = 1;
    if (e.pointerType !== "mouse") mouse.touchUntil = performance.now() + 900;
  }, { passive: true });
  document.addEventListener("pointerleave", function () { mouse.thover = 0; });
  addEventListener("pointerdown", function (e) {
    if (e.target instanceof Element && e.target.closest("input, textarea, select, .po-modal")) return;
    var p = toNdc(e);
    pulses[pulseIdx] = [p[0], p[1], 0];
    pulseIdx = (pulseIdx + 1) % 4;
    nebPulse = [p[0], p[1], 0];
    mouse.tx = p[0]; mouse.ty = p[1];
    mouse.thover = 1;
    if (e.pointerType !== "mouse") mouse.touchUntil = performance.now() + 1200;
  }, { passive: true });

  /* ---------- intro ---------- */
  var introSeen = false;
  try { introSeen = !!sessionStorage.getItem("fx-intro-seen"); } catch (e) {}
  var introDelay = !introSeen && scrollY < 40 && !calm ? 0.55 : 0;
  var introTime = introDelay ? 2.6 : 1.2;

  /* ---------- frame ---------- */
  var start = performance.now(), last = 0, raf = 0, lastScroll = scrollY, vel = 0;
  var slow = 0, sampled = 0, measureTick = 0;
  gl.clearColor(0.0047, 0.0071, 0.0196, 1);

  function frame(now) {
    raf = 0;
    if (document.hidden) return;
    var dt = last ? Math.min(0.1, (now - last) / 1000) : 1 / 60;
    if (last && quality > 0.5 && sampled < 240) {
      sampled++;
      if (dt > 0.034) slow++;
      if (sampled > 60 && slow / sampled > 0.5) {
        quality = 0.5;
        drawCount = Math.floor(COUNT * 0.55);
        resize();
      }
    }
    last = now;
    var t = (now - start) / 1000;
    var intro = Math.min(1, Math.max(0, (t - introDelay) / introTime));
    var introE = 1 - Math.pow(1 - intro, 4);

    if ((measureTick++ & 1) === 0) measure();
    var ease = 1 - Math.pow(0.955, dt * 60);
    for (var i = 0; i < FORMATIONS; i++) curW[i] += (tgtW[i] - curW[i]) * ease;
    look.neb += (tgt.neb - look.neb) * ease;
    look.bright += (tgt.bright - look.bright) * ease;
    look.chroma += (tgt.chroma - look.chroma) * ease;
    look.scale += (tgt.scale - look.scale) * ease;
    for (var c = 0; c < 3; c++) {
      look.ta[c] += (tgt.ta[c] - look.ta[c]) * ease;
      look.tb[c] += (tgt.tb[c] - look.tb[c]) * ease;
    }

    var sy = scrollY, dv = (sy - lastScroll) / innerHeight;
    lastScroll = sy;
    vel += ((calm ? 0 : dv) - vel) * 0.2;
    if (mouse.touchUntil && now > mouse.touchUntil) { mouse.thover = 0; mouse.touchUntil = 0; }
    mouse.x += (mouse.tx - mouse.x) * 0.14;
    mouse.y += (mouse.ty - mouse.y) * 0.14;
    mouse.hover += (mouse.thover - mouse.hover) * 0.06;
    mouse.tiltX += (mouse.tx * mouse.hover - mouse.tiltX) * 0.04;
    mouse.tiltY += (mouse.ty * mouse.hover - mouse.tiltY) * 0.04;
    for (var p = 0; p < 4; p++) if (pulses[p][2] < 1) pulses[p][2] = Math.min(1, pulses[p][2] + dt * 0.85);
    if (nebPulse[2] < 1) nebPulse[2] = Math.min(1, nebPulse[2] + dt * 0.85);
    var scrollUnits = sy / innerHeight;

    // nebula
    gl.disable(gl.BLEND);
    gl.bindBuffer(gl.ARRAY_BUFFER, quad);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    var nebAmount = look.neb * Math.min(1, introE * 1.15);
    if (nebAmount > 0.02) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.viewport(0, 0, NW, NH);
      gl.useProgram(neb.prog);
      gl.uniform2f(neb.u.u_res, NW, NH);
      gl.uniform1f(neb.u.u_time, t);
      gl.uniform1f(neb.u.u_neb, nebAmount);
      gl.uniform1f(neb.u.u_hover, mouse.hover);
      gl.uniform1f(neb.u.u_scroll, scrollUnits);
      gl.uniform2f(neb.u.u_mouse, mouse.x, mouse.y);
      gl.uniform3fv(neb.u.u_ta, look.ta);
      gl.uniform3fv(neb.u.u_tb, look.tb);
      gl.uniform3fv(neb.u.u_pulse, nebPulse);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.viewport(0, 0, W, H);
      gl.useProgram(blit.prog);
      gl.uniform2f(blit.u.u_res, W, H);
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    } else {
      gl.viewport(0, 0, W, H);
      gl.clear(gl.COLOR_BUFFER_BIT);
    }

    // dust
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE);
    gl.useProgram(stars.prog);
    var u = stars.u;
    gl.uniform1f(u.u_time, t);
    gl.uniform1f(u.u_aspect, W / H);
    gl.uniform1f(u.u_fit, Math.min(1, Math.max(0.55, W / H / 1.1)));
    gl.uniform1f(u.u_pix, dpr * 3.1 * Math.min(1.4, Math.max(0.7, innerHeight / 820)));
    gl.uniform1f(u.u_intro, introE);
    gl.uniform1f(u.u_scroll, scrollUnits);
    gl.uniform1f(u.u_vel, vel);
    gl.uniform1f(u.u_hover, mouse.hover);
    gl.uniform1f(u.u_bright, look.bright * Math.min(1, 0.25 + introE));
    gl.uniform1f(u.u_chroma, look.chroma);
    gl.uniform1f(u.u_scale, look.scale);
    gl.uniform1fv(u.u_w, curW);
    gl.uniform2f(u.u_mouse, mouse.x, mouse.y);
    gl.uniform2f(u.u_tilt, mouse.tiltX, mouse.tiltY);
    gl.uniform3fv(u.u_pulse, [].concat(pulses[0], pulses[1], pulses[2], pulses[3]));
    attribs.forEach(function (a) {
      gl.bindBuffer(gl.ARRAY_BUFFER, a.buf);
      gl.enableVertexAttribArray(a.loc);
      gl.vertexAttribPointer(a.loc, a.size, gl.FLOAT, false, 0, 0);
    });
    gl.drawArrays(gl.POINTS, 0, drawCount);
    attribs.forEach(function (a) { if (a.loc !== 0) gl.disableVertexAttribArray(a.loc); });

    if (!canvas.classList.contains("is-live")) canvas.classList.add("is-live");
    raf = requestAnimationFrame(frame);
  }
  function wake() {
    last = 0;
    if (!raf && !document.hidden) raf = requestAnimationFrame(frame);
  }
  document.addEventListener("visibilitychange", wake);
  canvas.addEventListener("webglcontextlost", function (e) {
    e.preventDefault();
    cancelAnimationFrame(raf);
    canvas.remove();
    root.classList.remove("fx-space-on");
    window.__fxSpace = false;
  });
  measure();
  for (var w0 = 0; w0 < FORMATIONS; w0++) curW[w0] = tgtW[w0];
  look.neb = tgt.neb; look.bright = tgt.bright; look.chroma = tgt.chroma; look.scale = tgt.scale;
  look.ta = tgt.ta.slice(); look.tb = tgt.tb.slice();
  wake();
})();
