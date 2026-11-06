# REV-010: Only a complete analysis cache counts as analysed
Stage: to-implement
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
