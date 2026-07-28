PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('direct', 'feedback')),
  direct_key TEXT UNIQUE,
  feedback_id TEXT UNIQUE REFERENCES feedback(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS conversations_updated ON conversations(updated_at DESC);

CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at INTEGER NOT NULL,
  last_read_at INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS conversation_members_user
  ON conversation_members(user_id, conversation_id);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  sender_label TEXT NOT NULL,
  body TEXT NOT NULL,
  message_kind TEXT NOT NULL DEFAULT 'user'
    CHECK (message_kind IN ('user', 'admin', 'system', 'ai')),
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS messages_conversation_created
  ON messages(conversation_id, created_at ASC);
