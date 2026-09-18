import { mkdir, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const targetUrl = process.argv[2] || "http://127.0.0.1:8765/promo.html?lang=zh";
const outputDir = resolve(process.argv[3] || "output/playwright/landing-copy-layout");
const modulePath = process.env.PLAYWRIGHT_MODULE;
const playwright = modulePath ? await import(pathToFileURL(modulePath).href) : await import("playwright");
const { chromium } = playwright;

await mkdir(outputDir, { recursive: true });
const browser = await chromium.launch({ headless: true });
const reports = [];
for (const scenario of [
	{ name: "desktop", viewport: { width: 1440, height: 1000 } },
	{ name: "mobile", viewport: { width: 390, height: 844 } },
]) {
	const page = await browser.newPage({ viewport: scenario.viewport, deviceScaleFactor: 1 });
	await page.addInitScript(() => localStorage.setItem("so-lang", "zh"));
	const errors = [];
	page.on("pageerror", error => errors.push(`pageerror: ${error}`));
	page.on("console", message => { if (message.type() === "error") errors.push(`console: ${message.text()}`); });
	await page.goto(targetUrl, { waitUntil: "networkidle" });
	await page.waitForTimeout(1200);
	await page.screenshot({ path: resolve(outputDir, `${scenario.name}-top.png`), fullPage: false });
	for (const section of ["eye", "optics", "reflector", "difference"]) {
		const locator = page.locator(`#${section}`);
		await locator.scrollIntoViewIfNeeded();
		await page.waitForTimeout(450);
		await locator.screenshot({ path: resolve(outputDir, `${scenario.name}-${section}.png`) });
	}
	const layout = await page.evaluate(() => {
		const visibleChinese = [...document.querySelectorAll(".zh")].filter(element => {
			const style = getComputedStyle(element);
			const rect = element.getBoundingClientRect();
			return style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
		});
		const overflow = visibleChinese.filter(element => element.scrollWidth > element.clientWidth + 2 || element.scrollHeight > element.clientHeight + 2).map(element => ({
			tag: element.tagName,
			className: element.className,
			text: element.textContent.trim().slice(0, 160),
			client: [element.clientWidth, element.clientHeight],
			scroll: [element.scrollWidth, element.scrollHeight],
		}));
		return {
			lang: document.documentElement.dataset.lang,
			visibleChinese: visibleChinese.length,
			overflow,
			heroText: document.querySelector(".hero-inner")?.innerText || "",
			eyeText: document.querySelector("#eye")?.innerText.slice(0, 800) || "",
		};
	});
	reports.push({ scenario: scenario.name, layout, errors });
	await page.close();
}
await browser.close();
await writeFile(resolve(outputDir, "report.json"), JSON.stringify(reports, null, 2), "utf8");
console.log(JSON.stringify(reports, null, 2));
