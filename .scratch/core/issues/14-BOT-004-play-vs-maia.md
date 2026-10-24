# BOT-004: Play a game against Maia
Stage: implementing
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

- 2026-10-24 From the BOT-002 review (a note, not a criterion until stage 1 folds it in):
  - Question for Bruno: Lc0 v0.32.1's default `PolicyTemperature` is not 1. `engine/uci.gd` leaves it at that default, so the `P:` it returns is flatter than Maia's raw policy. c2's τ/T (§3.3), the 0.9 premove check (§4.1) and BOT-007's calibration all read `P:`. Pick one value, and if it is not Lc0's default, set it in the bridge. BOT-007 must use the same value.
  - `engine/uci.gd` has no timeout and does not notice Lc0 exiting. A bad `WeightsFile` path or a crash leaves requests queued forever, with `available` still true, so Maia would never move and c6 would not catch it.
- 2026-10-24 From the UI-002 review (a note, not a criterion until stage 1 folds it in): Maia's move will reach the board through `BoardView.play()`, and BOT-004 is its first caller. `play()` does not handle a piece the human is holding, or a promotion picker that is open. While Maia is to move, `_pick_up` lets the human pick up Maia's pieces, because they belong to the side to move. If Maia's move arrives at that moment, the old target dots stay on the board and the next drop can play a move from an earlier position. With the picker open, it records an illegal SAN in the move list. Stage 1 has two ways to fix it, and either one needs `ui/board_view.gd` in this ticket's Primary files: stop the human picking up Maia's pieces, or make `play()` drop the held piece and close the picker. Details are in UI-002's Resolution.
- 2026-10-24 Deferral accepted (Bruno, human; relayed by the supervising foreman session): criterion 4's latency measurement (Maia's median reply under 50 ms) is deferred until the machine is idle. His words: "deixa a parte do tempo de resposta pra depois, porque as lanes + outro projeto nesse mesmo pc vão causar bastante ruído. tem como deixar isso pra depois? aí a gente testa o tempo quando não estiver mais nada rodando". Why: three sweatshop lanes and another project share this PC, so the 74–106 ms the reopening review measured (and the 16–160 ms spread stage 2 saw) cannot separate the code from the load. Impact: release, not integration. c4 no longer blocks this ticket's review or its merge into the session; it becomes a pending manual check (measure the windowed median with nothing else running), carried by stage 3 as `Acceptance: pending` and a `Disclosure: deferred | release` line, and listed in the session PR. A change to Lc0's thread options in `engine/uci.gd`, or a proxy request to add that file, made only to meet c4 is no longer needed; work already done is reviewed as usual, not discarded.
