CREATE TRIGGER IF NOT EXISTS research_reward_issuances_validate_insert
BEFORE INSERT ON research_reward_issuances
FOR EACH ROW
WHEN NOT EXISTS (
  SELECT 1
  FROM research_reward_offers
  WHERE offer_id = NEW.offer_id
    AND participant_id = NEW.participant_id
    AND NEW.selected_bundle_id IN (candidate_bundle_1, candidate_bundle_2, candidate_bundle_3)
)
BEGIN
  SELECT RAISE(ABORT, 'research_reward_issuance_offer_mismatch');
END;

CREATE TRIGGER IF NOT EXISTS research_reward_issuances_validate_update
BEFORE UPDATE OF participant_id, offer_id, selected_bundle_id ON research_reward_issuances
FOR EACH ROW
WHEN NOT EXISTS (
  SELECT 1
  FROM research_reward_offers
  WHERE offer_id = NEW.offer_id
    AND participant_id = NEW.participant_id
    AND NEW.selected_bundle_id IN (candidate_bundle_1, candidate_bundle_2, candidate_bundle_3)
)
BEGIN
  SELECT RAISE(ABORT, 'research_reward_issuance_offer_mismatch');
END;

CREATE TRIGGER IF NOT EXISTS research_reward_offers_preserve_issuance_integrity
BEFORE UPDATE OF participant_id, candidate_bundle_1, candidate_bundle_2, candidate_bundle_3 ON research_reward_offers
FOR EACH ROW
WHEN EXISTS (
  SELECT 1
  FROM research_reward_issuances
  WHERE offer_id = OLD.offer_id
    AND (
      participant_id <> NEW.participant_id
      OR selected_bundle_id NOT IN (NEW.candidate_bundle_1, NEW.candidate_bundle_2, NEW.candidate_bundle_3)
    )
)
BEGIN
  SELECT RAISE(ABORT, 'research_reward_issuance_offer_mismatch');
END;
