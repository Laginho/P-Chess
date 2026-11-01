# CLEAN-013: Move Review palette styles into shared Theme variations
Stage: done
Status: ready-for-agent
Blocked by: none
Review: human
Difficulty: normal

#### What to investigate

Follow-up for S1 (P3) in [UI-026](78-UI-026-review-screen.md): `ui/review.gd` creates palette/style overrides for the accuracy cards and the empty-analysis card. `.scratch/ui-redo/spec.md`, Foundation, requires shared Theme type variations. The missing variations belong in `ui/theme/p_chess.tres`, outside UI-026's Primary files.

Stage 1 must approve the shared-theme scope and visual verification seam before implementation. Preserve the accepted Review appearance and behaviour; no new screen feature is requested.

## Comments

- 2026-10-31 Opened by UI-026 stage-3 re-review to retain the existing documented-standard finding after UI-026 closes. This is a non-blocking maintainability follow-up; it does not change UI-026's numbered criteria or waive its pending product QA. Blocked pending stage-1 specification of Primary files and acceptance criteria.

Acceptance: pending | PR #35 review rounds, then Bruno merges (Review: human).
Disclosure: decision | none | Triaged and approved by the parent session on 2026-10-31, as part of the PR #35 fidelity pass; additive theme changes only, so PR #36 can merge alongside.

- 2026-10-31 Triaged by the parent session: approved, done inside the PR #35 fidelity pass. Implemented in 5c1593a: `ui/theme/p_chess.tres` gains five type variations, additive only (no existing entry edited, so PR #36's theme changes merge alongside): `AccuracyCardLight` / `AccuracyCardDark` (PanelContainer; light #ece9e4, dark #141412 with a 1 px #6b675f border, radius 6), `AccuracyValueLight` / `AccuracyValueDark` (Label; 22 px, weight 800, ink or text colour) and `EmptyAnalysisCard` (Panel; ground #1f1e1c, 1 px border, radius 10). `ui/review.gd` sets only `theme_type_variation` on the accuracy cards, their values and the empty-analysis card (`NoticeCard`). Verification seam: `test_review_cards_use_theme_variations` asserts the variations and the absence of inline stylebox, colour and size overrides (red before the change, green after). Appearance: the after captures listed in [UI-026](78-UI-026-review-screen.md).

- 2026-10-31 Round 1 (35aeeb2) adds one more additive variation, `LegendPanel` (PopupPanel; raised #363430, 1 px border, radius 10), for the move-class legend.
- 2026-10-31 Parent: done in the PR #35 fidelity pass (5c1593a, LegendPanel in round 1), approved by its round-4 review; merges with PR #35.
