import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { extname, join, relative, resolve } from "node:path";

const sourceRoot = resolve(process.argv[2] || "web/landing");
const outputPath = resolve(process.argv[3] || "artifacts/website_copy/website_copy_review.txt");
const supported = new Set([".html", ".js", ".json"]);

async function filesBelow(directory) {
	const rows = await readdir(directory, { withFileTypes: true });
	const files = [];
	for (const row of rows) {
		const path = join(directory, row.name);
		if (row.isDirectory()) files.push(...await filesBelow(path));
		else if (supported.has(extname(row.name).toLowerCase())) files.push(path);
	}
	return files.sort();
}

function lineAt(source, index) {
	return source.slice(0, index).split("\n").length;
}

function decodeEntities(value) {
	return value
		.replace(/&nbsp;/gi, " ")
		.replace(/&amp;/gi, "&")
		.replace(/&quot;/gi, '"')
		.replace(/&#39;|&apos;/gi, "'")
		.replace(/&lt;/gi, "<")
		.replace(/&gt;/gi, ">");
}

function decodeLiteral(raw) {
	const quote = raw[0];
	const body = raw.slice(1, -1);
	if (quote === '"') {
		try { return JSON.parse(raw); } catch (_) {}
	}
	return body
		.replace(/\\u\{([0-9a-f]+)\}/gi, (_match, code) => String.fromCodePoint(Number.parseInt(code, 16)))
		.replace(/\\u([0-9a-f]{4})/gi, (_match, code) => String.fromCharCode(Number.parseInt(code, 16)))
		.replace(/\\x([0-9a-f]{2})/gi, (_match, code) => String.fromCharCode(Number.parseInt(code, 16)))
		.replace(/\\n/g, "\n")
		.replace(/\\r/g, "")
		.replace(/\\t/g, "\t")
		.replace(/\\([\\'"`])/g, "$1");
}

function cleanCopy(value) {
	return decodeEntities(String(value || ""))
		.replace(/<script[\s\S]*?<\/script>/gi, " ")
		.replace(/<style[\s\S]*?<\/style>/gi, " ")
		.replace(/<[^>]+>/g, " ")
		.replace(/\$\{[^}]+\}/g, "{…}")
		.replace(/\s+/g, " ")
		.trim();
}

function looksLikeCopy(value, allowShort = false) {
	if (!value || value.length > 800) return false;
	if (/^(?:https?:|\/|\.\/|\.\.\/|#[a-z0-9_-]+$)/i.test(value)) return false;
	if (/^[a-z0-9_.:/-]+$/i.test(value) && !allowShort) return false;
	if (/^[\[\]{}();,.?*+^$|\\-]+$/.test(value)) return false;
	return /[\u3400-\u9fff]/.test(value) || /[A-Za-z]{2}/.test(value);
}

function extractHtml(source) {
	const entries = [];
	const attributePattern = /\b(?:content|aria-label|alt|placeholder|title)=("[^"]*"|'[^']*')/gi;
	for (const match of source.matchAll(attributePattern)) {
		const text = cleanCopy(decodeLiteral(match[1]));
		if (looksLikeCopy(text, true)) entries.push({ line: lineAt(source, match.index), text });
	}
	const visible = source.replace(/<script[\s\S]*?<\/script>/gi, "").replace(/<style[\s\S]*?<\/style>/gi, "");
	const textPattern = />([^<]+)</g;
	for (const match of visible.matchAll(textPattern)) {
		const text = cleanCopy(match[1]);
		if (looksLikeCopy(text, true)) entries.push({ line: lineAt(source, match.index), text });
	}
	return entries;
}

const literalSource = String.raw`(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\x60(?:\\.|[^\x60\\])*\x60)`;
const bilingualPattern = new RegExp(String.raw`\bt\(\s*(${literalSource})\s*,\s*(${literalSource})\s*\)`, "gs");
const literalPattern = new RegExp(literalSource, "gs");

function extractJavaScript(source) {
	const entries = [];
	const pairedRanges = [];
	for (const match of source.matchAll(bilingualPattern)) {
		const en = cleanCopy(decodeLiteral(match[1]));
		const zh = cleanCopy(decodeLiteral(match[2]));
		if (looksLikeCopy(en, true) || looksLikeCopy(zh, true)) {
			entries.push({ line: lineAt(source, match.index), en, zh });
			pairedRanges.push([match.index, match.index + match[0].length]);
		}
	}
	for (const match of source.matchAll(literalPattern)) {
		if (pairedRanges.some(([start, end]) => match.index >= start && match.index < end)) continue;
		const text = cleanCopy(decodeLiteral(match[0]));
		if (looksLikeCopy(text) && (/\s/.test(text) || /[\u3400-\u9fff]/.test(text))) {
			entries.push({ line: lineAt(source, match.index), text });
		}
	}
	return entries;
}

function extractJsonValue(value, path = "$") {
	const entries = [];
	if (typeof value === "string") {
		const text = cleanCopy(value);
		if (looksLikeCopy(text, true)) entries.push({ path, text });
	} else if (Array.isArray(value)) {
		value.forEach((item, index) => entries.push(...extractJsonValue(item, `${path}[${index}]`)));
	} else if (value && typeof value === "object") {
		for (const [key, item] of Object.entries(value)) entries.push(...extractJsonValue(item, `${path}.${key}`));
	}
	return entries;
}

const blocks = [];
let copyId = 0;
for (const file of await filesBelow(sourceRoot)) {
	const source = await readFile(file, "utf8");
	const extension = extname(file).toLowerCase();
	let entries = [];
	if (extension === ".html") entries = extractHtml(source);
	else if (extension === ".js") entries = extractJavaScript(source);
	else {
		try { entries = extractJsonValue(JSON.parse(source)); } catch (_) {}
	}
	const seen = new Set();
	entries = entries.filter(entry => {
		const key = `${entry.en || ""}\u0000${entry.zh || ""}\u0000${entry.text || ""}`;
		if (seen.has(key)) return false;
		seen.add(key);
		return true;
	});
	if (!entries.length) continue;
	blocks.push(`\n\n================================================================\nSOURCE: ${relative(sourceRoot, file).replace(/\\/g, "/")}\n================================================================`);
	for (const entry of entries) {
		copyId += 1;
		const location = entry.path || `line ${entry.line}`;
		blocks.push(`\n[COPY-${String(copyId).padStart(4, "0")}] ${location}`);
		if (entry.en !== undefined) blocks.push(`EN: ${entry.en}\nZH: ${entry.zh}`);
		else blocks.push(`TEXT: ${entry.text}`);
	}
}

const header = `PIXEL OBSERVATORY - WEBSITE COPY REVIEW\n像素观测站：网站文案修改稿\nGenerated from: web/landing\n\n使用说明\n- 这份 TXT 用于集中修改显得生硬、模板化或“AI 味”较重的网站文案。\n- 请直接修改 EN:、ZH: 或 TEXT: 后面的文字。\n- 请保留 COPY 编号，以及 {…}、%s、数字等运行时占位内容。\n- 修改完成后把 TXT 交回来，我可以按 COPY 编号同步回真正的网站源码。\n- TXT 是审阅稿；单独修改它不会自动改变线上网站。\n\n收录范围\n- 官网首页与宣传页面\n- 游戏加载页与注册用户侧栏\n- 账号、反馈、信箱、私信、社区、观测分享与管理界面\n- 版本更新公告\n\nPurpose\n- This TXT is a review document for rewriting website copy that feels too generic or AI-written.\n- Edit the text after EN:, ZH:, or TEXT:. Keep COPY ids and placeholders such as {…}, %s, and numbers intact.\n- Send the edited TXT back and the changes can be applied to the real source files.\n- Source files remain authoritative; editing this TXT alone does not change the live website.\n\nExtracted entries: ${copyId}`;

await mkdir(resolve(outputPath, ".."), { recursive: true });
await writeFile(outputPath, `${header}${blocks.join("\n")}\n`, "utf8");
console.log(`Wrote ${copyId} website-copy entries to ${outputPath}`);
