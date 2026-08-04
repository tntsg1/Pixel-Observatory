PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS observation_shares (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  owner_username TEXT NOT NULL,
  object_id TEXT NOT NULL,
  object_name TEXT NOT NULL,
  telescope_family TEXT NOT NULL,
  quality TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL DEFAULT 0,
  revoked_at INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS observation_shares_owner_created
  ON observation_shares(owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS observation_shares_public_lookup
  ON observation_shares(id, revoked_at, expires_at);
