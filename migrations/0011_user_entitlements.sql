PRAGMA foreign_keys = ON;

-- Privileged game tools are intentionally separate from the administrator
-- role. An observer may use the in-game developer console without gaining
-- moderation, feedback-console, database, or deployment access.
CREATE TABLE IF NOT EXISTS user_entitlements (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  developer_console INTEGER NOT NULL DEFAULT 0 CHECK (developer_console IN (0, 1)),
  special_title_en TEXT NOT NULL DEFAULT '',
  special_title_zh TEXT NOT NULL DEFAULT '',
  honor_en TEXT NOT NULL DEFAULT '',
  honor_zh TEXT NOT NULL DEFAULT '',
  avatar_frame TEXT NOT NULL DEFAULT 'standard',
  granted_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  granted_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS user_entitlements_developer_console
  ON user_entitlements(developer_console, updated_at DESC);
