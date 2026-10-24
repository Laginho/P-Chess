# BOT-004: Play a game against Maia
Stage: to-implement
Blocked by: UI-001, BOT-002, BOT-003
Review: agent
Difficulty: normal

- Primary files:
  - New: bot/maia_player.gd
  - New: ui/setup.tscn, ui/setup.gd
  - ui/main.tscn, ui/main.gd
  - New: tests/test_maia_player.gd

#### What to build

The first game against the bot (M3): a minimal setup picks colour and level, and Maia answers every move with a move sampled from its policy. No clocks yet; Maia replies as soon as Lc0 answers.

#### Acceptance criteria

1. A setup screen picks colour (white / black / random) and level (`maia-1100` … `maia-1900`); Start begins a game.
2. After each human move, Maia plays a legal move picked by `bot/move_picker.gd` from Lc0's policy, with the default `τ` and `T` and every book weight 1.
3. When Maia is white, it plays the first move.
4. From the human's move to Maia's move on the board takes under 50 ms (median over a full game, logged at the end).
5. The UI keeps drawing while Lc0 works; dragging stays smooth.
6. When the engine is missing, the setup screen shows how to run `scripts/fetch-engine.ps1` instead of Start.
7. `bot/maia_player.gd` picks only legal moves even if the policy holds an illegal one (tested with a fake policy, no Lc0).

#### Verification

    Manual: a full game against maia-1500 as each colour; read the logged median.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_maia_player.gd`: with a fake bridge returning a fixed policy and a seeded RNG, Maia's move is legal and repeatable, and an illegal policy entry is ignored. Red because `bot/maia_player.gd` does not exist.

## Comments
