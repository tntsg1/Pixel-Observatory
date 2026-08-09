import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";

// Node 22 marks its built-in SQLite module experimental; keep the contract output stable.
const emitWarning = process.emitWarning;
process.emitWarning = (warning, ...args) => {
  if (warning?.name === "ExperimentalWarning" || args.includes("ExperimentalWarning")) return;
  emitWarning.call(process, warning, ...args);
};
const { DatabaseSync } = await import("node:sqlite");
process.emitWarning = emitWarning;

const researchMigrationDirectory = new URL("../research_migrations/", import.meta.url);
const research = (await Promise.all(
  (await readdir(researchMigrationDirectory))
    .filter(file => file.endsWith(".sql"))
    .sort()
    .map(file => readFile(new URL(file, researchMigrationDirectory), "utf8")),
)).join("\n");
const account = await readFile(new URL("../migrations/0012_research_reward_inventory.sql", import.meta.url), "utf8");
const wrangler = JSON.parse(await readFile(new URL("../wrangler.jsonc", import.meta.url), "utf8"));

const researchTables = [
  "research_participants",
  "research_responses",
  "research_events",
  "research_reward_offers",
  "research_reward_issuances",
];
const accountTables = ["research_reward_claims", "user_cosmetic_inventory"];
const researchParticipantColumns = [
  "participant_id",
  "study_token_hash",
  "language",
  "consent_version",
  "route_arm",
  "current_node",
  "completed_nodes_json",
  "defer_counts_json",
  "late_response_count",
  "cross_exposed",
  "withdrawn_at",
  "consented_at",
  "created_at",
  "updated_at",
];
const researchResponseColumns = [
  "response_id",
  "participant_id",
  "node_id",
  "question_form_id",
  "answers_json",
  "score",
  "max_score",
  "duration_seconds",
  "late_response",
  "created_at",
];
const researchEventColumns = ["event_id", "participant_id", "study_version", "event_type", "payload_json", "created_at"];
const researchOfferColumns = [
  "offer_id",
  "participant_id",
  "node_id",
  "candidate_bundle_1",
  "candidate_bundle_2",
  "candidate_bundle_3",
  "created_at",
];
const researchIssuanceColumns = [
  "issuance_id",
  "participant_id",
  "offer_id",
  "receipt_hash",
  "selected_bundle_id",
  "issued_at",
  "claimed_at",
];
const selectedCosmeticColumns = [
  "study_prestige_level",
  "selected_avatar",
  "selected_frame",
  "selected_background",
  "selected_name_glow",
  "selected_chat_bubble",
  "selected_badge",
  "selected_research_title",
];

function columnNames(database, table) {
  return database.prepare(`PRAGMA table_info(${table})`).all().map(column => column.name);
}

function assertColumns(database, table, expected) {
  const actual = columnNames(database, table);
  for (const column of expected) {
    assert.ok(actual.includes(column), `${table} includes ${column}`);
  }
}

function expectSqliteFailure(action, message) {
  assert.throws(action, /constraint|research_reward_issuance_offer_mismatch/i, message);
}

function insertParticipant(database, participantId, studyTokenHash) {
  database.prepare(
    `INSERT INTO research_participants (
      participant_id, study_token_hash, language, consent_version, route_arm,
      current_node, completed_nodes_json, defer_counts_json, late_response_count,
      cross_exposed, consented_at, created_at, updated_at
    ) VALUES (?, ?, 'en', 'consent-v1', 'archive_text', 'baseline', '[]', '{}', 0, 0, 1, 1, 1)`,
  ).run(participantId, studyTokenHash);
}

function insertOffer(database, offerId, participantId, nodeId, candidates) {
  database.prepare(
    `INSERT INTO research_reward_offers (
      offer_id, participant_id, node_id, candidate_bundle_1, candidate_bundle_2, candidate_bundle_3, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, 1)`,
  ).run(offerId, participantId, nodeId, ...candidates);
}

function insertIssuance(database, issuanceId, participantId, offerId, receiptHash, selectedBundleId) {
  database.prepare(
    `INSERT INTO research_reward_issuances (
      issuance_id, participant_id, offer_id, receipt_hash, selected_bundle_id, issued_at
    ) VALUES (?, ?, ?, ?, ?, 1)`,
  ).run(issuanceId, participantId, offerId, receiptHash, selectedBundleId);
}

function assertResearchPrivacyBoundary(database) {
  const forbidden = /(^|_)(?:user_?id|account_?id|username|email|ip_?address|ip|raw_?user_?agent|user_?agent|device\w*|fingerprint)(_|$)/i;
  for (const table of researchTables) {
    for (const column of columnNames(database, table)) {
      assert.doesNotMatch(column, forbidden, `${table}.${column} is not an identifying field`);
    }
  }
}

function assertAccountPrivacyBoundary(database) {
  const forbidden = /(^|_)(?:route_?arm|answers?|question_?form|form|score|participant_?id|research_?participant_?id|study_?token_?hash|participant_?token|research_?token)(_|$)/i;
  for (const table of accountTables) {
    for (const column of columnNames(database, table)) {
      assert.doesNotMatch(column, forbidden, `${table}.${column} stays out of account storage`);
    }
  }
  for (const column of columnNames(database, "user_profiles")) {
    assert.doesNotMatch(column, forbidden, `user_profiles.${column} stays out of account storage`);
  }
}

function assertForeignKeysStayInTheirDatabase(database, tables, allowedTargets) {
  for (const table of tables) {
    for (const foreignKey of database.prepare(`PRAGMA foreign_key_list(${table})`).all()) {
      assert.ok(allowedTargets.includes(foreignKey.table), `${table} foreign key stays in its database`);
    }
  }
}

const binding = wrangler.d1_databases.filter(database => database.binding === "RESEARCH_DB");
assert.equal(binding.length, 1, "one isolated research binding exists");
assert.deepEqual(
  {
    binding: binding[0].binding,
    database_name: binding[0].database_name,
    migrations_dir: binding[0].migrations_dir,
  },
  {
    binding: "RESEARCH_DB",
    database_name: "pixel-observatory-research",
    migrations_dir: "research_migrations",
  },
);
assert.match(binding[0].database_id, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
assert.notEqual(binding[0].database_id, "00000000-0000-0000-0000-000000000000");

const researchDatabase = new DatabaseSync(":memory:");
const accountDatabase = new DatabaseSync(":memory:");

try {
  researchDatabase.exec("PRAGMA foreign_keys = ON;");
  researchDatabase.exec(research);
  accountDatabase.exec(`
    PRAGMA foreign_keys = ON;
    CREATE TABLE users (id TEXT PRIMARY KEY);
    CREATE TABLE user_profiles (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      bio TEXT NOT NULL DEFAULT '',
      avatar_id INTEGER NOT NULL DEFAULT 1 CHECK (avatar_id BETWEEN 1 AND 8),
      selected_title TEXT NOT NULL DEFAULT 'first-light',
      play_seconds INTEGER NOT NULL DEFAULT 0,
      last_active_at INTEGER NOT NULL DEFAULT 0,
      last_play_heartbeat_at INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    );
  `);
  accountDatabase.exec(account);

  assert.deepEqual(
    researchDatabase.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'research_%' ORDER BY name").all().map(row => row.name),
    [...researchTables].sort(),
  );
  assertColumns(researchDatabase, "research_participants", researchParticipantColumns);
  assertColumns(researchDatabase, "research_responses", researchResponseColumns);
  assertColumns(researchDatabase, "research_events", researchEventColumns);
  assertColumns(researchDatabase, "research_reward_offers", researchOfferColumns);
  assertColumns(researchDatabase, "research_reward_issuances", researchIssuanceColumns);
  assertResearchPrivacyBoundary(researchDatabase);
  assertForeignKeysStayInTheirDatabase(researchDatabase, researchTables, researchTables);

  insertParticipant(researchDatabase, "p1", "token-hash-1");
  insertParticipant(researchDatabase, "p2", "token-hash-2");
  expectSqliteFailure(
    () => insertParticipant(researchDatabase, "p3", "token-hash-1"),
    "study token hashes are unique",
  );
  researchDatabase.prepare(
    `INSERT INTO research_responses (
      response_id, participant_id, node_id, question_form_id, answers_json, score, max_score, created_at
    ) VALUES ('response-1', 'p1', 'baseline', 'baseline-1', '{}', 0, 3, 1)`,
  ).run();
  expectSqliteFailure(
    () => researchDatabase.prepare(
      `INSERT INTO research_responses (
        response_id, participant_id, node_id, question_form_id, answers_json, score, max_score, created_at
      ) VALUES ('response-2', 'p1', 'baseline', 'baseline-2', '{}', 1, 3, 1)`,
    ).run(),
    "responses are unique per participant and node",
  );
  insertOffer(researchDatabase, "offer-1", "p1", "A", ["R01", "R02", "R03"]);
  expectSqliteFailure(
    () => insertOffer(researchDatabase, "offer-duplicate", "p1", "A", ["R04", "R05", "R06"]),
    "offers are unique per participant and node",
  );

  expectSqliteFailure(
    () => insertIssuance(researchDatabase, "issuance-wrong-owner", "p2", "offer-1", "receipt-wrong-owner", "R01"),
    "issuances reject an offer owned by another participant",
  );
  expectSqliteFailure(
    () => insertIssuance(researchDatabase, "issuance-unoffered", "p1", "offer-1", "receipt-unoffered", "R99"),
    "issuances reject a bundle outside the offer candidates",
  );
  insertIssuance(researchDatabase, "issuance-valid", "p1", "offer-1", "receipt-valid", "R02");
  expectSqliteFailure(
    () => researchDatabase.prepare(
      "UPDATE research_reward_issuances SET participant_id = 'p2' WHERE issuance_id = 'issuance-valid'",
    ).run(),
    "issuances reject ownership changes after creation",
  );
  expectSqliteFailure(
    () => researchDatabase.prepare(
      "UPDATE research_reward_issuances SET selected_bundle_id = 'R99' WHERE issuance_id = 'issuance-valid'",
    ).run(),
    "issuances reject bundles outside the offer after creation",
  );
  expectSqliteFailure(
    () => researchDatabase.prepare(
      "UPDATE research_reward_offers SET candidate_bundle_2 = 'R99' WHERE offer_id = 'offer-1'",
    ).run(),
    "offers cannot invalidate an existing issuance",
  );
  expectSqliteFailure(
    () => insertIssuance(researchDatabase, "issuance-offer-reuse", "p1", "offer-1", "receipt-other", "R03"),
    "an offer produces one issuance",
  );
  insertOffer(researchDatabase, "offer-2", "p1", "B", ["R04", "R05", "R06"]);
  expectSqliteFailure(
    () => insertIssuance(researchDatabase, "issuance-receipt-reuse", "p1", "offer-2", "receipt-valid", "R04"),
    "receipt hashes are unique",
  );

  assert.deepEqual(
    accountDatabase.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('research_reward_claims', 'user_cosmetic_inventory') ORDER BY name").all().map(row => row.name),
    [...accountTables].sort(),
  );
  assertColumns(accountDatabase, "user_profiles", ["avatar_id", ...selectedCosmeticColumns]);
  assertColumns(accountDatabase, "research_reward_claims", ["receipt_id", "user_id", "bundle_id", "claimed_at"]);
  assertColumns(accountDatabase, "user_cosmetic_inventory", ["user_id", "bundle_id", "acquired_at"]);
  assertAccountPrivacyBoundary(accountDatabase);
  assertForeignKeysStayInTheirDatabase(accountDatabase, accountTables, ["users"]);

  accountDatabase.prepare("INSERT INTO users (id) VALUES ('u1'), ('u2'), ('u3')").run();
  expectSqliteFailure(
    () => accountDatabase.prepare("INSERT INTO user_profiles (user_id, avatar_id, updated_at) VALUES ('u1', 9, 1)").run(),
    "legacy avatar constraint rejects IDs outside 1 through 8",
  );
  accountDatabase.prepare("INSERT INTO user_profiles (user_id, updated_at) VALUES ('u1', 1)").run();
  const profile = accountDatabase.prepare(
    "SELECT study_prestige_level, selected_avatar FROM user_profiles WHERE user_id = 'u1'",
  ).get();
  assert.equal(profile.study_prestige_level, 0);
  assert.equal(profile.selected_avatar, "legacy-1");
  accountDatabase.prepare(
    "INSERT INTO research_reward_claims (receipt_id, user_id, bundle_id, claimed_at) VALUES ('receipt-1', 'u1', 'R01', 1)",
  ).run();
  expectSqliteFailure(
    () => accountDatabase.prepare(
      "INSERT INTO research_reward_claims (receipt_id, user_id, bundle_id, claimed_at) VALUES ('receipt-1', 'u2', 'R02', 1)",
    ).run(),
    "receipt claims are unique by receipt ID",
  );
  accountDatabase.prepare(
    "INSERT INTO user_cosmetic_inventory (user_id, bundle_id, acquired_at) VALUES ('u1', 'R01', 1)",
  ).run();
  expectSqliteFailure(
    () => accountDatabase.prepare(
      "INSERT INTO user_cosmetic_inventory (user_id, bundle_id, acquired_at) VALUES ('u1', 'R01', 2)",
    ).run(),
    "cosmetic inventory is unique by user and bundle",
  );
}
finally {
  researchDatabase.close();
  accountDatabase.close();
}

console.log("research migrations: ok");
