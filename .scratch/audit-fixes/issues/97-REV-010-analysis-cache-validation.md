# REV-010: Only a complete analysis cache counts as analysed
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: hard

- Primary files:
  - engine/analyser.gd (`read_analysis`)
  - ui/review.gd (the four `read_analysis` sites, around :891, :932, :990 and :1472, and the length/FEN checks next to them)
  - ui/history_screen.gd (`_cached_accuracy` at :743, and the read at :734)
  - ui/profile.gd (`_complete_analysis` at :115, and the read at :89)
  - tests/test_analyser.gd, tests/test_review.gd, tests/test_history_screen.gd, tests/test_profile.gd

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 3. `read_analysis` checks only the engine version and node budget, and Review adds only a length check. A cache with empty PVs or missing scores therefore reaches classification and accuracy and raises script errors. History and Profile validate more on their own, so they already call the same cache stale. Move the full check into `read_analysis` so every reader agrees.

#### Acceptance criteria

1. `Analyser.read_analysis` takes the expected position FENs and returns `{"state": "stale"}` unless all of these hold:
   - the cache has exactly that many positions;
   - each position is a dictionary whose `fen` matches the expected one;
   - each position has the scores and PV structure that classification and accuracy read: a non-terminal position has a non-empty PV with a score, and a terminal one has its terminal score.

   Its other results are unchanged: `not analysed`, `stale` on metadata, and `analysed` with `data`.
2. Review, History and Profile use it at every read site and drop their own copies of these checks: the shape checks in `_cached_accuracy` and `_complete_analysis`, and Review's length and per-position FEN comparison. The site at review.gd :932 keeps its own engine id.
3. Opening a saved game whose cache matches the metadata but has a missing score, an empty non-terminal PV, a non-dictionary position or a wrong FEN shows the stale/unanalysed state with the usual offer to analyse. No script error is logged.
4. A valid cache loads as today without starting Stockfish. History and Profile show the same accuracy as today for valid caches.
5. Incremental, not-yet-scored live data (REV-008/REV-009 side lines, analysis in progress) is not read through this check and keeps working.
6. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_analyser.gd: one cache per invalid shape reads as `stale` (red: `analysed`). The shapes: a missing `terminal_score`, an empty non-terminal `pv`, a non-dictionary position, one position too few, and a FEN that differs. A valid cache still reads `analysed`.
- tests/test_review.gd, with a fake engine: opening a game with one of those caches shows the stale state, starts no engine and leaves no script error. A valid cache loads without starting the engine.

## Comments

- 2026-11-06 Written from the grill ([spec](../spec.md)). Bruno chose to put the validation in `read_analysis` with the expected FENs (Q7).
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)

#### Stage 2 implementation (2026-11-06)

- `read_analysis` now requires the expected FENs, exact position count and matching FEN strings. It rejects malformed positions, missing or non-numeric/non-finite scores, malformed PV lines/move arrays and missing `best_move`. An empty PV needs a numeric terminal score and can only occur at the final position, since classification reads the preceding position's first PV. A final draw with legal moves remains valid.
- All four Review reads, History and Profile pass the game FENs through the shared validator. Review keeps `_analysis_bridge.engine_id` at `_check_engine`; duplicated length/FEN checks and Profile's `_complete_analysis` are removed. Incremental `receive_position` and live side-line paths are unchanged.
- History preserves its existing metadata-stale accuracy display: `_analysis_text` checks current metadata, while `_cached_accuracy` validates the complete cache using its recorded metadata before evaluating accuracy. The existing old-engine accuracy test remains green.
- Tests exercise malformed positions/PVs/scores/FEN types, missing terminal score, too few/many positions, wrong FEN, valid terminal draws and valid caches. The saved-game Review test opens six invalid shapes and a valid cache with a fake engine factory: invalid caches offer analysis, the valid cache shows its summary, no factory is called and the runner records no script error.
- Test-only contract adaptations: the two `read_analysis` assertions in `tests/test_history.gd` now supply expected FENs, as permitted by stage2.md for tests of a replaced interface. Profile's cache helper and Review's 80-ply layout fixture now write complete FEN/PV/best-move data; their existing assertions remain intact. Profile also rejects a complete cache whose second FEN belongs to another position.
- Red/green: `566b94e` reproduced nine accepted malformed positions (11 passed, 1 failed); `5e9309a` passed all 12 analyser tests. `01f42a4` reproduced accepted short/long/wrong-FEN caches (12 passed, 1 failed) and the Review wrong-FEN failure (75 passed, 2 failed, including the old incomplete layout fixture). `51d6c03` adapts fixtures/callers; `767f39c` implements expected-FEN validation. `f7c5fb9` reproduced script errors comparing dictionary/numeric FENs; `f7dc4a8` checks their type first (13 passed, 0 failed). Logs: C:/Users/bruno/AppData/Local/Temp/REV-010-analyser-red.log, REV-010-fens-red.log, REV-010-review-red.log, REV-010-fen-types-red.log and REV-010-analyser-green.log in the same directory.
- Focused green checks: Analyser 13 passed, Profile 6 passed, History screen 18 passed; zero failures. The final gate also passed all 77 Review tests, including saved-cache opening, the adapted layout fixture and live side-line regressions.
- Final gate ran once at `f7dc4a8`: 564 passed, 0 failed, exit 0. One graphical pixel check and six live Lc0 checks skipped (headless display / missing engine). Full log: C:/Users/bruno/AppData/Local/Temp/REV-010-gate-20261106.log. No code changed after this run.

Acceptance: passed | The agreed automated seams in [spec](../spec.md) passed: direct cache reads and saved-game Review opening with a fake engine, plus existing History/Profile accuracy and live side-line tests.
Disclosure: pending | none | [Gate log](C:/Users/bruno/AppData/Local/Temp/REV-010-gate-20261106.log): graphical pixels and live Lc0 were skipped; no graphical or real-engine acceptance is claimed. The ticket's verification uses the agreed automated seams.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/REV-010-gate-20261106.json

#### Resolution (2026-11-06)
Verdict: Approve

- Reviewed the complete nine-file diff `601b778...d312c7d` and all eight implementation commits. No production fixes were authored during review. Test-only and production-only commits are separate; `tests/test_history.gd` is a permitted test-only adaptation to the replaced interface.
- Examined the analyser writer and shared reader; all four Review reads (including engine-id lookup and stop/queue restoration), both History reads and Profile; Classification, Accuracy and graph consumers; terminal draws, stale metadata, malformed positions/PVs/scores/FENs, saved-game opening and incremental/live side-line interactions.

##### Standards

No actionable findings. Repository guidance and the baseline smell review pass; the shared validator replaces duplicate shape checks, and caller changes propagate the expected-FEN contract.

##### Spec

No actionable findings or scope creep. Numbered criteria:

1. ✅ Exact count, matching FEN strings and required finite scores/PV structure are checked at `read_analysis`; missing files and stale metadata keep their existing states.
2. ✅ Every production read supplies expected FENs; duplicate checks are removed, and `_check_engine` retains its bridge engine id. History retains validated old-engine accuracy beside the stale state.
3. ✅ Saved-game tests reject malformed scores, terminal scores, PVs, positions, FENs and position counts, show the analysis offer and start no engine. The runner reports no script errors.
4. ✅ Valid saved caches load without an engine start; existing History/Profile accuracy tests pass in the verified gate.
5. ✅ Incremental receipt and live side-line paths are unchanged; their Review regression tests pass.
6. ✅ The existing gate receipt was validated against the tested commit, log hash, exit marker and unchanged code: 564 passed, 0 failed, exit 0 at `f7dc4a8`. The receipt remains valid after the conflict-free session integration; the gate was not rerun.

- Independently reran focused files, one at a time: Analyser 13 passed and Review 77 passed, zero failures or script errors. Logs: C:/Users/bruno/AppData/Local/Temp/REV-010-stage3-analyser.log and C:/Users/bruno/AppData/Local/Temp/REV-010-stage3-review.log, both exit 0. Inspected the recorded red failures for incomplete shapes, position count/FEN mismatch and invalid FEN types, and their later green gate evidence. `git diff --check` passed.
- Not examined here: graphical pixel behavior, real-engine acceptance, export/CI and History performance measurement (the latter remains HIST-007). The existing graphical/Lc0 skip disclosure and automated acceptance boundary remain in force.
- Integrated into `sweatshop/audit-fixes/2026-11-06-1433` with merge commit `0bc8bda7ba535867b37f0b2202e7d4884e773ccb`; no PR or push in this stage. Standards: 0 findings; Spec: 0 findings.
