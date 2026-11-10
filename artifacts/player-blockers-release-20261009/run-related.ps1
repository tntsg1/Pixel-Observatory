$ErrorActionPreference='Stop'
$env:APPDATA='E:/godot/po-player-blockers-live-20261009/.test_appdata'
$env:LOCALAPPDATA='E:/godot/po-player-blockers-live-20261009/.test_localappdata'
foreach ($poTestName in @('fast_pulse_capture_test','fast_fold_discovery_test','l31_sombrero_averted_vision_test')) {
 & E:/godot/godot47/Godot_v4.7-stable_win64_console.exe --headless --path E:/godot/po-player-blockers-live-20261009 --script "res://tools/$poTestName.gd"
 if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
