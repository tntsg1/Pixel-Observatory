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
