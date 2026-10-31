import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const sourcePath = resolve(process.argv[2] || "web/landing/promo.html");
const copyPath = resolve(process.argv[3] || "artifacts/website_copy/landing_page_chinese_copy.txt");
const shouldWrite = process.argv.includes("--write");

let source = await readFile(sourcePath, "utf8");
const copy = await readFile(copyPath, "utf8");

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

function encodeText(value) {
	return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
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

function collectVisibleEntries(html) {
	const masked = html
		.replace(/<style\b[\s\S]*?<\/style>/gi, preserveLines)
		.replace(/<script\b[\s\S]*?<\/script>/gi, preserveLines)
		.replace(/<!--[\s\S]*?-->/g, preserveLines);
	const entries = [];
	const titleMatch = html.match(/<title>([\s\S]*?)<\/title>/i);
	if (titleMatch) {
		const start = titleMatch.index + titleMatch[0].indexOf(titleMatch[1]);
		entries.push({ start, end: start + titleMatch[1].length, section: "PAGE", language: "TEXT", text: decodeEntities(titleMatch[1]).trim(), duplicate: true });
	}
	const descriptionMatch = html.match(/<meta\s+name="description"\s+content="([^"]*)"/i);
	if (descriptionMatch) {
		const start = descriptionMatch.index + descriptionMatch[0].indexOf(descriptionMatch[1]);
		entries.push({ start, end: start + descriptionMatch[1].length, section: "PAGE", language: "EN", text: decodeEntities(descriptionMatch[1]).trim() });
	}

	const stack = [{ tag: "root", section: "PAGE", language: "TEXT", hidden: false }];
	const tokenPattern = /<[^>]+>|[^<]+/g;
	for (const match of masked.matchAll(tokenPattern)) {
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
			if (!/\/$/.test(token.slice(0, -1)) && !["area", "base", "br", "hr", "img", "input", "link", "meta", "source", "wbr"].includes(tag)) stack.push(node);
			continue;
		}
		const node = stack.at(-1);
		if (node.hidden) continue;
		const normalized = decodeEntities(token).replace(/\s+/g, " ").trim();
		if (!normalized || !(/[\p{L}\p{N}]/u.test(normalized))) continue;
		entries.push({ start: match.index, end: match.index + token.length, section: node.section, language: node.language, text: normalized, raw: token });
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
	return [...grouped.values()].flat();
}

function readEditedEntries(text) {
	const lines = text.replace(/\r\n/g, "\n").split("\n");
	const values = new Map();
	let active = null;
	let buffer = [];
	const flush = () => {
		if (!active) return;
		values.set(active, buffer.join("\n").trim());
	};
	for (const line of lines) {
		const id = line.match(/^\s*\[(ZH-\d+)\]/);
		if (id) {
			flush();
			active = id[1];
			buffer = [];
			continue;
		}
		if (active && /^\s*=+\s*$/.test(line)) {
			flush();
			active = null;
			buffer = [];
			continue;
		}
		if (active) buffer.push(line);
	}
	flush();
	return values;
}

const edited = readEditedEntries(copy);
const visibleEntries = collectVisibleEntries(source).filter(entry => entry.language !== "EN");
const highestEditedId = Math.max(...[...edited.keys()].map(id => Number.parseInt(id.slice(3), 10)));
if (visibleEntries.length < 50) throw new Error(`Landing-page extraction is unexpectedly small: ${visibleEntries.length}`);
if (highestEditedId > visibleEntries.length) {
	throw new Error(`TXT reaches ZH-${highestEditedId}, but the current source has only ${visibleEntries.length} entries. Export a fresh TXT before importing again.`);
}
const replacements = [];
for (let index = 0; index < visibleEntries.length; index += 1) {
	const entry = visibleEntries[index];
	const id = `ZH-${String(index + 1).padStart(3, "0")}`;
	const desired = edited.has(id) ? edited.get(id) : "";
	if (desired === entry.text) continue;
	const raw = source.slice(entry.start, entry.end);
	const leading = raw.match(/^\s*/)?.[0] || "";
	const trailing = raw.match(/\s*$/)?.[0] || "";
	replacements.push({ id, start: entry.start, end: entry.end, before: entry.text, after: desired, value: `${leading}${encodeText(desired)}${trailing}` });
}

for (const replacement of replacements.sort((a, b) => b.start - a.start)) {
	source = `${source.slice(0, replacement.start)}${replacement.value}${source.slice(replacement.end)}`;
}

console.log(`Source entries: ${visibleEntries.length}`);
console.log(`Edited TXT ids: ${edited.size}`);
console.log(`Changed source nodes: ${replacements.length}`);
for (const row of replacements) console.log(`${row.id}: ${JSON.stringify(row.before)} -> ${JSON.stringify(row.after)}`);

if (shouldWrite) {
	await writeFile(sourcePath, source, "utf8");
	console.log(`Updated ${sourcePath}`);
} else {
	console.log("Dry run only. Pass --write to update the source file.");
}
