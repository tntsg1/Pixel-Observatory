$ErrorActionPreference='Stop'
node tools/prepare_web_export.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
New-Item -ItemType Directory -Path build/web/.godot-export -Force | Out-Null
& E:/godot/godot47/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/po-player-blockers-live-20261009 --export-release Web build/web/.godot-export/index.html
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node tools/build_web_resource_packs.mjs E:/godot/godot47/Godot_v4.7-stable_win64_console.exe build/web/.godot-export/resource-packs .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node tools/build_web_shell.mjs build/web build/web/.godot-export
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node tools/build_cloudflare_release.mjs build/web build/cloudflare-public
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
