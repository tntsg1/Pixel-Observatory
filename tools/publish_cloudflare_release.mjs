import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";

const webDir = resolve(process.argv[2] || "build/web");
const publicDir = resolve(process.argv[3] || "build/cloudflare-public");
const html = await readFile(resolve(webDir, "game/index.html"), "utf8");
const build = html.match(/data-pixel-observatory-build="([a-zA-Z0-9._-]+)"/)?.[1];
if (!build) throw new Error("The game shell does not contain a safe build id.");

function run(command, args) {
	let executable = command;
	let commandArgs = args;
	if (process.platform === "win32" && command === "npx") {
		executable = process.execPath;
		commandArgs = [join(dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js"), ...args];
	}
	const result = spawnSync(executable, commandArgs, { stdio: "inherit", shell: false });
	if (result.error) throw result.error;
	if (result.status !== 0) process.exit(result.status ?? 1);
}

for (const [name, type] of [["index.pck", "application/octet-stream"], ["index.wasm", "application/wasm"]]) {
	run("npx", [
		"wrangler", "r2", "object", "put",
		`pixel-observatory-game-assets/runtime/${build}/${name}`,
		"--file", resolve(webDir, "game", "runtime", build, name),
		"--content-type", type,
		"--cache-control", "public, max-age=31536000, immutable",
		"--remote",
	]);
}

const packRoot = resolve(webDir, "game", "resource-packs");
const packManifest = JSON.parse(await readFile(resolve(packRoot, "manifest.json"), "utf8"));
for (const pack of packManifest.packs || []) {
	const source = resolve(packRoot, pack.id, `${pack.version}.pck`);
	run("npx", [
		"wrangler", "r2", "object", "put",
		`pixel-observatory-game-assets/resource-packs/${pack.id}/${pack.version}.pck`,
		"--file", source,
		"--content-type", "application/octet-stream",
		"--cache-control", "public, max-age=31536000, immutable",
		"--remote",
	]);
}

run("npx", ["wrangler", "deploy", "--assets", publicDir]);
console.log(`Published immutable browser runtime ${build} with ${packManifest.packs?.length || 0} independent resource packs.`);
