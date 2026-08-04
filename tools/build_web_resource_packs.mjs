import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { basename, join, relative, resolve } from "node:path";

const godot = resolve(process.argv[2] || process.env.GODOT || "godot");
const outputDir = resolve(process.argv[3] || "build/web/.godot-export/resource-packs");
const projectDir = resolve(process.argv[4] || ".");

const retiredOrSourceOnly = new Set([
	"assets/audio/music/giant_telescope.mp3",
	"assets/audio/music/space_fast_theme.mp3",
	"assets/audio/ambient/fast_terminal_hum.ogg",
	"assets/reference/observatory_ai_mockup.png",
	"assets/reference/observatory_room_hall_4x3.png",
	"assets/reference/observatory_room_bg_1024.png",
	"assets/reference/observatory_room_hall_remote_desk_1024.png",
	"assets/reference/sky_observation_ui_bg_1024.png",
	"assets/reference/sky_view_mode_buttons_uniform.png",
	"assets/reference/sky_view_mode_buttons_uniform_250x76.png",
	"assets/assembly/newtonian_blueprint_reference.png",
	"assets/assembly/cassegrain_main_blueprint.png",
	"assets/assembly/cassegrain_tube_blueprint.png",
]);

const definitions = [
	{
		id: "audio",
		roots: ["assets/audio"],
		accept: path => !retiredOrSourceOnly.has(path),
	},
	{
		id: "astronomy-media",
		roots: [
			"assets/telescope_view",
			"assets/telescope_parts",
			"assets/assembly",
			"assets/reference",
			"assets/horizon/processed",
		],
		accept: path => !retiredOrSourceOnly.has(path),
	},
	{
		id: "star-catalog",
		files: ["data/deep_stars.json", "data/bright_stars.json"],
		accept: () => true,
	},
];

const resourceExtensions = new Set([
	".bmp", ".csv", ".glb", ".gltf", ".jpeg", ".jpg", ".json", ".mp3",
	".ogg", ".png", ".res", ".svg", ".tres", ".tscn", ".ttf", ".wav", ".webp",
]);

async function walk(root) {
	const absolute = join(projectDir, root);
	const rows = await readdir(absolute, { withFileTypes: true });
	const files = [];
	for (const row of rows) {
		const child = join(root, row.name).replace(/\\/g, "/");
		if (row.isDirectory()) files.push(...await walk(child));
		else files.push(child);
	}
	return files;
}

function isExportableResource(path) {
	if (path.endsWith(".import") || basename(path).startsWith(".")) return false;
	const extension = `.${path.split(".").pop()?.toLowerCase() || ""}`;
	return resourceExtensions.has(extension);
}

function runGodot(target, files) {
	const result = spawnSync(godot, [
		"--headless", "--path", projectDir,
		"--script", "res://tools/build_resource_pack.gd", "--", target,
		...files.map(path => `res://${path}`),
	], { cwd: projectDir, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
	if (result.stdout) process.stdout.write(result.stdout);
	if (result.stderr) process.stderr.write(result.stderr);
	if (result.error) throw result.error;
	if (result.status !== 0) throw new Error(`Godot failed to build ${target} (${result.status}).`);
}

async function sha256(path) {
	const bytes = await readFile(path);
	return createHash("sha256").update(bytes).digest("hex");
}

await mkdir(outputDir, { recursive: true });
const manifest = { schema: 1, packs: [] };

	for (const definition of definitions) {
		const discovered = definition.files
			? definition.files.slice()
			: (await Promise.all(definition.roots.map(walk))).flat();
		const files = [...new Set(discovered)]
			.filter(isExportableResource)
			.filter(definition.accept)
			.sort();
		if (!files.length) throw new Error(`Resource pack ${definition.id} has no input files.`);

		const draftPath = join(outputDir, `${definition.id}.draft.pck`);
		runGodot(draftPath, files);
		const digest = await sha256(draftPath);
		const version = digest.slice(0, 20);
		const versionDir = join(outputDir, definition.id);
		await mkdir(versionDir, { recursive: true });
		const finalPath = join(versionDir, `${version}.pck`);
		const alreadyBuilt = await stat(finalPath).then(() => true, () => false);
		if (alreadyBuilt) await rm(draftPath);
		else await rename(draftPath, finalPath);
		const info = await stat(finalPath);
		manifest.packs.push({
			id: definition.id,
			version,
			sha256: digest,
			size: info.size,
			url: `resource-packs/${definition.id}/${version}.pck`,
			mountPath: `/resource-packs/${definition.id}.pck`,
		});
		console.log(`Built ${definition.id}: ${files.length} resources, ${info.size} bytes, ${version}`);
	}

await writeFile(join(outputDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Wrote independent resource-pack manifest at ${relative(projectDir, outputDir)}/manifest.json`);
