PRAGMA foreign_keys = ON;

-- Anonymous research sessions intentionally have no foreign key to the game
-- account table. Exports use only this generated study id.
CREATE TABLE IF NOT EXISTS study_participants (
  id TEXT PRIMARY KEY,
  study_token_hash TEXT NOT NULL UNIQUE,
  language TEXT NOT NULL DEFAULT 'en' CHECK(language IN ('en', 'zh')),
  consent_version TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'enrolled' CHECK(status IN ('enrolled', 'reading', 'game', 'post_game', 'completed', 'withdrawn')),
  next_stage TEXT NOT NULL DEFAULT 'pretest' CHECK(next_stage IN ('pretest', 'reading', 'reading_posttest', 'game', 'posttest', 'experience', 'complete')),
  pretest_completed_at INTEGER NOT NULL DEFAULT 0,
  reading_started_at INTEGER NOT NULL DEFAULT 0,
  reading_completed_at INTEGER NOT NULL DEFAULT 0,
  reading_posttest_completed_at INTEGER NOT NULL DEFAULT 0,
  game_started_at INTEGER NOT NULL DEFAULT 0,
  game_completed_at INTEGER NOT NULL DEFAULT 0,
  posttest_completed_at INTEGER NOT NULL DEFAULT 0,
  experience_completed_at INTEGER NOT NULL DEFAULT 0,
  game_active_seconds INTEGER NOT NULL DEFAULT 0,
  game_event_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS study_participants_status_updated
  ON study_participants(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS study_responses (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES study_participants(id) ON DELETE CASCADE,
  phase TEXT NOT NULL CHECK(phase IN ('pre', 'reading_post', 'post', 'experience')),
  responses_json TEXT NOT NULL,
  score INTEGER,
  max_score INTEGER,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  quality_flags_json TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL,
  UNIQUE(participant_id, phase)
);

CREATE INDEX IF NOT EXISTS study_responses_participant_phase
  ON study_responses(participant_id, phase);

CREATE TABLE IF NOT EXISTS study_events (
  id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES study_participants(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS study_events_participant_created
  ON study_events(participant_id, created_at);
