# BOT-002: UCI bridge and Maia's policy
Stage: to-review
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
- 2026-10-24 Attempt 2, question asked of the proxy instead of the human: criterion 4 wants a *recorded* Lc0 fixture, and no Lc0 is reachable from this session (no `engine/` in the lane worktree, BOT-001 still `to-implement`, not on PATH, the sandbox blocks the main checkout, WebFetch to Lc0's source is not permitted). Build now on a fixture rebuilt from the format, or block?
- Proxy decided (opus): option A — build engine/uci.gd and the parser now on a fixture rebuilt from Lc0 v0.32.1's VerboseMoveStats format and labelled as rebuilt; Acceptance pending with integration impact until the fixture is re-recorded from real Lc0 and the integration test runs where engine/ exists — the byte format is the only thing that can't be checked here, and the live integration test checks it, while blocking would leave a fully specified ticket idle behind BOT-001 (Review: human, not running tonight). Conditions: no junctions, downloads or sandbox workarounds; the fixture header says it is rebuilt and lists the UCI lines to re-record it; castling written king-takes-rook (`e1h1`) is normalised to the king's move only when the from-square holds the mover's king, both spellings tested and a rook's `e1h1` left alone; the c7 test also checks that the live keys are exactly the legal moves on a castling position and sum to about 1; `P:` is read by its field, and the `node` line is skipped.
- Stage-1 question for Bruno (not decided here): Lc0's `PolicyTemperature` scales the printed `P:`, and v0.32.1's default is not 1. The bridge leaves it at Lc0's default because no criterion sets it. The τ cut and T (§3.3), the premove check (top move over 0.9, §4.1) and the BOT-007 calibration all read `P:`, so whichever value is chosen, the bridge and BOT-007 must use the same one.
- 2026-10-24 Stage 2, one red/green cycle, criteria 1–7: red on 860d6fd (`res://engine/uci.gd` does not exist, so `test_uci.gd` fails to load; 29 passed, 1 failed), green on 6fa31c3 (34 passed, 0 failed; the c7 integration test prints `SKIP ... no engine/lc0/lc0.exe, run scripts/fetch-engine.ps1` and returns). Mutant with the castling normalisation removed: 2 tests fail (fixture keys miss `e1g1`/`e1c1`, sum 0.6155; black `e8h8` dropped). The process and thread path (`start`, `_read`, `stop`) did not run here: no Lc0, and copying `cmd.exe` as a stand-in engine needed approval. A scratch smoke run, not committed, drove the command queue with a file in place of Lc0's stdin and injected replies: `uci` → (uciok) → `setoption name VerboseMoveStats value true`, `ucinewgame`, `setoption name WeightsFile value …`, `isready` → (readyok) → `position fen … moves …`, `go nodes 1` → (bestmove) → the next request; stray `info string` lines outside a search were ignored, and each `bestmove` emitted one policy from `poll()`.
- API for BOT-004: `engine/uci.gd` is a Node; add it to the tree so `_process` calls `poll()`, and freeing it (with the tree at exit) kills Lc0 and joins the reader threads (c6). `start(dirs := search_dirs()) -> bool`; on false, `available` is false and `error` names `scripts/fetch-engine.ps1`. `set_level(net_path)` (the caller builds `engine/weights/maia-<level>.pb.gz`), `new_game()`, `request_policy(start_fen, uci_moves)` → `policy_ready(policy)` with legal move → 0–1. Commands queue and each waits for its reply, so requests made before `uciok`/`readyok` go out in order once it arrives. `parse_policy(lines, board)` and `engine_path(dirs)` are static and pure.
- Callers and degenerate inputs: nothing calls `uci.gd` yet; `Board` is used read-only (`from_fen`, `make_move`, `legal_moves`, `piece_at`). An empty move list sends `position fen <fen>` without `moves` (smoke-tested). A position with no legal moves parses to `{}`. `request_policy` with a FEN that `Board.from_fen` rejects fails on a null board, like `Game.new` (CORE-004 deferral); its callers pass the game's FEN. Not handled, by the "starts once" contract: `start()` after `stop()` keeps any request that was in flight.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\claude\D--Desktop-Projects-P-Chess--artifacts-build-lanes-core\c06177d2-6e96-40df-8613-52ccc195e595\scratchpad\BOT-002-gate.json

Acceptance: pending | tests/fixtures/lc0_verbose.txt is rebuilt, not recorded (c4), and the c7 integration test skipped here (no Lc0). Still to do: re-record the fixture from Lc0 v0.32.1 with the UCI lines in its header, then run the gate locally with engine/ present.
Disclosure: pending | integration | Proxy decided (opus), see ## Comments: the c4 fixture is rebuilt from the v0.32.1 format, not recorded. Resolve before the session PR is integrated. If the parser fails on real output, BOT-002 goes back to to-implement.
