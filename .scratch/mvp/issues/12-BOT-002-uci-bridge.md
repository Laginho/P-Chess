# BOT-002: UCI bridge and Maia's policy
Stage: to-implement
Blocked by: CORE-001, CORE-003
Review: agent
Difficulty: hard

- Primary files:
  - New: engine/uci.gd
  - New: tests/test_uci.gd
  - New: tests/fixtures/lc0_verbose.txt

#### What to build

`engine/uci.gd` runs Lc0 over UCI and returns Maia's policy, a probability for every legal move (§3.2). It speaks generic UCI, so a second engine can be added later without touching the game code.

#### Acceptance criteria

1. Lc0 starts once with `OS.execute_with_pipe`; the bridge sends `uci`, waits for `uciok` and sets `VerboseMoveStats=true`. Its output is read on a worker thread; the main thread never blocks on it.
2. Changing the level sends `ucinewgame`, `setoption name WeightsFile value <net path>` and `isready`, and waits for `readyok`. Every new game also sends `ucinewgame`.
3. A policy request sends `position fen <start fen> moves <uci moves>` and `go nodes 1`, and returns a map from each legal move to its `P:` probability (0–1), delivered on the main thread after `bestmove`.
4. The parser of the `info string` lines is a pure function, tested on a recorded Lc0 output fixture, with no Lc0 process.
5. The bridge finds `engine/lc0/lc0.exe` next to the executable, or in the project root when run from the editor. When it is missing, the bridge reports itself unavailable with a message that names `scripts/fetch-engine.ps1`.
6. The Lc0 process is stopped when the app exits.
7. Integration test, skipped with a message when Lc0 is absent (as on the CI runner): switching from `maia-1100` to `maia-1900` changes the policy for one position.

#### Verification

    godot --headless -s tests/run.gd   # locally, with engine/ present, the integration test runs

## Tests stage 2 writes (own commit, red)

- `tests/test_uci.gd`: the parser on the fixture (every legal move present, probabilities summing to about 1), the engine-path lookup, and the level-switch integration test. Red because `engine/uci.gd` does not exist.

## Comments
