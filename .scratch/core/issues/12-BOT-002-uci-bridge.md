# BOT-002: UCI bridge and Maia's policy
Stage: blocked
Blocked by: CORE-001, CORE-003, BOT-001
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
Disclosure: pending | release | Stage-1 question above, unanswered: Lc0 v0.32.1's default `PolicyTemperature` is not 1, so the `P:` the bridge returns is flatter than Maia's raw policy, and §3.3's τ/T, §4.1's 0.9 premove check and BOT-007 all read it. Moved for Bruno to BOT-004 `## Comments` (.scratch/core/issues/14-BOT-004-play-vs-maia.md), the next ticket that consumes `P:`.
Disclosure: deferred | release | Found in review, outside the criteria: the bridge has no timeout and does not notice Lc0 exiting. A bad `WeightsFile` path or a crash leaves the queue waiting forever, with `available` still true and no `error`, so Maia would never answer. Routed to BOT-004 `## Comments`, whose c5/c6 are where it would show.

#### Resolution (2026-10-24)

Verdict: Needs your call: the code meets all seven criteria as written, but c4's fixture is rebuilt rather than recorded (Proxy decided), and Lc0 itself never ran (c1–c3, c6, c7). Re-record the fixture and run the gate with `engine/` present before you integrate the session PR.

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Spec found nothing missing or out of scope. Standards found two judgement calls and I kept both: the `[lines, reply, board]` step array (a Data Clump, private to `_queue`/`_send`), and the string-built castling normalisation, which reads like `board.gd`. I also read the whole diff myself, against `board.gd`'s move format and §3.1–3.2. No code changes in review.

Proxy decided (opus), named per the loop: the c4 fixture is rebuilt from the v0.32.1 format. The Disclosure above (`pending | integration`) carries it. Its conditions hold: the header says the fixture is rebuilt and lists the UCI lines to re-record it; there are no junctions or downloads; castling is normalised only from the mover's own king onto the mover's own rook, both spellings are tested, and a rook's `e1h1` is left alone; `P:` is read by its field; the `node` line is skipped; the live test checks keys = legal moves and sum ≈ 1.

Criteria:

1. ✅ In code: `start()` uses `OS.execute_with_pipe`, is a no-op once `available`, and queues `uci`→`uciok`, then `setoption name VerboseMoveStats value true`. Two worker threads block on stdout/stderr. The main thread only swaps `_lines` under the mutex in `poll()`. It never ran against Lc0 here.
2. ✅ In code: `set_level` sends `ucinewgame`, `setoption name WeightsFile value …` and `isready` in that order, then holds the queue until `readyok`. `new_game()` sends `ucinewgame`. Exercised only by the c7 test, which was skipped here.
3. ✅ `request_policy` sends `position fen <fen>[ moves …]` and `go nodes 1`. `poll()` collects `info string` lines only while it waits for `bestmove`, then emits `policy_ready(parse_policy(...))` on the polling (main) thread. The parser is tested on the fixture and on synthetic lines; the live path is covered only by the skipped c7 test.
4. ⚠️ `parse_policy(lines, board)` is static and pure. `test_parser_reads_every_legal_move_from_lc0_output` runs it with no Lc0 process: keys = legal moves, sum ≈ 1, both castles normalised. The fixture is rebuilt, not recorded, so this half of c4 is pending (Disclosure above).
5. ✅ `test_engine_lookup_takes_the_first_folder_holding_lc0` and `test_missing_engine_reports_unavailable_naming_the_fetch_script`. `search_dirs()` returns the executable's folder, plus `res://` globalised under the `editor` feature, which both a play-from-editor run and the headless gate have.
6. ✅ In code: `NOTIFICATION_PREDELETE` → `stop()` → `OS.kill(pid)`, then joins both readers, which return when the pipes break. This holds at app exit when the node is in the tree (the SceneTree frees it); BOT-004 must add it there, per the API note above. The live test asserts the pid is gone after `free()`, but it was skipped here.
7. ✅ The gate log shows `SKIP test_uci.gd::test_switching_from_maia_1100_to_1900_changes_the_policy: no engine/lc0/lc0.exe, run scripts/fetch-engine.ps1`.

Test-first: I checked `diff --stat` on every commit:
- 860d6fd: `tests/test_uci.gd`, `tests/fixtures/lc0_verbose.txt` and the ticket only (red).
- 6fa31c3: `engine/uci.gd` only.
- b1ce1d5: the ticket only.
- 8a8cf74: the `--no-ff` merge into the session.

All three code files are in Primary files.

Examined:
- Callers: nothing calls `uci.gd` yet. The planned callers are BOT-004 (`maia_player.gd`: tree, `start`, `set_level`, `request_policy`), CI-002 c5 (the missing-engine message) and BOT-007 (reads `P:`). `Board` is only read, through `from_fen`, `make_move`, `legal_moves`, `piece_at` and `side_to_move`. Its move strings match the regex: promotions are `e7e8q`, castling is `e1g1`.
- Failure paths:
  - Missing engine: `available` false and `error` set (tested).
  - `execute_with_pipe` fails: `error` set.
  - Pipes break: the readers return.
  - Lc0 exits or never replies: the queue stalls silently (Disclosure above).
  - Rejected FEN: crashes on a null board, as `Game.new` does (the CORE-004 deferral).
  - A position with no legal moves parses to `{}`.
- Re-entrancy: a `policy_ready` handler that calls `request_policy` is safe. The policy is parsed before the emit and `_awaiting` is cleared first, so the new request goes out at once and the trailing `_send()` does nothing.
- Threads: `_lines` is guarded by the mutex. The `stdio` FileAccess is read on a worker and written on the main thread. That relies on Godot's pipe using separate read/write handles; it was not exercised.
- Cross-feature: `PolicyTemperature` (Disclosure above) reaches §3.3, §4.1 and BOT-007.
- Not examined:
  - Real Lc0 output.
  - The process/thread path, and c6 at a real app exit.
  - What Lc0 does on a bad `WeightsFile`.
  - `go nodes 1` on a position with a single legal move.
  - The Linux CI run (CI-001 not built).

Red-green, from stage 2 and checked here: red at 860d6fd, because `res://engine/uci.gd` does not exist, so `test_uci.gd` fails to load (29 passed, 1 failed). Green at 6fa31c3 (34 passed, 0 failed). Removing the castling normalisation fails 2 tests.

Gate: the stage-2 receipt above (6fa31c3, exit 0, log hash checked: `806F24B1…0CC3`) still holds. The ticket branch already sat on the session tip, and only this ticket changed after 6fa31c3. Result: 34 passed, 0 failed. One of the 34 is the c7 test, which prints SKIP and returns.

- 2026-10-24 Stage stopped (incomplete handoff): Invalid committed handoff: BOT-002: code changed after gate (.scratch/core/issues/14-BOT-004-play-vs-maia.md); reuse evidence only for identical code. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\core\.scratch\run-log\BOT-002-review-20261024-032435.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-10-24 Foreman: merge 8a8cf74 reverted on the session (Bruno approved via the coordinating foreman: "de resto, aceito todas as recomendações"; the recommendation was to revert BOT-002 now and redo it after BOT-001). Reason: Verdict Needs your call (fixture rebuilt, not recorded; Lc0 never ran) kept the session PR from merging under the agent-only rule. BOT-001 added to `Blocked by`: the fixture and the integration test need `engine/`. The work is kept: merge 8a8cf74 in history and the local branch `BOT-002-uci-bridge` (6fa31c3). Redo after BOT-001 lands; Bruno picks `PolicyTemperature` then (question in BOT-004's Comments). Because the merge was reverted, merging the old branch again brings nothing back: start from a revert of this revert, or cherry-pick 860d6fd and 6fa31c3 onto a fresh branch.
