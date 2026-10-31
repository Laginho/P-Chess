# CLEAN-013: Move Review palette styles into shared Theme variations
Stage: blocked
Status: needs-triage
Blocked by: none
Review: human
Difficulty: normal

#### What to investigate

Follow-up for S1 (P3) in [UI-026](78-UI-026-review-screen.md): `ui/review.gd` creates palette/style overrides for the accuracy cards and the empty-analysis card. `.scratch/ui-redo/spec.md`, Foundation, requires shared Theme type variations. The missing variations belong in `ui/theme/p_chess.tres`, outside UI-026's Primary files.

Stage 1 must approve the shared-theme scope and visual verification seam before implementation. Preserve the accepted Review appearance and behaviour; no new screen feature is requested.

## Comments

- 2026-10-31 Opened by UI-026 stage-3 re-review to retain the existing documented-standard finding after UI-026 closes. This is a non-blocking maintainability follow-up; it does not change UI-026's numbered criteria or waive its pending product QA. Blocked pending stage-1 specification of Primary files and acceptance criteria.

Acceptance: unknown
Disclosure: pending | none | Stage 1 must specify this cleanup before implementation; UI-026 integration and Bruno's release QA are independent.
