import assert from "node:assert/strict";
import fs from "node:fs";

const accountSource = fs.readFileSync(new URL("../web/landing/account.js", import.meta.url), "utf8");
const socialSource = fs.readFileSync(new URL("../web/landing/social.js", import.meta.url), "utf8");
const landingSource = fs.readFileSync(new URL("../web/landing/promo.html", import.meta.url), "utf8");
const loaderPatchSource = fs.readFileSync(new URL("./patch_web_loader.mjs", import.meta.url), "utf8");

assert.ok(
  !/modal\.onclick\s*=\s*event\s*=>\s*\{\s*if\s*\(\s*event\.target\s*===\s*modal\s*\)\s*close/.test(accountSource),
  "account and registration dialogs ignore backdrop clicks",
);
assert.ok(
  !/modal\.onclick\s*=\s*event\s*=>\s*\{\s*if\s*\(\s*event\.target\s*===\s*modal\s*\)\s*close/.test(socialSource),
  "community dialog ignores backdrop clicks",
);
assert.ok(
  accountSource.includes('modal.querySelector(".po-close").onclick=()=>close(modal);'),
  "account dialog retains an explicit close button",
);
assert.ok(
  accountSource.includes('if(event.key==="Escape")'),
  "account dialog retains Escape dismissal",
);
assert.ok(
  socialSource.includes('modal.querySelector(".social-close").onclick = close;'),
  "community dialog retains an explicit close button",
);
assert.ok(
  socialSource.includes('if (event.key === "Escape" && !modal.hidden) close();'),
  "community dialog retains Escape dismissal",
);

assert.ok(
  landingSource.includes('account.js?v=20260729-modal-dismissal'),
  "landing page cache-busts the corrected account behavior",
);
assert.ok(
  landingSource.includes('social.js?v=20260729-modal-dismissal'),
  "landing page cache-busts the corrected community behavior",
);
assert.ok(
  loaderPatchSource.includes('const SHELL_VERSION = "20260729-game-shell-v3";'),
  "game shell cache-busts the corrected account behavior",
);

console.log("PASS web modal dismissal: backdrop clicks stay inert and explicit close paths remain");
