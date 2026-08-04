ALTER TABLE user_profiles ADD COLUMN activity_key TEXT NOT NULL DEFAULT 'observatory';
ALTER TABLE user_profiles ADD COLUMN activity_updated_at INTEGER NOT NULL DEFAULT 0;

ALTER TABLE friend_signals RENAME TO friend_signals_legacy;

CREATE TABLE friend_signals (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('poke', 'come_online', 'invite_observe')),
  seen_at INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

INSERT INTO friend_signals (id, sender_id, recipient_id, kind, seen_at, created_at)
SELECT id, sender_id, recipient_id, kind, seen_at, created_at
FROM friend_signals_legacy;

DROP TABLE friend_signals_legacy;

CREATE INDEX friend_signals_recipient
  ON friend_signals(recipient_id, seen_at, created_at DESC);

CREATE INDEX friend_signals_cooldown
  ON friend_signals(sender_id, recipient_id, kind, created_at DESC);

CREATE INDEX user_profiles_activity
  ON user_profiles(last_active_at DESC, activity_updated_at DESC);
