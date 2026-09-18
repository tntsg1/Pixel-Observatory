import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const sourcePath = resolve(process.argv[2] || "web/landing/promo.html");
const outputPath = resolve(process.argv[3] || "artifacts/website_copy/landing_page_copy_review.txt");
const chineseOutputPath = resolve(process.argv[4] || "artifacts/website_copy/landing_page_chinese_copy.txt");
const source = await readFile(sourcePath, "utf8");

const sectionNames = new Map([
	["PAGE", "页面基础信息"],
	["NAV", "顶部导航"],
	["eye", "Chapter 01 · 第一次观测 / Maya 引导"],
	["assemble", "组装望远镜"],
	["optics", "理解光学"],
	["reflector", "反射式望远镜"],
	["observe", "开始观测"],
	["sky-live", "动态天空"],
	["path", "成长路线"],
	["principles", "设计原则 / 核心体验"],
	["difference", "产品差异"],
	["story", "Maya 的故事"],
	["features", "功能总览"],
	["join", "结尾行动区"],
	["FOOTER", "页脚"],
]);

function preserveLines(match) {
	return match.replace(/[^\n]/g, " ");
}

function decodeEntities(value) {
	return value
		.replace(/&#x([0-9a-f]+);/gi, (_match, code) => String.fromCodePoint(Number.parseInt(code, 16)))
		.replace(/&#([0-9]+);/g, (_match, code) => String.fromCodePoint(Number.parseInt(code, 10)))
		.replace(/&nbsp;/gi, " ")
		.replace(/&amp;/gi, "&")
		.replace(/&quot;/gi, '"')
		.replace(/&#39;|&apos;/gi, "'")
		.replace(/&lt;/gi, "<")
		.replace(/&gt;/gi, ">");
}

function lineAt(index) {
	return source.slice(0, index).split("\n").length;
}

function attr(tag, name) {
	const match = tag.match(new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)')`, "i"));
	return match ? (match[1] ?? match[2] ?? "") : "";
}

function languageFrom(className, inherited = "TEXT") {
	const classes = className.split(/\s+/);
	if (classes.includes("en")) return "EN";
	if (classes.includes("zh")) return "ZH";
	return inherited;
}

let visible = source
	.replace(/<style\b[\s\S]*?<\/style>/gi, preserveLines)
	.replace(/<script\b[\s\S]*?<\/script>/gi, preserveLines)
	.replace(/<!--[\s\S]*?-->/g, preserveLines);

const titleMatch = source.match(/<title>([\s\S]*?)<\/title>/i);
const descriptionMatch = source.match(/<meta\s+name="description"\s+content="([^"]*)"/i);
const entries = [];
if (titleMatch) entries.push({ section: "PAGE", line: lineAt(titleMatch.index), language: "TEXT", text: decodeEntities(titleMatch[1]).trim() });
if (descriptionMatch) entries.push({ section: "PAGE", line: lineAt(descriptionMatch.index), language: "EN", text: decodeEntities(descriptionMatch[1]).trim() });

const stack = [{ tag: "root", section: "PAGE", language: "TEXT", hidden: false }];
const tokenPattern = /<[^>]+>|[^<]+/g;
for (const match of visible.matchAll(tokenPattern)) {
	const token = match[0];
	if (token.startsWith("</")) {
		if (stack.length > 1) stack.pop();
		continue;
	}
	if (token.startsWith("<")) {
		if (/^<!/i.test(token)) continue;
		const tagMatch = token.match(/^<\s*([a-z0-9-]+)/i);
		if (!tagMatch) continue;
		const tag = tagMatch[1].toLowerCase();
		const parent = stack.at(-1);
		const className = attr(token, "class");
		let section = parent.section;
		if (tag === "nav" && className.split(/\s+/).includes("gnav")) section = "NAV";
		if (tag === "section" && attr(token, "id")) section = attr(token, "id");
		if (tag === "footer") section = "FOOTER";
		const node = {
			tag,
			section,
			language: languageFrom(className, parent.language),
			hidden: parent.hidden || /\baria-hidden\s*=\s*["']true["']/i.test(token),
		};
		if (!/\/$/.test(token.slice(0, -1)) && !["area", "base", "br", "hr", "img", "input", "link", "meta", "source", "wbr"].includes(tag)) {
			stack.push(node);
		}
		continue;
	}

	const node = stack.at(-1);
	if (node.hidden) continue;
	const text = decodeEntities(token).replace(/\s+/g, " ").trim();
	if (!text || !(/[\p{L}\p{N}]/u.test(text))) continue;
	entries.push({ section: node.section, line: lineAt(match.index), language: node.language, text });
}

const deduped = entries.filter((entry, index) => {
	const previous = entries[index - 1];
	return !previous || entry.section !== previous.section || entry.language !== previous.language || entry.text !== previous.text;
});

const grouped = new Map();
for (const entry of deduped) {
	if (!grouped.has(entry.section)) grouped.set(entry.section, []);
	grouped.get(entry.section).push(entry);
}

const blocks = [];
let itemId = 0;
for (const [section, sectionEntries] of grouped) {
	blocks.push(`\n\n================================================================\n${sectionNames.get(section) || section}\nSOURCE SECTION: ${section}\n================================================================`);
	for (let index = 0; index < sectionEntries.length; index += 1) {
		const entry = sectionEntries[index];
		const next = sectionEntries[index + 1];
		itemId += 1;
		blocks.push(`\n[LANDING-${String(itemId).padStart(3, "0")}] source line ${entry.line}`);
		if (entry.language === "EN" && next?.language === "ZH") {
			blocks.push(`EN: ${entry.text}\nZH: ${next.text}`);
			index += 1;
		} else {
			blocks.push(`${entry.language}: ${entry.text}`);
		}
	}
}

const header = `PIXEL OBSERVATORY · 官网首页文案修改稿

这份文件只收录 pixelobservatorygame.com 首页上能看到的宣传文案。
不包含游戏内文案、账号弹窗、社区、私信、后台、公告或程序提示。

修改方法
1. 直接改 EN:、ZH: 或 TEXT: 后面的文字。
2. 请保留 [LANDING-xxx] 编号，方便把修改准确同步回网页。
3. Maya、Starlight Observatory、数值和专业术语也可以改，但请确认是有意修改。
4. 修改完成后把这份 TXT 交还给我即可。

来源：web/landing/promo.html
文案条目：${itemId}`;

const chineseBlocks = [];
let chineseId = 0;
for (const [section, sectionEntries] of grouped) {
	const chineseEntries = sectionEntries.filter(entry => entry.language !== "EN");
	if (!chineseEntries.length) continue;
	chineseBlocks.push(`\n\n================================================================\n${sectionNames.get(section) || section}\n================================================================`);
	for (const entry of chineseEntries) {
		chineseId += 1;
		chineseBlocks.push(`\n[ZH-${String(chineseId).padStart(3, "0")}] source line ${entry.line}\n${entry.text}`);
	}
}

const chineseHeader = `PIXEL OBSERVATORY · 官网首页中文文案

这就是 pixelobservatorygame.com 首页中文模式中实际展示的文字，顺序与网页从上到下基本一致。
不包含游戏内、账号弹窗、社区、后台、公告或程序提示。

修改方法
1. 直接修改每个 [ZH-xxx] 编号下面的文字。
2. 保留 [ZH-xxx] 编号，方便修改后准确同步回网页。
3. 英文品牌名、Maya、数值和按钮符号属于中文页面中同样可见的固定文字，因此也保留在这里。
4. 修改完成后把本 TXT 交还给我即可。

来源：web/landing/promo.html
中文页面可见条目：${chineseId}`;

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${header}${blocks.join("\n")}\n`, "utf8");
await writeFile(chineseOutputPath, `${chineseHeader}${chineseBlocks.join("\n")}\n`, "utf8");
console.log(`Wrote ${itemId} bilingual landing-page entries to ${outputPath}`);
console.log(`Wrote ${chineseId} Chinese landing-page entries to ${chineseOutputPath}`);
