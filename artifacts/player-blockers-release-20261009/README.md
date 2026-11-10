# Player blocker release — 2026-10-09

- Production source baseline: 6b45873554ea (verified from previous live game shell, not stale origin/main).
- Released source: 39eabc3b8b8d, branch fix/player-blockers-live-20261009 pushed to origin.
- Fixes: L39/L43 explicit side-view access and centering instructions; L55 Triton click instruction; FAST calibration UI uses mission thresholds, including phase/capture/confirmation flow.
- Focused native tests passed: player_reported_blockers_test.gd (L30/39/43/55 and FAST76–85), fast_pulse_capture_test.gd, fast_fold_discovery_test.gd, l31_sombrero_averted_vision_test.gd.
- Web export completed without ERROR, SCRIPT ERROR or parse/resource failures. Resource packs unchanged by SHA256.
- R2 runtime uploaded to runtime/39eabc3b8b8d/index.pck and index.wasm.
- Existing production Worker from po-l10-live-hotfix retained, including trailer and account bindings. Existing static files retained; landing HTML preserved with edge-injected analytics removed from source to avoid duplicate injection.
- Pixel Worker version: 61030f37-2c1a-4fae-ba77-fd9705a55dd7.
- Online browser evidence: browser.json, browser.log, live-menu.png; see these files for final verification result. Automated tests are not a manual campaign playthrough.
- Old pixelobservatorygame.com/stellar* access closed separately in Stellar Worker; original live asset set retained with keep_assets. Source commit G:/CODE/stellar-web: 9336599. Deployment: 5785849ec61443d1a8766730303e88ca.

Final online validation PASS: old domain routes 404 without redirects, dedicated pages 200, landing content unchanged after normalizing edge analytics/newlines, PCK MD5 15ea1f5cdb81dbe0ad1fb5cc75b1738e, menu loaded and New Game enters story. No browser runtime errors; guest /api/social/friends 401 responses recorded separately.
