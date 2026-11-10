import { spawnSync } from "node:child_process";
const cli = "C:/Users/tntsg/AppData/Local/npm-cache/_npx/31e32ef8478fbf80/node_modules/@playwright/cli/playwright-cli.js";
function run(args) {
  const result = spawnSync(process.execPath, [cli, "-s=observatory-corner-removal", ...args], { cwd: "E:/godot/po-l10-live-hotfix", encoding: "utf8", timeout: 60000 });
  if (result.status !== 0 || /### Error/.test(result.stdout || "")) throw new Error(result.stdout + result.stderr);
  console.log((result.stdout || "").slice(-2200));
}
try {
  run(["open", "https://pixelobservatorygame.com/", "--config", "G:/CODE/stellar-web/output/playwright/domain-migration/cli.config.json"]);
  run(["snapshot"]);
  run(["run-code", `async (page) => {
    await page.setViewportSize({ width: 2048, height: 826 });
    await page.waitForTimeout(2600);
    if (await page.locator('.corner-newgame').count()) throw new Error('Corner badge is still present');
    await page.screenshot({ path: 'E:/godot/po-l10-live-hotfix/output/playwright/corner-removed-desktop.png' });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(600);
    if (await page.locator('.corner-newgame').count()) throw new Error('Mobile corner badge is still present');
    await page.screenshot({ path: 'E:/godot/po-l10-live-hotfix/output/playwright/corner-removed-mobile.png' });
    return { url: page.url(), badgeCount: 0, title: await page.title() };
  }`]);
} finally { run(["close"]); }
