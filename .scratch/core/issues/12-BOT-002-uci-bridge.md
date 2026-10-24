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

- 2026-10-24 Attempt 1 failed: exit 0. Log tail: ... `e1g1` or `e1h1`? A made-up fixture would hide exactly that. /  / The simplest fix is to link your engine files into this worktree. Both folders are gitignored, so nothing extra gets committed. Run these one at a time in PowerShell: /  / ```powershell / New-Item -ItemType Directory -Force 'D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core\engine' / ``` / ```powershell / New-Item -ItemType Junction -Path 'D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core\engine\lc0' -Target 'D:\Desktop\Projects\P-Chess\engine\lc0' / ``` / ```powershell / New-Item -ItemType Junction -Path 'D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core\engine\weights' -Target 'D:\Desktop\Projects\P-Chess\engine\weights' / ``` /  / Then tell me to continue. I'll record the fixture with `go nodes 1` on a position where castling is legal, and the integration test will actually run. /  / If you'd rather not, say "fabricate". I'll write the fixture by hand, label it as unverified in the ticket and skip the integration test. I'd advise against it. /  / There's also a separate `sweatshop/bot/2026-10-24-0159` lane, which has already finished BOT-003. If its driver is restarted it could pick up BOT-002 too, so keep this ticket to one lane.
