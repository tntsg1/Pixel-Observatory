import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const research = await readFile(new URL("../research_migrations/0001_research_program.sql", import.meta.url), "utf8");
const account = await readFile(new URL("../migrations/0012_research_reward_inventory.sql", import.meta.url), "utf8");

for (const table of ["research_participants", "research_responses", "research_events", "research_reward_offers", "research_reward_issuances"]) {
  assert.match(research, new RegExp(`CREATE TABLE IF NOT EXISTS ${table}`));
}

assert.match(research, /route_arm TEXT NOT NULL CHECK\(route_arm IN \('archive_text', 'field_gameplay'\)\)/);
assert.doesNotMatch(research, /username|email|user_agent|ip_address|account_id/i);
assert.match(account, /CREATE TABLE IF NOT EXISTS research_reward_claims/);
assert.match(account, /CREATE TABLE IF NOT EXISTS user_cosmetic_inventory/);
assert.doesNotMatch(account, /route_arm|responses_json|score|question_form/i);

console.log("research migrations: ok");
