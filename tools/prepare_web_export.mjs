import { readFile, writeFile } from "node:fs/promises";

const projectPath = new URL("../project.godot", import.meta.url);
const project = await readFile(projectPath, "utf8");
const editorPluginsPattern =
  /(\[editor_plugins\]\s*\r?\n\s*enabled=)PackedStringArray\([^\r\n]*\)/;
const featurePattern =
  /(config\/features=PackedStringArray\([^\r\n]*?)"(?:Forward Plus|GL Compatibility)"([^\r\n]*\))/;
const renderingPattern = /(\[rendering\]\s*\r?\n)/;
const debugAutoloadPattern = /^_mcp_game_helper="\*res:\/\/addons\/godot_ai\/runtime\/game_helper\.gd"\r?\n/m;
const preparedRenderingPattern = /^(?:renderer\/rendering_method(?:\.mobile|\.web)?|textures\/vram_compression\/import_etc2_astc)=.*\r?\n/gm;

if (!editorPluginsPattern.test(project)) {
  throw new Error("Could not locate the editor_plugins block in project.godot");
}
if (!featurePattern.test(project) || !renderingPattern.test(project)) {
  throw new Error("Could not locate the renderer configuration in project.godot");
}

await writeFile(
  projectPath,
  project
    .replace(debugAutoloadPattern, "")
    .replace(editorPluginsPattern, "$1PackedStringArray()")
    .replace(featurePattern, '$1"GL Compatibility"$2')
    .replace(preparedRenderingPattern, "")
    .replace(
      renderingPattern,
      "$1renderer/rendering_method=\"gl_compatibility\"\nrenderer/rendering_method.mobile=\"gl_compatibility\"\nrenderer/rendering_method.web=\"gl_compatibility\"\ntextures/vram_compression/import_etc2_astc=true\n",
    ),
);

console.log("Prepared editor plugins and Compatibility renderer for web export.");
