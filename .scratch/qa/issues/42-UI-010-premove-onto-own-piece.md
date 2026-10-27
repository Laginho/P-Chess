# UI-010: Premoves follow piece geometry, so recaptures can be queued
Stage: to-merge
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: hard

- Primary files:
  - ui/premove_queue.gd
  - ui/board_view.gd (premove targets and dots)
  - tests/test_premove.gd
  - docs/spec.md (§8.2)

#### What to build

A premove that recaptures cannot be queued today: `PremoveQueue` checks input against `legal_moves()` of a ghost position, and a square holding your own piece is never a legal target (Bruno's QA, 2026-10-26: "o pre-move não funciona se for pra recapturar uma peça minha"). Lichess and Chess.com accept any premove the piece's movement pattern allows, and check legality only when it is due.

Premove input accepts any move that fits the piece's geometry from the ghost position, ignoring what stands on the target and in between: rook along its rank or file, bishop along its diagonals, queen both, knight's jumps, king one square or castling from its start square, pawn one forward, two forward from its start rank, or one diagonally forward. The real-board legality check at execution (§8.2) stays as it is.

#### Acceptance criteria

1. With Maia to move, a premove onto a square holding one of your own pieces is queued when the piece's geometry reaches it (example: your knight on f3 and pawn on e5; premove Nf3xe5).
2. Sliding premoves are accepted through blockers, and a pawn's diagonal premove is accepted onto an empty square.
3. A premove that does not fit the geometry (a knight moving like a bishop, a pawn moving backwards) is still rejected.
4. When a due premove is illegal on the real board, it and the rest of the queue are dropped, as now.
5. In the Chess.com queue, each queued premove is applied to the ghost position (replacing whatever stood on its target), and the next premove is validated from there.
6. While premoving, the legal-move dots show the geometric targets.
7. A premove promotion still follows the auto-queen setting and Alt.

#### Verification

    Manual: a 1+0 game; premove a recapture onto a square your own piece occupies; it plays when Maia captures there.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_premove.gd`: queueing a premove onto your own piece, through a blocker, and a pawn diagonal onto an empty square (red: `enqueue` returns false); a geometry miss is still rejected; the recapture plays when Maia captures there.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 3). Default taken: Lichess's geometric premove rule for both styles, including through blockers; correct it if a stricter rule is wanted.
- The existing guard against premoving onto a king square in the ghost position stays, since the ghost can put the opposing king in reach.

- Red: 253 passed, 2 failed at fd05a74; geometric queue and board target assertions failed as expected.
- Green: 255 passed, 0 failed at 6b1f607; gate exit 0.
- Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui-010-stage3-gate.json
- Acceptance: pending | Manual 1+0 recapture against Maia remains to be checked.
- Disclosure: pending | release | Manual 1+0 recapture against Maia remains to be checked.

#### Resolution (2026-10-27)
Verdict: Approve

- Reviewer: gpt-6.1-sol xhigh, stage 3 of Models (terra). Independent Standards and Spec reviewers examined `c2ef1f1...42fc55f`; neither found a breach, defect or actionable smell. No review fixes were needed.
- Standards: the changes stay in the Primary files plus ticket metadata. `fd05a74` contains tests only, `6b1f607` contains production/spec only, and `42fc55f` contains the handoff only.
- Spec: criteria 1-7 pass inspection and automated coverage: own-piece recapture, blocked sliders and empty pawn diagonals, rejected geometry, illegal-due queue clearing, sequential ghost replacement, geometric targets, and auto-queen/Alt promotion.
- Examined callers and failure paths: queue enqueue/input/projection/take; board pickup, targets, drawing, drop and submission; Main's Maia callback and turn dispatch; Board/Game real execution. Cross-feature checks covered both colours, Lichess replacement, Chess.com chaining, castling, en passant, king-target guards, promotion cancellation, captured sources and game-end cleanup.
- Files: `ui/premove_queue.gd`, `ui/board_view.gd`, `tests/test_premove.gd`, `docs/spec.md` section 8.2.
- Red-green proof: the recorded red log has 253 passed, 2 failed at `fd05a74`, including rejected own-piece recapture and missing board targets. The stage-2 green log has 255 passed, 0 failed at `6b1f607`, exit 0. After integrating UI-008, the stage-3 gate has 256 passed, 0 failed, exit 0; the current receipt is linked above.
- Integration: fetched and rebased onto `origin/main` before PR creation and again after UI-008 merged. Both `docs/spec.md` changes are preserved, with UI-010 limited to section 8.2. The pre-existing terra lineup is now part of `origin/main`.
- Proxy decisions: none.
- Acceptance: pending | [Automated recapture and board-target coverage](../../../tests/test_premove.gd) passes; the manual 1+0 recapture against Maia was not performed.
- Disclosure: pending | release | The manual 1+0 recapture check remains a release condition; this review establishes automated correctness only.
