PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS research_participants (
  participant_id TEXT PRIMARY KEY,
  study_token_hash TEXT NOT NULL UNIQUE,
  language TEXT NOT NULL DEFAULT 'en' CHECK(language IN ('en', 'zh')),
  consent_version TEXT NOT NULL,
  route_arm TEXT NOT NULL CHECK(route_arm IN ('archive_text', 'field_gameplay')),
  current_node TEXT NOT NULL DEFAULT 'baseline',
  completed_nodes_json TEXT NOT NULL DEFAULT '[]',
  defer_counts_json TEXT NOT NULL DEFAULT '{}',
  late_response_count INTEGER NOT NULL DEFAULT 0,
  cross_exposed INTEGER NOT NULL DEFAULT 0 CHECK(cross_exposed IN (0, 1)),
  withdrawn_at INTEGER,
  consented_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS research_responses (
  response_id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES research_participants(participant_id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  question_form_id TEXT NOT NULL,
  answers_json TEXT NOT NULL,
  score INTEGER NOT NULL,
  max_score INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  late_response INTEGER NOT NULL DEFAULT 0 CHECK(late_response IN (0, 1)),
  created_at INTEGER NOT NULL,
  UNIQUE(participant_id, node_id)
);

CREATE TABLE IF NOT EXISTS research_events (
  event_id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES research_participants(participant_id) ON DELETE CASCADE,
  study_version TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS research_events_participant_created
  ON research_events(participant_id, created_at);

CREATE TABLE IF NOT EXISTS research_reward_offers (
  offer_id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES research_participants(participant_id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  candidate_bundle_1 TEXT NOT NULL,
  candidate_bundle_2 TEXT NOT NULL,
  candidate_bundle_3 TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(participant_id, node_id),
  CHECK(
    candidate_bundle_1 <> candidate_bundle_2
    AND candidate_bundle_1 <> candidate_bundle_3
    AND candidate_bundle_2 <> candidate_bundle_3
  )
);

CREATE TABLE IF NOT EXISTS research_reward_issuances (
  issuance_id TEXT PRIMARY KEY,
  participant_id TEXT NOT NULL REFERENCES research_participants(participant_id) ON DELETE CASCADE,
  offer_id TEXT NOT NULL UNIQUE REFERENCES research_reward_offers(offer_id) ON DELETE CASCADE,
  receipt_hash TEXT NOT NULL UNIQUE,
  selected_bundle_id TEXT NOT NULL,
  issued_at INTEGER NOT NULL,
  claimed_at INTEGER
);
