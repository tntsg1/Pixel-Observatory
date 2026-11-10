const {chromium}=require('C:/Users/tntsg/AppData/Local/npm-cache/_npx/31e32ef8478fbf80/node_modules/playwright');
const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true,args:['--enable-unsafe-swiftshader']});
 try {
 const context=await browser.newContext({viewport:{width:1280,height:800}});
 const p=await context.newPage(), errors=[],logs=[],routes=[],unauthorized=[];
 p.on("response",r=>{if(r.status()===401)unauthorized.push({url:r.url(),status:r.status()})});
 p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{const t=m.text();logs.push(t);if(m.type()==='error'&&!/favicon|404|403|ERR_ABORTED/.test(t))errors.push(t)});
 await p.addInitScript(()=>{window.__contexts=[];window.addEventListener('observatory:game-context',e=>window.__contexts.push(e.detail))});
 for(const path of ['/stellar','/stellar/','/stellar/play/','/stellar/skyguard/','/stellar/game/v1/index.wasm','/stellar/api/save']){
  const r=await p.goto('https://pixelobservatorygame.com'+path,{waitUntil:'domcontentloaded',timeout:30000});
  routes.push({url:r.url(),status:r.status()});assert.equal(r.status(),404);assert.equal(r.headers()['location'],undefined);
 }
 for(const path of ['/','/play/','/stellar/']){
  const r=await p.goto('https://stellarascensiongame.com'+path,{waitUntil:'domcontentloaded',timeout:30000});routes.push({url:r.url(),status:r.status()});assert.equal(r.status(),200);
 }
 const homepage=await p.goto('https://pixelobservatorygame.com/',{waitUntil:'domcontentloaded'});assert.equal(homepage.status(),200);
 const homepageHash=crypto.createHash('sha256').update(await homepage.body()).digest('hex');
 const expected=crypto.createHash('sha256').update(fs.readFileSync('artifacts/player-blockers-release-20261009/live-landing/promo.html')).digest('hex');fs.writeFileSync('artifacts/player-blockers-release-20261009/live-home.html',await homepage.body());
 const normalize=text=>text.replace(/\r\n/g,'\n').replace(/<script\b[^>]*src="https:\/\/static\.cloudflareinsights\.com\/[^\"]*"[^>]*>\s*<\/script>\s*/g,'').trim();
 assert.equal(normalize(await homepage.text()),normalize(fs.readFileSync('artifacts/player-blockers-release-20261009/live-landing/promo.html','utf8')),'Homepage content preserved');
 const pck=await context.request.head('https://pixelobservatorygame.com/game/runtime/39eabc3b8b8d/index.pck');assert.equal(pck.status(),200);
 const md5=crypto.createHash('md5').update(fs.readFileSync('build/web/game/runtime/39eabc3b8b8d/index.pck')).digest('hex');assert.equal(pck.headers().etag.replaceAll('"',''),md5);
 errors.length=0;logs.length=0;
 const game=await p.goto('https://pixelobservatorygame.com/game/index.html?verify=39eabc3b8b8d',{waitUntil:'domcontentloaded',timeout:45000});assert.equal(game.status(),200);assert.ok((await game.text()).includes('runtime/39eabc3b8b8d/index.pck'));
 try {await p.waitForFunction(()=>{const n=document.querySelector('#status');return !n||getComputedStyle(n).display==='none'},null,{timeout:120000});} catch(e) {fs.writeFileSync('artifacts/player-blockers-release-20261009/browser-failure.json',JSON.stringify({errors,logs,status:await p.locator('#status').innerText(),contexts:await p.evaluate(()=>window.__contexts)},null,2));console.log('LOAD_FAILURE',JSON.stringify({errors,logs:logs.slice(-12)}));throw e;}
 await p.waitForFunction(()=>window.__contexts.length>0,null,{timeout:15000});
 console.log('Game loaded',JSON.stringify(await p.evaluate(()=>window.__contexts))); await p.screenshot({path:'artifacts/player-blockers-release-20261009/live-menu.png'});
 const gameContext=await p.evaluate(()=>window.__contexts);
 for (const response of unauthorized) assert.ok(new URL(response.url).pathname.startsWith('/api/'),'Guest 401 belongs to account API');
 const runtimeErrors=errors.filter(t=>!/^Failed to load resource: the server responded with a status of 401/.test(t));
 await p.mouse.click(640,370);
 await p.waitForFunction(()=>window.__contexts.some(c=>c.scene!=='menu'&&c.scene!=='unknown'),null,{timeout:20000});
 const afterNewGame=await p.evaluate(()=>window.__contexts);
 await p.screenshot({path:'artifacts/player-blockers-release-20261009/live-new-game.png'});
 const report={routes,homepageHash,pckMD5:md5,gameContext,afterNewGame,unauthorized,errors:runtimeErrors,logs};
 fs.writeFileSync('artifacts/player-blockers-release-20261009/browser.json',JSON.stringify(report,null,2));
 console.log(JSON.stringify({routes,gameContext,afterNewGame,unauthorized,errors:runtimeErrors,pckMD5:md5},null,2));assert.equal(runtimeErrors.length,0,'Game has no browser runtime errors');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});

