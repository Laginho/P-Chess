# UI-024: Game-over card to the design
Stage: done
Blocked by: UI-021, UI-023
Review: agent
Difficulty: normal

- Primary files:
  - ui/game_over.gd, ui/game_over.tscn
  - ui/main.gd (only the card's Copy PGN wiring)
  - tests/test_session.gd

#### What to build

Restyle the game-over panel to `docs/design/v0.1.0/png/GameOver.png`, `GameOverStates.png` and `GameOverCard.png` (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. The card matches `GameOverCard.png` over a dimmed final board: a head tinted by the result (green win, red loss, grey draw) with a trophy, flag or ½ icon, "You won!", "You lost" or "Draw" and the reason; both players with their avatars, the winner ringed in gold; the match score ("2 – 1", halves as ½) labelled "Match".
2. The main button reads **"Review"** (Bruno's decision, not the canvas's "Game Review"), with the star icon and the canvas's green style. Below it, "New game" and "Rematch". New game returns Home as today; the canvas's "New 3+2" is not adopted.
3. A Copy PGN icon at the top left copies the game's PGN, as the review's Copy PGN does; the ✕ at the top right closes the card.
4. The loss and draw variants match `GameOverStates.png`.
5. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the three boards.

#### Verification

    Manual: win, lose and draw a game; use Copy PGN and ✕ on the card.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: the card's Copy PGN puts the game's PGN on the clipboard; the main button reads "Review" (red: no Copy PGN on the card).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. The "Review" label is Bruno's decision of 2026-10-29, confirmed 2026-10-31.

- 2026-10-31 Stage 2: card copy, score, result variants and focused-button Space covered by session tests. Updated `test_checkmate_opens_review_with_result_and_both_sides_moves` and `test_review_opens_for_no_move_resignation_flag_and_claimed_draw` for the new card text; the updated assertions were red against the old text before the final fix.
- Screenshot evidence (fixture): `C:/Users/bruno/AppData/Local/Temp/pchess-ui024-variants-f3ec8047-e7ac-4ac7-8baa-9dd1e98f79e4/win.png`, `loss.png`, `draw.png` at 1280x800 and `small.png` at 800x600. The screenshot fixture constructs the card directly, so the displayed 0-0 score, resignation reason and surrounding panel do not represent a completed interactive match.
- Visual differences from the reference: the shared flag icon is outlined, the shared robot icon differs from the canvas robot, and the card has no drop shadow. Long player names can be clipped in the fixed-width name label.
- Acceptance: pending | Play win, loss and draw; verify real Copy PGN and close, and assess the recorded visual differences and long player names.
- Disclosure: pending | integration | Review the recorded visual differences and long-name clipping against the design and usability criteria; see the screenshot evidence above.
- Disclosure: pending | release | Manual win/loss/draw, real clipboard and close acceptance remains outstanding; see the ticket verification above.
- Gate: `godot --headless -s tests/run.gd`: 422 reported passed, 0 failed; 7 reported passes were skipped (six Lc0-dependent tests and one graphical pixel test), so 415 executed. The first run failed only on the old review text expectations; these were updated before the successful run.

#### Resolution (2026-10-31, stage-3 review)
Verdict: Reopen — criterion 5: accepted long player names are silently clipped.

##### Standards

Zero findings. Independent reviewer `/root/standards` examined all five files in `1a9c2d43b1bc5ff063b2d60d58019c9e092ff23d...5eecbb6abd115a3ae9f31bdea5cce7ee4bd02aff`: this ticket, `tests/test_review.gd`, `tests/test_session.gd`, `ui/game_over.gd` and `ui/game_over.tscn`. OCR delegation excluded all five as `unsupported_ext`; each was reviewed directly, for coverage 5/5 (100%), zero skipped. No documented-standard violations or actionable baseline smells were found.

All eight commits separate tests, production and tracker metadata. Test-only `1814769`, `341a11c` and `b4fc591` precede production-only `f1870b6`; test-only `64e7012` precedes the wording correction in `9cd93b2`. The extra `tests/test_review.gd` changes update only assertions on behavior criterion 1 replaces, as explicitly allowed by `ticket-flow/stage2.md`. Production remains within Primary files. No production repair was authored during review.

##### Spec

- ✅ Criterion 1: the card is centered over the dimmed final board with human-relative result, reason, result tint/icon, both avatars, the correct winner's gold ring and numeric match score. The real-scene graphical probe checked all six human-color/result combinations. Existing tests cover match-score accumulation, halves and rematch color swaps. Shared typography remains subject to the already open CLEAN-012 integration condition below.
- ✅ Criterion 2: Review retains the star/green style and opens the existing analysis route; New game returns Home; Rematch preserves the match and swaps colors. The labels follow Bruno's recorded override.
- ✅ Criterion 3: the top-left Copy PGN reuses Review's prepared PGN, and the top-right Close hides the card. A graphical probe activated Copy PGN with focused Space, read the actual Windows clipboard and restored its prior content; a viewport mouse press/release closed the card. The clipboard comparison normalizes Windows CRLF; the initial strict comparison was a probe error, not a product defect.
- ✅ Criterion 4: loss/draw tints, flag/half icon and the winner/no-winner ring variants are present. The documented outlined flag, shared robot and absent shadow remain visual departures using the existing assets/native card styling; they do not add a separate behavioral finding. The reference sample names, scores and end reasons are illustrative.
- ❌ Criterion 5, **P2**, `ui/game_over.tscn:178-188` (especially `clip_text = true` at line 187): save the valid name `Alexandria Catherine Montgomery de Albuquerque`, finish a game and view its card at 800x600. The text measures 337 px, but HumanName is 112 px wide at `(110,329)` with centered alignment, no ellipsis (`text_overrun_behavior = 0`) and no tooltip. Both ends are silently cut, leaving only a middle fragment of the player's identity. This fails shared acceptance 2, "nothing clipped or overlapping", and was independently confirmed by `/root/spec` after the graphical evidence. Keep the bounded label, show ellipsis, preserve the full stored name, and add a red-first regression at the existing `tests/test_session.gd` card seam. A tooltip containing the full name is a suggested small improvement, not a new numbered requirement. Evidence: `C:/Users/bruno/AppData/Local/Temp/pchess-ui024-stage3-1793484465401/long-name-800.png`, `probe.gd` and `probe3.log` in that directory.

Standards: 0 findings. Spec: 1 P2 in criterion 5. All other examined implementation paths retain approval; stage 2 resumes only the ❌ item on this branch.

##### Coverage and verification

Reviewed the complete diff and both card creation sites, `main._show_result()` and `scripts/screens.gd`; checkmate, resignation, time and draw result routes; Review's PGN preparation/export and analysis opening; half-point score formatting; rematch/Home/reset; card lifetime/disposal; and Settings/input arbitration. Every real result creates a fresh card, so conditional icon/ring setup cannot inherit an earlier card's result. No identified caller or failure route was left unexamined. Physical keyboard/mouse use, a played Lc0 game, audio and Bruno's final visual acceptance remain unexecuted.

`Assert-GateEvidence` passed against reviewed HEAD: correct command, exit 0, unchanged log SHA-256 and identical non-tracker code since tested `9cd93b2fa4030676483b6354c2cb057312a38956`. The log has 422 reported passes, 0 failures, 7 skips (six Lc0-dependent tests and one graphical pixel check): 415 executed. Code did not change during review, so the gate was reused rather than rerun. The focused graphical probe exited 0: actual clipboard Copy with Space, mouse Close and all six color/result icon/ring cases passed; it also recorded the long-name defect above. Synthetic viewport input and real clipboard access do not constitute physical-input or end-to-end gameplay acceptance.

##### Before / reference / after screenshots

The following stage-3 captures use the screenshot tool at 1280x800 and 800x600. Before is detached session base `1a9c2d43`; After is reviewed HEAD `5eecbb6`. Before and After folders are `C:/Users/bruno/AppData/Local/Temp/pchess-ui024-stage3-1793484465401/before/` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui024-stage3-1793484465401/after/`. Each filename below exists in both folders.

| Board/state | Reference | Before and After filenames (1280x800 / 800x600) |
|---|---|---|
| GameOver | [reference](../../../docs/design/v0.1.0/png/GameOver.png) | `GameOver--1280.png` / `GameOver--800.png` |
| GameOverCard | [reference](../../../docs/design/v0.1.0/png/GameOverCard.png) | `GameOverCard--1280.png` / `GameOverCard--800.png` |
| GameOverStates, loss | [reference](../../../docs/design/v0.1.0/png/GameOverStates.png) | `GameOverStates-loss-1280.png` / `GameOverStates-loss-800.png` |
| GameOverStates, draw | [reference](../../../docs/design/v0.1.0/png/GameOverStates.png) | `GameOverStates-draw-1280.png` / `GameOverStates-draw-800.png` |

The component fixtures capture the full game screen: compare their card region to the component reference. As disclosed by stage 2, these fixtures build a card directly, leaving a synthetic 0-0 score, resignation reason and surrounding panel; they are layout evidence, not completed-match evidence. The separate long-name screenshot uses the real session/result path. Data and logs were isolated from the player's files, and the temporary before worktree was removed after capture.

Acceptance: pending | Repair criterion 5, complete CLEAN-012, then perform final visual and real win/loss/draw play acceptance.
Disclosure: pending | integration | This open UI-024 ticket schedules the P2 long-name repair before integration; no accepted deferral is recorded.
Disclosure: pending | integration | [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) still requires corrected shared font weights before the session PR lands on main and before final visual acceptance; this review does not waive that existing condition.
Disclosure: pending | release | Real win/loss/draw gameplay, physical input, Lc0, audio and final human visual QA remain. The focused real-clipboard/viewport-Close checks above supplement the previous evidence.

No merge, push or ledger entry. UI-024 returns to `to-implement` on its retained branch.

#### Stage 2 retry (2026-10-31)

- Corrected the reopened criterion 5: the bounded player-name label now uses the same ellipsis behavior as other screens, retaining the full displayed value and saved preference.
- `test_game_over_long_player_name_is_visibly_truncated` failed before the fix (`expected 3, got 0`) and passed after it. Test-only commit `7db35c9`; production-only commit `33244ba`.
- Gate `godot --headless -s tests/run.gd`: exit 0, 423 reported passes, 0 failures, including 7 skips (six Lc0-dependent tests and one graphical pixel test), so 416 executed.
- Acceptance: pending | Stage 3 must review the long-name correction and CLEAN-012 remains an integration condition. Real win/loss/draw, physical input, Lc0, audio and final visual acceptance remain pending as recorded above.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/pchess-ui024-long-name-gate.json

#### Resolution (2026-10-31, long-name re-review)
Verdict: Approve

##### Standards

Zero findings. Independent reviewer `/root/standards` examined all three changed files in `5eecbb6abd115a3ae9f31bdea5cce7ee4bd02aff...79b776186158663af002126ac133637ada35c1e3`: this ticket, `tests/test_session.gd` and `ui/game_over.tscn`. OCR delegation excluded all three as `unsupported_ext`; each was reviewed directly using the resolved rule group, for coverage 3/3 (100%), zero skipped. No documented-standard violations or actionable baseline smells were found. Test-only `7db35c9` precedes production-only `33244ba`; reopen/handoff commits contain tracker metadata. The added test and production correction stay within Primary files. No production changes were authored during this review.

##### Spec

- Previous criterion-5 P2 resolved: HumanName now uses `TextServer.OVERRUN_TRIM_ELLIPSIS` inside its existing 112 px width. Fresh graphical captures of the real session/result path show `Alexandria Cat...` at both 800x600 and 1280x800, rather than a silently clipped middle fragment. The full label value and saved preference remain unchanged; the short name `You` remains fully visible.
- `test_game_over_long_player_name_is_visibly_truncated` exercises real card creation and checks the full label text, saved name and ellipsis mode. Stage 2 recorded the pre-fix failure (`expected 3, got 0`); the validated green gate records this regression passing. The commit order preserves the red-first handoff.
- Independent reviewer `/root/spec` found no missing behavior, scope creep or new defect in the delta. Examined context includes `game_over.present()`, `main._show_result()`, screenshot-tool card construction, settings validation and existing ellipsis usage. Criteria 1-4 retain the previous review's approval; criterion 5's UI-024 long-name defect is now resolved. CLEAN-012 and final product acceptance remain separately scheduled below.

Standards: 0 findings. Spec: 0 remaining UI-024 findings. The earlier complete five-file review and before/reference/after table remain the evidence for the unchanged redesign; this re-review covers all added changes and the previous P2.

##### Graphical evidence

Fresh isolated-data probe: `C:/Users/bruno/AppData/Local/Temp/pchess-ui024-rereview-8412bb1e-e3eb-47d2-bda9-c7937e8a3d86/probe.gd`, `probe.log` and `godot.log`. It checked long/short names at both window sizes, full-name preservation, ellipsis mode, the bounded label and card containment; all four cases passed, exit 0. The long-name images and the 800x600 short-name image were visually inspected. These captures use the real result route with the existing held-engine test fixture, not completed Lc0 gameplay.

| Case | Before | Reference | After |
|---|---|---|---|
| Long name, 800x600 | [previous P2](C:/Users/bruno/AppData/Local/Temp/pchess-ui024-stage3-1793484465401/long-name-800.png) | [card reference](../../../docs/design/v0.1.0/png/GameOverCard.png) | [ellipsis](C:/Users/bruno/AppData/Local/Temp/pchess-ui024-rereview-8412bb1e-e3eb-47d2-bda9-c7937e8a3d86/long-800.png) |
| Long name, 1280x800 | Prior full-screen table above | [card reference](../../../docs/design/v0.1.0/png/GameOverCard.png) | [ellipsis](C:/Users/bruno/AppData/Local/Temp/pchess-ui024-rereview-8412bb1e-e3eb-47d2-bda9-c7937e8a3d86/long-1280.png) |
| Short name | Prior full-screen table above | [card reference](../../../docs/design/v0.1.0/png/GameOverCard.png) | [800x600](C:/Users/bruno/AppData/Local/Temp/pchess-ui024-rereview-8412bb1e-e3eb-47d2-bda9-c7937e8a3d86/short-800.png), [1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui024-rereview-8412bb1e-e3eb-47d2-bda9-c7937e8a3d86/short-1280.png) |

##### Verification and session delivery

`Assert-GateEvidence` passed at reviewed HEAD, after the no-op rebase onto `sweatshop/ui-game/2026-10-31-1734`, and after the session merge. It verifies the bound command, exit 0, unchanged log SHA-256 and identical non-tracker code against tested commit `33244ba1329e24236552188e0c5a99b332800c59`. The log reports 423 passes, 0 failures, including seven skips (six Lc0-dependent tests and one graphical pixel test): 416 executed. Existing warnings include anchor sizing and deliberately malformed fixture data; no error or failed test was recorded. The gate was reused because code did not change. The focused graphical probe above supplements the headless evidence.

The existing [UI-022 workflow decision](74-UI-022-home-name-dialog-searching.md#resolution-2026-10-31-long-name-re-review), with verified proxy receipt `C:/Users/bruno/AppData/Local/Temp/sweatshop-proxy/20261031-181515-UI-022-7181c6.json`, permits session consolidation while CLEAN-012 holds integration of the session PR into `main`. No contract change or product waiver was made here.

Merged without squashing into `sweatshop/ui-game/2026-10-31-1734` as `a6ba31e4f476b9eeb9fc6d2e55e8cbce2a12f836`. This closure changes only the ticket and ledger. The driver owns pushing and opening the session PR.

Acceptance: pending | Final visual comparison after CLEAN-012, real win/loss/draw gameplay, physical input, Lc0 and audio remain pending. The previous review's real-clipboard and synthetic Close evidence remains recorded above.
Disclosure: decision | none | The previous UI-024 criterion-5 P2 is resolved by this re-review and session merge; all other implementation approvals stand. The previously recorded icon/shadow differences remain documented, with final visual acceptance pending.
Disclosure: pending | integration | [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) must be completed and reviewed before this session PR lands on `main` and before final visual acceptance. The existing UI-022 workflow decision permits consolidation into this session only.
Disclosure: pending | release | Complete real win/loss/draw gameplay, physical input, Lc0, audio and final human visual QA. This re-review adds graphical name-overflow checks, not physical-input or end-to-end gameplay acceptance.
- 2026-10-31 Foreman acceptance check on session be29801: headless gate 416 executed, 0 failed, 7 skipped. Before/after/reference captures and the long-name re-review shots copied to `.artifacts-build/ui-game-screens/UI-024/` in the main checkout (ignored).
Acceptance: pending | Visual comparison after CLEAN-012; real win/loss/draw, Copy PGN and close.
- 2026-10-31 PR #36 fidelity pass (pr-review-loop, round 0): [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) merged to `main` in PR #37 (0635b3d) and into this branch, so the integration condition below is met. Fresh 1280x800 captures still differed from the canvas; fixed in e409f39. The broken GameOver capture was the fixture: `scripts/screens.gd` skipped the game setup (flip, move list, Settings hidden) for the game-over boards; they now replay it and end through `main._show_result()`. Card: Review star and label centred together, New game/Rematch weight 700 on #45423d with the inset edge, Review with its inset edge, filled flag on a loss. Before: `%TEMP%/pr36-before/<Board>.png`; after: `%TEMP%/pr36-after/<Board>.png` (800x600: `%TEMP%/pr36-after-800/`); reference `docs/design/v0.1.0/png/<Board>.png`. Copies under `.artifacts-build/ui-game-screens/pr36-fidelity/` in the main checkout (ignored).
- Remaining, by behaviour: after the game the side panel's Offer draw, Resign and Claim draw are disabled and both clocks idle, where the canvas draws them live; the card keeps "Review" and "New game" (Bruno and the spec).
Disclosure: resolved | integration | CLEAN-012 merged in PR #37.
Acceptance: pending | Visual comparison of the after captures; real win/loss/draw, Copy PGN and close.
