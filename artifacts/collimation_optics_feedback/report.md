# Collimation Optics Feedback

## Runtime Rules

- The collimation bench draws a live focused-star preview from the same combined primary/secondary mirror error used by the score.
- Misalignment produces directional coma; alignment produces a compact core with symmetric diffraction rings.
- Telescope-view severity is `(100 - collimation_score) / 50`, clamped to `0..1`.
- Stars receive a directional coma tail and elongated ghost images.
- Planets, the Moon, nebulae, and galaxies receive offset blur/ghosting and reduced detail.
- Focus and collimation remain separate. Exact focus cannot remove coma.
- The real clarity score continues to use `GameManager.calculate_stats()`; the visual effect does not replace or bypass quality calculation.
- Existing collimation gates, level order, and save structure are unchanged.

## Evidence

- `01_bench_misaligned_star.png`: live asymmetric coma preview.
- `02_bench_aligned_star.png`: symmetric Airy-disc preview.
- `03_scope_poor_collimation.png`: Vega at exact mechanical focus with 20% collimation.
- `04_scope_perfect_collimation.png`: the same target at exact focus with 100% collimation.

## Validation

- `collimation_optics_feedback_test.gd`: passed.
- Existing animation, Newtonian, focus, environment, identification, and layer tests: passed.
