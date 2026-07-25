import { readFile, writeFile } from "node:fs/promises";

const projectPath = new URL("../project.godot", import.meta.url);
const project = await readFile(projectPath, "utf8");
const editorPluginsPattern =
  /(\[editor_plugins\]\s*\r?\n\s*enabled=)PackedStringArray\([^\r\n]*\)/;

if (!editorPluginsPattern.test(project)) {
  throw new Error("Could not locate the editor_plugins block in project.godot");
}

await writeFile(
  projectPath,
  project.replace(editorPluginsPattern, "$1PackedStringArray()"),
);

console.log("Disabled editor-only plugins for the headless web export.");
