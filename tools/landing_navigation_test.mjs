import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const playwright = process.env.PLAYWRIGHT_MODULE
  ? await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE).href)
  : await import("playwright");
const browser = await playwright.chromium.launch({
  headless: true,
  ...(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : {}),
});
const url = process.argv[2] || "http://127.0.0.1:8765/promo.html?lang=zh";

for (const viewport of [{ width: 1440, height: 1000 }, { width: 1366, height: 900 }, { width: 1280, height: 900 }, { width: 1024, height: 768 }, { width: 420, height: 714 }, { width: 390, height: 844 }]) {
  const page = await browser.newPage({ viewport, reducedMotion: "reduce" });
  await page.addInitScript(() => localStorage.setItem("so-lang", "zh"));
  await page.goto(url, { waitUntil: "domcontentloaded" });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), viewport.width);
  const nav = page.locator("#gnav");
  assert.equal(await nav.evaluate(node => node.classList.contains("hide")), false);
  assert.equal(await nav.evaluate(node => node.inert), false);

  if (viewport.width < 1250) {
    const toggle = page.locator("#gnav-menu-toggle");
    await toggle.focus();
    await page.keyboard.press("Enter");
    assert.equal(await toggle.getAttribute("aria-expanded"), "true");
    await page.keyboard.press("Escape");
    assert.equal(await toggle.getAttribute("aria-expanded"), "false");
    await toggle.click();
  }
  await page.locator("#account-open").click();
  assert.equal(await page.locator("#po-account-modal").isVisible(), true);
  await page.locator("#po-account-modal .po-close").click();
  if (viewport.width < 1250) await page.locator("#gnav-menu-toggle").click();
  await page.locator("#langEn").click();
  assert.equal(await page.locator("html").getAttribute("data-lang"), "en");
  assert.equal(await page.locator("#account-label").innerText(), "Account");
  await page.locator("body").click({ position: { x: 5, y: 160 } });

  await page.evaluate(() => scrollTo(0, 900));
  await page.waitForTimeout(100);
  assert.equal(await nav.evaluate(node => node.classList.contains("hide") && node.inert), true);
  await page.evaluate(() => scrollTo(0, 600));
  await page.waitForTimeout(100);
  assert.equal(await nav.evaluate(node => node.classList.contains("hide") || node.inert), false);
  await page.evaluate(() => scrollTo(0, 0));
  await page.waitForTimeout(100);
  assert.equal(await nav.evaluate(node => node.classList.contains("hide")), false);

  await page.locator(".instrument-tab").nth(1).focus();
  await page.keyboard.press("ArrowRight");
  assert.equal(await page.locator(".instrument-tab").nth(2).getAttribute("aria-pressed"), "true");
  assert.equal(await page.locator("#principles .pr").nth(2).isVisible(), true);
  if (viewport.width <= 900) {
    await page.locator(".view-tabs button").nth(2).click();
    assert.equal(await page.locator(".obs-card").nth(2).isVisible(), true);
  }
  assert.match(await page.locator("#gnav .gnav-play").getAttribute("href"), /^game\/\?lang=en$/);
  await page.close();
}

const noScript = await browser.newPage({ viewport: { width: 420, height: 714 }, javaScriptEnabled: false });
await noScript.goto(url, { waitUntil: "domcontentloaded" });
assert.equal(await noScript.locator("#principles .pr:visible").count(), 4);
assert.equal(await noScript.locator(".obs-card:visible").count(), 3);
await noScript.close();

const touch = await browser.newPage({
  viewport: { width: 420, height: 714 },
  isMobile: true,
  hasTouch: true,
  reducedMotion: "reduce",
});
await touch.addInitScript(() => localStorage.setItem("so-lang", "zh"));
await touch.goto(url, { waitUntil: "domcontentloaded" });
await touch.locator("#gnav-menu-toggle").tap();
assert.equal(await touch.locator("#gnav-menu-toggle").getAttribute("aria-expanded"), "true");
await touch.locator("#account-open").tap();
assert.equal(await touch.locator("#po-account-modal").isVisible(), true);
await touch.locator("#po-account-modal .po-close").tap();
await touch.locator("#gnav-menu-toggle").tap();
await touch.locator("#langEn").tap();
assert.equal(await touch.locator("html").getAttribute("data-lang"), "en");
await touch.locator(".instrument-tab").nth(3).tap();
assert.equal(await touch.locator("#principles .pr").nth(3).isVisible(), true);
await touch.close();
await browser.close();
console.log("PASS landing navigation, scroll, language, comparison, and no-script content");
