# Handoff: Stellar Ascension entry on the main nav (2026-09-28)

- Live since 2026-09-28: `web/landing/promo.html` has a `.gnav-new` pill next to `.gnav-play`
  linking to `/stellar/` (commit on branch `feat/stellar-entry-20260928`, based on b14bb65; not pushed).
- The deploy patched `build/cloudflare-public/index.html` with the identical insertion; wrangler
  uploaded only index.html. **Merge this branch (or cherry-pick the commit) before the next main-site
  deploy, or the entry disappears.**
- `/stellar*` is a separate worker `stellar-ascension-web` (repo `G:\CODE\stellar-web`), same zone,
  same R2 bucket under prefix `stellar/`. It reuses `/api/auth/*`, `/api/config` and the `po_session`
  cookie (same origin); nothing in this worker was changed.
- Pre-existing: in English at ~1440px wide the full nav is wider than the viewport (▶ Play is cut off);
  not caused by this change (the entry collapses to a 38px icon between 1251 and 1800px).

## Changelog page (2026-09-29)

- Live at https://pixelobservatorygame.com/changelog/ — source `web/landing/changelog/index.html`,
  data `web/landing/changelog.json` (bilingual; built from `docs/CHANGELOG.md` + `docs/VERSION_HISTORY.md`).
- Entry points in `web/landing/promo.html`: `.hero-log` line under the hero buttons (shows a static
  version, currently `v0.9.7`) and a footer "Changelog / 更新日志" link.
- **On every release:** add the entry to `changelog.json` (newest first, `en` + `zh`), bump the version in
  `.hero-log`, and keep `docs/CHANGELOG.md` as the local record. Deployed by patching the built index
  identically (3 files uploaded).
