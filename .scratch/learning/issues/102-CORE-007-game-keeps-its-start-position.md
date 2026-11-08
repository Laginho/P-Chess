# CORE-007: A game keeps its start position, and Maia plays from it
Stage: to-review
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/game.gd (`_init`, a stored start FEN)
  - bot/maia_player.gd (`think`: the `Game.START` shortcut)
  - tests/test_maia_player.gd
  - tests/test_rules.gd (only if a Game construction assertion needs the new field)

#### What to build

Play-outs start from a FEN (spec §L8). Today `Game.new(fen)` accepts a FEN but forgets it, and `MaiaPlayer.think()` always asks the engine for the policy from the initial position (its `shortcut:` comment). A game must remember the position it started from, and Maia must ask for its policy from there.

#### Acceptance criteria

1. `Game.new(fen)` keeps `fen` as the game's start position; `Game.new()` keeps `Game.START`.
2. `MaiaPlayer.think()` requests the policy with the game's start position and its moves, for a game from a FEN as for a normal game, including the case where it re-requests for the previous position.
3. Games from the initial position send exactly the same requests as before (the existing `test_maia_player.gd` request assertions still pass unchanged).
4. The `shortcut:` comment in `think()` is gone.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_maia_player.gd`: a game built from a rook-endgame FEN makes `think()` request `[that FEN, moves]` (red: it requests `Game.START`).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L8. Found by the code survey: `bot/maia_player.gd` lines 98–101.
- Stage 2: test commits `734c147` and `0f9668d` failed before production changes (11 passed, 1 failed): the start field was absent and both requests used `Game.START`. The second test-only commit corrected the first assertion's timing: the fake retains the mutable moves array, so the initial request must be checked before moves are played. Production commit `9a75f8e` made the focused suite green (12 passed, 0 failed).
- Criteria check, read-only subagent:
  - ✅ 1: `core/game.gd:24-25` stores the supplied or default FEN; `tests/test_maia_player.gd:119-123,132` checks both and retention after moves.
  - ✅ 2: `bot/maia_player.gd:96-98` requests both positions from that FEN; `tests/test_maia_player.gd:127-135` checks empty and nonempty histories.
  - ✅ 3: the same production lines preserve the default; unchanged request assertions in `tests/test_maia_player.gd:58-68,108-115` cover the initial game.
  - ✅ 4: diff inspection confirms the shortcut comment is removed; this structural criterion has no behavioral test.
- Gate on `9a75f8e`: `godot --headless -s tests/run.gd` exited 0, 570 passed, 0 failed. Seven checks reported skips: one graphical pixel check and six requiring Lc0. No live-engine or graphical acceptance was performed.

Gate evidence: /run/media/lage/New Volume/Scratch/core-007/gate.json
