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

## Casino entry on the main nav (2026-10-02)

- New `.gnav-casino` pill in `web/landing/promo.html`, placed between the `.gnav-new`
  (Stellar Ascension) pill and `.gnav-play`, linking to `/casino`.
- Target is a **separate worker** (`roulette-anti-gamble`, repo `G:\CODE\roulette-anti-gamble`)
  that owns `pixelobservatorygame.com/casino*` plus the `gamble.pixelobservatorygame.com`
  custom domain. Nothing in `pixel-observatory-web` changed for it; `/casino` must stay 200.
- Motif is a CSS-only roulette wheel (`conic-gradient` red/black + gold hub), no NEW badge,
  so the nav does not end up with two competing badges. Bilingual `Casino / 赌场`.
- In the 1251–1800px band the pill collapses to a 38px icon exactly like `.gnav-new`; the same
  media query now also tightens `.gnav` (gap 3px, padding 14/8) and `.gnav-links` margin, which
  recovers ~10px more than the pill costs in zh — verified with headless Chrome: at 1440px zh the
  Play button moved 10px *inward* versus pre-change (1427 vs 1437), and in English the
  pre-existing Play clipping in that band shrank by 22px (1537 vs 1559).
- Deployed 2026-10-02 by copying `web/landing/promo.html` → `build/cloudflare-public/index.html`
  and running `npx -y wrangler@4 deploy` from this worktree (5 assets uploaded, `index.html`
  among them; that copy also carried the pending v0.9.7 → v0.9.8 bump into the built file).

## Changelog page (2026-09-29)

- Live at https://pixelobservatorygame.com/changelog/ — source `web/landing/changelog/index.html`,
  data `web/landing/changelog.json` (bilingual; built from `docs/CHANGELOG.md` + `docs/VERSION_HISTORY.md`).
- Entry points in `web/landing/promo.html`: `.hero-log` line under the hero buttons (shows a static
  version, currently `v0.9.7`) and a footer "Changelog / 更新日志" link.
- **On every release:** add the entry to `changelog.json` (newest first, `en` + `zh`), bump the version in
  `.hero-log`, and keep `docs/CHANGELOG.md` as the local record. Deployed by patching the built index
  identically (3 files uploaded).

## Casino → footer (2026-10-04)

- The `.gnav-casino` nav pill was removed at the user's request. The entry now lives in the footer as a separate
  `.foot-other` row: "Other games / 其他游戏" → "Anti-Gambling / 反赌博" (`.foot-anti`, still links to `/casino`,
  reuses the `.gnav-casino-wheel` icon CSS). Deployed the same way (copy promo.html → build index, `wrangler@4 deploy`).
