ALTER TABLE user_profiles
ADD COLUMN last_play_report_id TEXT NOT NULL DEFAULT '';

ALTER TABLE user_profiles
ADD COLUMN last_play_report_credit_seconds INTEGER NOT NULL DEFAULT 0;
