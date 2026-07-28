# Accounts, Cloud Saves, and Feedback

The canonical website at `https://pixelobservatorygame.com/` owns the account
session. Because the game runs at `/game/` on the same origin, the browser can
use the same Secure, HttpOnly session without exposing its token to website or
Godot JavaScript.

## Public API

- `GET /api/config` returns public feature flags and the Turnstile site key.
- `POST /api/auth/register`, `/login`, `/logout`, and `/password` manage the
  observer account.
- `GET /api/auth/session` returns the current public user profile.
- `GET` and `PUT /api/cloud-save` read and version the current user's save.
- `POST /api/feedback` accepts a field report and returns a receipt.

## Developer Console

The feedback console is served at `/admin/`. Its API requires a database user
whose role is `admin`; hiding the page is not the security boundary.

To promote an existing observer account:

```powershell
npx --yes wrangler@latest d1 execute pixel-observatory --remote --command "UPDATE users SET role='admin' WHERE username_key='observer-name';"
```

## Security and Operations

- `TURNSTILE_SECRET` and `RATE_LIMIT_SECRET` are Worker secrets and must never
  be committed.
- Turnstile is always verified server-side. The widget alone is not proof.
- Usernames are intentionally restricted to 3-24 ASCII letters, numbers,
  dots, dashes and underscores to avoid visually confusable account names.
- Cloud writes use optimistic versions. A stale client receives `409` and
  downloads the current cloud copy before deciding whether to upload again.
- The Godot client only enables cloud sync in Web exports. Native development
  builds remain local-only.
- D1 migrations live in `migrations/` and are applied with
  `wrangler d1 migrations apply pixel-observatory --remote`.
