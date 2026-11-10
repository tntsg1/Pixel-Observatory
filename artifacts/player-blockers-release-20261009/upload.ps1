$ErrorActionPreference='Stop'
$wrangler='C:/Users/tntsg/AppData/Local/npm-cache/_npx/d77349f55c2be1c0/node_modules/wrangler/bin/wrangler.js'
$base='E:/godot/po-player-blockers-live-20261009/build/web/game/runtime/39eabc3b8b8d'
node $wrangler r2 object put pixel-observatory-game-assets/runtime/39eabc3b8b8d/index.pck --file "$base/index.pck" --content-type application/octet-stream --cache-control 'public, max-age=31536000, immutable' --remote
if ($LASTEXITCODE -ne 0) {exit $LASTEXITCODE}
node $wrangler r2 object put pixel-observatory-game-assets/runtime/39eabc3b8b8d/index.wasm --file "$base/index.wasm" --content-type application/wasm --cache-control 'public, max-age=31536000, immutable' --remote
exit $LASTEXITCODE
