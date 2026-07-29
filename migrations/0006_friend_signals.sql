PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS friend_signals (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('poke', 'come_online')),
  seen_at INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS friend_signals_recipient
  ON friend_signals(recipient_id, seen_at, created_at DESC);

CREATE INDEX IF NOT EXISTS friend_signals_cooldown
  ON friend_signals(sender_id, recipient_id, kind, created_at DESC);
