PRAGMA foreign_keys = ON;

ALTER TABLE user_profiles ADD COLUMN profile_theme TEXT NOT NULL DEFAULT 'standard';

CREATE TABLE IF NOT EXISTS user_moderation (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  muted_until INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL DEFAULT '',
  moderator_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS user_moderation_muted_until
  ON user_moderation(muted_until);

CREATE TABLE IF NOT EXISTS moderation_actions (
  id TEXT PRIMARY KEY,
  moderator_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('mute', 'unmute')),
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  reason TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS moderation_actions_target
  ON moderation_actions(target_user_id, created_at DESC);
