ALTER TABLE community_replies ADD COLUMN parent_reply_id TEXT;

CREATE INDEX IF NOT EXISTS community_replies_parent
  ON community_replies(parent_reply_id, deleted_at, created_at ASC);
