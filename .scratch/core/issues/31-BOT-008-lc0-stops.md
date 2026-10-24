# BOT-008: Say so when Lc0 stops
Stage: to-implement
Blocked by: BOT-004
Review: agent
Difficulty: normal

- Primary files:
  - engine/uci.gd
  - ui/main.gd
  - tests/test_uci.gd

#### What to build

If Lc0 dies during a game (a crash, or a net it cannot load), the player is told and sent back to the setup screen, instead of waiting forever for Maia's move. Today `engine/uci.gd` never notices: requests stay queued and `available` stays true. Found in BOT-002's review, carried by BOT-004 (see both Resolutions).

#### Acceptance criteria

1. When the Lc0 process exits on its own, the next `poll()` leaves `available` false, `error` set to a message saying Lc0 stopped, the queue empty, and emits `stopped`. The app's own `stop()` does not emit it.
2. A net Lc0 cannot load (`set_level` with a path that does not exist) ends the same way, not in a wait for `readyok` that never comes.
3. On `stopped`, `ui/main.gd` ends the game and shows the setup screen with `error` in place of Start, as BOT-004 c6 does when Lc0 is missing.
4. Tested live, skipped where `engine/` lacks Lc0 as in BOT-002 c7: killing Lc0's `pid` outside `stop()`, and a missing net path, each give `stopped` within 10 s of polling.

#### Verification

    Manual: in a game against Maia, end lc0.exe in Task Manager; the setup screen shows the error.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_uci.gd`: the two live cases of c4. Red because the bridge never reports a stop.

## Comments

- 2026-10-24 Created at BOT-004's close (Proxy decided (opus), BOT-004 ## Comments). No general reply timeout is asked for: the first net load took 15.5 s on a loaded machine (BOT-004 Review), so a short one would kill a healthy Lc0. If c2 needs one, put it on the `readyok` wait only and record the value here.
- The proxy did not check what Lc0 v0.32.1 does with a `WeightsFile` that does not exist (exit, an `error` line, or silence), so c2 states the outcome, not the mechanism. If Lc0 instead finds another net and answers `readyok`, c2 cannot hold: stage 2 stops and asks.
- If Bruno answers PolicyTemperature (BOT-007 ## Comments) before this ticket starts, stage 1 may fold its `setoption` line into a criterion here, since `start()` is in this file.
