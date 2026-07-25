import { readFile, writeFile } from "node:fs/promises";

const projectPath = new URL("../project.godot", import.meta.url);
const project = await readFile(projectPath, "utf8");
const editorPluginsPattern =
  /(\[editor_plugins\]\s*\r?\n\s*enabled=)PackedStringArray\([^\r\n]*\)/;
const featurePattern =
  /(config\/features=PackedStringArray\([^\r\n]*?)"Forward Plus"([^\r\n]*\))/;
const renderingPattern = /(\[rendering\]\s*\r?\n)/;

if (!editorPluginsPattern.test(project)) {
  throw new Error("Could not locate the editor_plugins block in project.godot");
}
if (!featurePattern.test(project) || !renderingPattern.test(project)) {
  throw new Error("Could not locate the renderer configuration in project.godot");
}

await writeFile(
  projectPath,
  project
    .replace(editorPluginsPattern, "$1PackedStringArray()")
    .replace(featurePattern, '$1"GL Compatibility"$2')
    .replace(
      renderingPattern,
      "$1renderer/rendering_method=\"gl_compatibility\"\nrenderer/rendering_method.mobile=\"gl_compatibility\"\nrenderer/rendering_method.web=\"gl_compatibility\"\ntextures/vram_compression/import_etc2_astc=true\n",
    ),
);

console.log("Prepared editor plugins and Compatibility renderer for web export.");
