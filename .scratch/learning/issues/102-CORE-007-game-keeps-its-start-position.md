# CORE-007: A game keeps its start position, and Maia plays from it
Stage: implementing
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
