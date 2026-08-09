PRAGMA foreign_keys = ON;

ALTER TABLE user_profiles ADD COLUMN study_prestige_level INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_profiles ADD COLUMN selected_avatar TEXT NOT NULL DEFAULT 'legacy-1';
ALTER TABLE user_profiles ADD COLUMN selected_frame TEXT;
ALTER TABLE user_profiles ADD COLUMN selected_background TEXT;
ALTER TABLE user_profiles ADD COLUMN selected_name_glow TEXT;
ALTER TABLE user_profiles ADD COLUMN selected_chat_bubble TEXT;
ALTER TABLE user_profiles ADD COLUMN selected_badge TEXT;
ALTER TABLE user_profiles ADD COLUMN selected_research_title TEXT;

CREATE TABLE IF NOT EXISTS research_reward_claims (
  receipt_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bundle_id TEXT NOT NULL,
  claimed_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_cosmetic_inventory (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bundle_id TEXT NOT NULL,
  acquired_at INTEGER NOT NULL,
  PRIMARY KEY(user_id, bundle_id)
);
