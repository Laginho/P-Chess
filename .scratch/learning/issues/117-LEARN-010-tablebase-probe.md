# LEARN-010: The tablebase probe (Fathom helper)
Stage: to-review
Blocked by: CI-005
Review: agent
Difficulty: hard

- Primary files:
  - New: native/tbprobe/main.c (the helper: a UCI subset over Fathom's root probe)
  - New: scripts/build-tbprobe.ps1 (fetches pinned Fathom source by SHA-256, builds the helper for the host into `<Root>/engine/tbprobe/`)
  - New: engine/tablebase.gd (the probe, spec §L5, over the unchanged `engine/uci.gd`)
  - New: tests/test_tablebase.gd
  - New: tests/fixtures/tablebase/ (transcripts recorded from the real helper)
  - .github/workflows/release.yml (build, require and ship the helper and Fathom's licence)
  - .github/workflows/ci.yml (a windows-latest job: build the helper and run one real probe)
  - .gitignore (`engine/tbprobe/`)
  - export_presets.cfg (exclude `native/` and `engine/tbprobe/` from the exported `.pck`)
  - docs/THIRD_PARTY.md (Fathom)
  - docs/spec.md (§3.1 Engine files, one line on `engine/tbprobe/`)

`engine/uci.gd` is reused unchanged. If it needs a change, stop and ask.

#### What to build

The one probe that grading, play-out checks, the perfect opponent and the review marker all ask (spec §L5). RES-001 showed that Stockfish 19 computes root-move DTZ but never exposes it through UCI. Instead, a small helper built from Fathom (MIT) reads the CI-005 files and speaks a UCI subset over the same bridge as the engines. `engine/tablebase.gd` turns its lines into answers about the position: win, draw or loss; each legal move's result and distance to zeroing; and the best move. It fails closed and never falls back to an engine evaluation.

#### Helper protocol

| In | Out |
| --- | --- |
| `uci` | `id name P-Chess tbprobe (Fathom <commit>)`, then `uciok` |
| `setoption name SyzygyPath value <rest of line, verbatim>` | Nothing. If no table loads: `error tablebase files not found in <path>` |
| `isready` | `readyok` |
| `position fen <FEN>` then `go` | For every legal move: `info string tbmove <uci> <wdl> <dtz>`, then `bestmove <uci>` |
| (position not probeable) | `info string tberror <reason>`, then `bestmove (none)` |
| (no legal move) | `bestmove (none)` with no `tbmove` lines |
| `quit`, or end of stdin | The helper exits |

- `<wdl>` is `win`, `cursed-win`, `draw`, `blessed-loss` or `loss`: the result for the side making the move, taking the FEN's half-move clock into account.
- `<dtz>` is an unsigned number of plies to zeroing, counted from this position with the move included. A capture, pawn move, promotion or mate that keeps a win is 1. A non-zeroing move is the child's distance plus one. A draw is 0.
- A promotion is four moves (q/r/b/n), each with its own value. Castling is never generated.
- "Not probeable" means: castling rights, a FEN that does not parse, more pieces than the loaded tables cover, a missing or unreadable table for the position or any child, or any Fathom failure.
- At startup the helper changes its working directory to its own folder, with the wide-character API on Windows. The app always passes `../tablebase`. Paths then never depend on the app's working directory (RES-001 measured that dependency), and folders with spaces or accents work. Fathom opens files with narrow strings, so absolute non-ASCII paths are unsafe on Windows.
- Expected source of the values: `tb_probe_root` results (`TB_GET_WDL/DTZ/FROM/TO/PROMOTES`), which take the half-move clock and refuse castling rights. Confirm this in the pinned source first. If it differs, map to this contract in `main.c` and say so in the first commit.

#### Acceptance criteria

1. `scripts/build-tbprobe.ps1 [-Root]` downloads Fathom's sources and LICENSE as raw files at one pinned commit SHA. It checks each file's SHA-256 and stops naming any file that doesn't match. It caches them outside `-Root` and the repo, then compiles `native/tbprobe/main.c` single-threaded into `<Root>/engine/tbprobe/tbprobe.exe` (Windows) or `tbprobe` (Linux). On Windows it uses MSVC found through vswhere with the static CRT, so the exe imports only system DLLs (the VC++ DLLs ship only beside Lc0). With no compiler it fails, naming what to install. A failed build leaves no helper behind.
2. The helper follows the protocol table above.
3. `start()` finds the helper with `UCI.search_dirs()`/`engine_path()`. A missing helper gives `Tablebase probe is missing (engine/tbprobe/tbprobe.exe). Run scripts/build-tbprobe.ps1 to build it.` Any of the 40 CI-005 files missing under `<helper folder>/../tablebase` gives an error naming the first missing file and `scripts/fetch-engine.ps1`. Otherwise it starts the helper through `engine/uci.gd` and sends `setoption name SyzygyPath value ../tablebase`.
4. `probe(fen, callback)` never blocks the main thread and calls back exactly once, with `{ok = true, result, dtz, best, moves}` or `{ok = false, error}`.
   - `moves[uci] = {result, dtz}` for every legal move. `result` is the mover's `win`, `draw` or `loss`. A cursed win and a blessed loss are `draw`, because the game ends at 100 half-moves (`core/game.gd:79`).
   - `best` is ranked by win > cursed-win > draw > blessed-loss > loss, then the smallest `dtz` for wins and the largest for losses, then UCI order. The top-level `result` and `dtz` are `best`'s.
   - With no legal move (by `Board`), the probe answers without the helper: checkmate is a loss, stalemate a draw, `dtz` 0, `best` "", `moves` {}.
   - It fails closed on castling rights (nothing sent), on `tberror`, on a line it cannot parse, or when the helper's move set differs from `Board.legal_moves()`. It never reads a score, a PV or an evaluation.
5. When the helper stops (crash, an `error` line, or the probe is freed), every pending and later probe gets `{ok = false, error}` and `available` is false; no callback waits forever. Freeing the probe stops the helper.
6. On this Linux box, with the helper and the 40 verified files present, these real-file checks run (skipped elsewhere, like the live Lc0 tests):
   - RES-001's FEN `8/8/8/4k3/8/4K3/4P3/R6r w - - 0 1`: win, `a1h1` win with dtz 1 (best), `a1a5` draw, `a1a3` loss, 18 moves equal to the board's legal moves.
   - A promotion where an under-promotion's result differs from the queen's.
   - A winning non-zeroing move whose dtz is the child's plus one.
   - The same win with a half-move clock that makes it cursed, answering draw.
   - A capture into bare kings, answering draw.
   - A 6-piece FEN and a FEN with castling rights, each giving an error.
   - A tables folder missing the needed file, giving an error, not a guess.

   Check expected values against an independent reader outside the repo, as RES-001 did, and record the commands. Record the median warm probe time; there is no threshold.
7. `release.yml` builds the helper into `build/windows` after the fetch step and copies Fathom's LICENSE (pinned SHA-256) to `licenses/Fathom-LICENSE.txt`. Both are in the required-files check. The job fails if `dumpbin /dependents` shows a non-system DLL for the helper. No other package change.
8. A windows-latest job in `ci.yml` builds the helper with the same script. It copies the helper to a folder whose path has a space and a non-ASCII character, with only `KRvK.rtbw`/`.rtbz` (hashes from `fetch-engine.ps1`) in `../tablebase`. It probes one KRvK position and checks for a `tbmove` line and `bestmove`.
9. THIRD_PARTY.md names Fathom, the commit, MIT and the copyright holders from its LICENSE. `.gitignore` covers `engine/tbprobe/`. spec §3.1 lists the helper. The exported `.pck` contains neither `native/` nor `engine/tbprobe/`.

#### Verification

    Linux: pwsh scripts/build-tbprobe.ps1; symlink engine/tablebase -> /run/media/lage/New Volume/Scratch/CI-005/install/engine/tablebase (keep the tables off the SSD)
    godot --headless -s tests/run.gd   (the real-file tests must run, not SKIP)
    Windows (pending Bruno): unzip the release under a folder with an accented name; LEARN-006's Lucena check grades a line

## Tests stage 2 writes (own commit, red)

- `tests/test_tablebase.gd`, through the fake UCI engine (lines injected as in `tests/test_uci.gd`):
  - `start` sends `SyzygyPath ../tablebase`.
  - A missing helper or table gives the named error.
  - Scripted `tbmove` lines become moves, result, dtz and best, including cursed win and blessed loss as draw and each tie-break.
  - `tberror`, a move-set mismatch and castling rights give `ok = false`.
  - A terminal position answers without sending.
  - A helper stop answers every pending probe with an error.

  Red: no probe.
- `tests/test_tablebase.gd`, against the real files (skipped without them): criterion 6. Red: no helper.
- `tests/fixtures/tablebase/`: the real helper's transcript for RES-001's FEN, parsed in CI.
- Build script and workflows: no automated tests, as in CI-005. Criteria 1, 7 and 8 are covered by the manual run and the CI job.

## Comments

- 2026-11-08 Second reopen: foreman diagnosis required before retrying. Classify new defect, earlier review miss, contract gap, or review-induced churn; record cause and next action, then return to-implement only when ready.

- 2026-11-08 Split out of LEARN-006 (proxy). Named limits:
  - The probe sees only the FEN, so repetition is outside it.
  - A helper that hangs while still alive has no timeout.
  - The Windows release package and the accented-folder check are pending Bruno before release. The CI Windows job covers only the build and one smoke probe, and only once the branch is pushed.
  - Running the game from the editor on Bruno's Windows machine needs a C compiler (VS Build Tools) to build the helper.

- Draft application: `export_presets.cfg` is included in Primary files because criterion 9 explicitly requires those export exclusions. The helper's startup error is for no tables loaded, allowing criterion 8's KRvK-only smoke fixture; the application's adapter still requires all 40 files under criterion 3. The spec distinguishes that Windows smoke fixture from the full real-file suite. These reconcile supporting files and verification wording in the approved draft. Fathom source/API details and the static-CRT build remain to be verified by stage 2; this ticket does not claim those checks have run.

- Stage 2 source check: pinned Fathom `c9c6fef0dddc05d2e242c183acf5833149ab676d`; `tb_probe_root` rejects castling and returns mover-side root WDL/DTZ including the halfmove clock. `probe_root` adds the current ply, handles mate as 1 and zeroing via WDL; intrinsic cursed/blessed distances carry a 100-ply encoding offset. The helper will remove that offset using the clock-zero classification and verify child probes so missing child DTZ files also fail closed. No change to `engine/uci.gd`. New adapter callers are the future grader/play-outs/review; existing UCI, Board and build-script callers are preserved. Boundary inputs under test: terminal boards, all promotion moves, castling, malformed output, empty/mismatched move sets, queued requests and process failure.


### Stage 2 criteria check (2026-11-08)

Read-only check by a fresh Codex subagent on the ticket and `git diff sweatshop/learning/2026-11-07-2234..HEAD`. It found one concrete miss: the cache could equal `-Root`. Fixed in `75fc6f3`, manually proved rejected, and rechecked. No remaining numbered-criterion miss found; Windows execution remains pending as already authorized.

- ✅ 1: `scripts/build-tbprobe.ps1:9` pins individual sources/license and SHA-256; `:32` locates compilers; `:51` rejects a cache within or equal to either root; `:88`/`:93` compile single-threaded, Windows `/MT`; `:103` removes failed output. Manual successful build/rerun, corrupt-cache, missing-compiler and cache-equality checks passed.
- ✅ 2: `native/tbprobe/main.c:180` supplies root/child probing and failures; `:223` supplies the UCI subset and own-directory startup. Real protocol, promotion, distance and missing-child tests plus the recorded transcript cover it.
- ✅ 3: `engine/tablebase.gd:39` resolves the helper; `:49` checks all 40 files; `:63` queues the relative Syzygy path. `test_start_checks_the_helper_and_each_required_table` checks every missing filename; `test_start_sets_a_relative_path_and_probe_returns_every_move_once` checks the command.
- ✅ 4: `engine/tablebase.gd:72`, `:92`, `:101`, `:132`, `:136`, `:147` cover asynchronous requests, terminal answers, closed parsing, WDL normalization, ranking and completion. Tests cover ranks/ties, malformed/incomplete/extra moves, castling, invalid FEN and callback reentry.
- ✅ 5: `engine/tablebase.gd:32`, `:154`, `:158` stop the helper, drain pending callbacks and reject later calls. `test_stop_error_and_free_finish_all_pending_callbacks_once` checks the UCI stopped signal, error output and freeing the probe.
- ✅ 6: `native/tbprobe/main.c:185`, `:202`, `:213` enforce table availability and normalize intrinsic DTZ50. `tests/test_tablebase.gd:324`, `:346`, `:386` cover all real-file scenarios. All 40 installed file hashes were verified; the external reader matched all 96 legal-move values across six FENs. Commands and warm timing below.
- ✅ 7: `.github/workflows/release.yml:69`, `:119`, `:133` build after fetch, inspect imports, verify the pinned license and require both artifacts. Static MSVC CRT is selected by the shared script; actual Windows execution remains pending Bruno/CI.
- ✅ 8: `.github/workflows/ci.yml:9`, `:18`, `:23`, `:27`, `:54` build on Windows and check a real KRvK probe from `P Chess ação`, with only the two hash-verified files. The Linux equivalent passed; the Windows job awaits a push.
- ✅ 9: `docs/THIRD_PARTY.md:3`, `docs/spec.md:41`, `.gitignore:5`, `export_presets.cfg:8` provide Fathom attribution and packaging rules. Exported the pack, inspected all 282 directory entries and loaded it from an isolated project: adapter present, `native/` and `engine/tbprobe/` absent.

### Stage 2 implementation and verification

- Branch `LEARN-010`, based on `sweatshop/learning/2026-11-07-2234`; `engine/uci.gd` is byte-for-byte unchanged. Sources and objects are cached on the HDD, outside the repo and installation root. The app uses the same UCI queue/reader threads and serializes requests on the main thread.
- Red/green commits: `a9d2e86` (0 passed, 2 failed: no adapter) → `7379402` (2/0); `5b4f6db` (5/3: terminal/parser validation absent) → `be00f82` (8/0); `268cbae` (8/3: no helper, tables installed) → `b7dd7a9` (11/0). `208f901` added the real transcript and intrinsic-cursed fixture: temporarily forcing parsed results to draw and removing the helper's 100-ply normalization each made the new assertions fail. Restored production: 12/0 focused tests, including all three live tests, with no tablebase SKIPs. No test-only and production edits were mixed in a commit.
- Confirmed the pinned Fathom root API in `tbprobe.h` and `probe_root`/`dtz_to_wdl` in `tbprobe.c` before implementation. The helper removes the 100-ply intrinsic cursed/blessed encoding offset, while preserving clock-induced WDL. It checks each child's table pair and performs a child root probe even when Fathom's zeroing optimization needs only WDL. No engine scores or PVs are used.
- Native source compiled both as C11 and C++14 on Linux; the latter checks the language mode used by MSVC. Manual build failures named `src/tbconfig.h` on a poisoned cache, named the C compiler installation when `cc` was absent, and rejected cache-root equality; each left no output helper. Build and KRvK-only smoke in a spaced, accented Linux path passed from an unrelated working directory.
- Independent reference: python-chess 1.11.2 from RES-001, outside the repo. Six positions matched all 96 legal moves: RES-001 (18), promotion (9), KRvK at clocks 0/98 (19 each), capture into bare kings (3), and intrinsic-cursed KRBvKR (28). Warm median over 31 completed RES-001 queries: **0.609847 ms**, helper already loaded, including pipe round-trip; no threshold.

Local execution evidence is under `/run/media/lage/New Volume/Scratch/LEARN-010/`: `independent.py`, `independent.log`, `warm-timing.txt`, `native-red.log`, `focused-green.log`, `fixture-mutant-red.log`, `intrinsic-mutant-red.log`, `build-hash-failure.log`, `build-no-compiler.log`, `cache-root-failure.log`, `accent-build.log`, `accent-smoke.log`, `export.log` and `pack-files.txt`. These paths are local evidence; the committed fixture, literal real-file assertions and commands below preserve the essential verification for another machine.

Commands used (Linux):

```sh
pwsh -NoProfile -File scripts/build-tbprobe.ps1
# The 40 files stay on the HDD, exposed by the ignored symlink prescribed above.
PYTHONPATH='/run/media/lage/New Volume/Scratch/RES-001/python-chess-1.11.2' python3 '/run/media/lage/New Volume/Scratch/LEARN-010/independent.py'
godot --headless --export-pack 'Windows Desktop' '/run/media/lage/New Volume/Scratch/LEARN-010/content.pck'
godot --headless --path '/run/media/lage/New Volume/Scratch/LEARN-010/inspect-pack' -s '/run/media/lage/New Volume/Scratch/LEARN-010/inspect-pack/inspect.gd'
```

Independent values can also be reproduced directly, with `PYTHONPATH` pointing to python-chess outside the repository and `TABLES` pointing to the verified files:

```python
import chess, chess.syzygy
with chess.syzygy.open_tablebase(TABLES) as tb:
    for fen, moves in [
        ("8/8/8/4k3/8/4K3/4P3/R6r w - - 0 1", ["a1h1", "a1a5", "a1a3"]),
        ("8/7P/8/8/2k5/8/8/1K6 w - - 0 1", ["h7h8q", "h7h8r", "h7h8b", "h7h8n"]),
        ("8/8/8/4k3/8/4K3/8/R7 w - - 0 1", ["e3f3"]),
        ("7k/8/3Br3/8/3R2K1/8/8/8 w - - 0 1", ["g4f5"]),
        ("8/8/8/4k3/8/8/1r6/1K6 w - - 0 1", ["b1b2"]),
    ]:
        board = chess.Board(fen)
        print(fen, tb.probe_wdl(board), tb.probe_dtz(board))
        for move in moves:
            child = board.copy(); child.push_uci(move)
            print(move, tb.probe_wdl(child), tb.probe_dtz(child))
```

Expected reference examples: `e3f3`'s child is loss/DTZ -26, hence parent move win/27. Intrinsic KRBvKR is cursed/DTZ 102, with `g4f5`'s child blessed/DTZ -101, hence actual distances 2/1. Q/R promotions win and B/N promotions draw. A zeroing move that keeps a win has distance 1; bare kings and other draws have distance 0. The same KRvK win at halfmove clock 98 is returned as draw.

Windows release/engine startup, the actual windows-latest job and LEARN-006's end-to-end Lucena grading remain pending as documented in the approved ticket. This handoff does not claim those runs occurred.

Gate: `godot --headless -s tests/run.gd`, tested commit `75fc6f3bbd9376461c4be5a218d9c904f2782cc0`: **615 passed, 0 failed**, exit 0. All real tablebase tests ran.

Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-010/consolidated-gate.json

#### Resolution (2026-11-08)
Verdict: Reopen — criterion 4 accepts malformed helper output instead of failing closed.

Standards: **0 findings**. Independent Standards review read the full diff against session base `882c182` and the documented repository rules. All production changes are within Primary files, `engine/uci.gd` is unchanged, and the nine stage-2 commits separate tests, production and metadata. No actionable baseline smell was reported.

Spec: **1 finding, with two reproduced cases**, under criterion 4. Independent Spec review and the stage-3 reviewer checked all nine criteria and the full diff. The contract requires failure "on a line it cannot parse":

- At `engine/tablebase.gd:118–120`, `begins_with("bestmove")` accepts malformed command tokens. After a complete set of legal `tbmove` records, both `bestmoves a1h1` and `bestmoveX a1h1` produce one `{ok: true, ...}` callback and leave `available` true. The first token is never checked for equality with `bestmove`.
- During the same active search, a line `garbage` followed by a valid `bestmove a1h1` also produces success. The unchanged bridge at `engine/uci.gd:181` forwards only `info ` and `bestmove` prefixes to the adapter; other output never reaches its rejection branch. Generic UCI tolerance does not exempt this helper's enumerated protocol from criterion 4.

Reproduction used the existing `tests/test_tablebase.gd` FakeUCI seam. Call `_setup()`, start `probe(RES_FEN, callback)`, inject `info string tbmove <move> draw 0` for every `Board.from_fen(RES_FEN).legal_moves()`, then inject either malformed completion token, or `garbage` followed by `bestmove a1h1`. Expected: one error callback and unavailable probe. Observed in all three cases: one success callback and available probe. The external diagnostic script also checked that its harness recorded no assertion failures:

```sh
godot --headless --path . -s '/run/media/lage/New Volume/Scratch/LEARN-010/stage3-parser-probe.gd'
```

Local script and captured output: `/run/media/lage/New Volume/Scratch/LEARN-010/stage3-parser-probe.gd` and `/run/media/lage/New Volume/Scratch/LEARN-010/stage3-parser-probe.log`. The description above preserves the reproduction without depending on those local artifacts.

Criteria reviewed:

- ✅ 1: pinned source/license hashes, external cache, single-threaded host build, MSVC `/MT`, compiler errors and failed-output cleanup; reviewed `scripts/build-tbprobe.ps1` and stage-2 manual evidence.
- ✅ 2: root/child Fathom probes, five WDL classes, DTZ normalization, promotions, terminal replies, own-directory startup and relative table path; reviewed native source, pinned Fathom implementation, recorded transcript and live-test evidence.
- ✅ 3: helper discovery, all 40 required files and named errors, unchanged UCI bridge and relative Syzygy option.
- ❌ 4: valid replies, ranking, terminal answers, castling and move-set checks are covered, but malformed completion tokens succeed and unrecognized active-search stdout is ignored, as reproduced above.
- ✅ 5: stopped/error/free paths drain active and queued callbacks and reject subsequent probes; reviewed the existing lifecycle tests and callback reentry.
- ✅ 6: all required Linux real-file scenarios ran in the verified gate; literal assertions and stage-2 independent-reader evidence cover promotions, child-plus-one distance, clock-induced and intrinsic curses, bare kings, unsupported material and missing tables. Warm timing is recorded above.
- ✅ 7: release build ordering, pinned license, required artifacts and system-import check are present. Windows execution remains pending.
- ✅ 8: Windows CI builds with the shared script and probes hash-verified KRvK files from a spaced, accented folder. The job's actual run remains pending.
- ✅ 9: attribution, ignore rule, spec entry and export exclusions are present; stage-2 pack inspection confirmed both excluded directories absent.

Affected callers and interactions examined: the new adapter's `start/probe/poll/stop` API; existing UCI handshake, queue, callback dispatch, error and process-stop handling; Board FEN parsing, terminal detection and legal moves; native root/child material checks and halfmove/promotion boundaries; fetch-file inventory, release licensing/import checks, Windows smoke job and exported pack. There are no production adapter callers yet in this diff; LEARN-006 and later grading/play-out/review integrations remain future work. Actual Windows execution and end-to-end Lucena grading were not examined because they remain pending.

Next stage 2 addresses only the ❌ items: add regression tests at the approved fake-UCI seam, prove them red, repair fail-closed parsing in the approved Primary files, then obtain fresh green gate evidence. Preserve `engine/uci.gd`; if a transport change proves necessary, follow the existing stop-and-ask instruction. Stage 3 made no production or committed-test changes. The receipt still matches the unchanged code (`75fc6f3`, SHA-256 log verified): **615 passed, 0 failed**, all real tablebase tests ran. Those passing tests do not cover the malformed-output cases above. No merge or ledger entry was made.

Acceptance: pending | stage-3 re-review of the criterion 4 repair; actual Windows CI, accented-folder release startup and LEARN-006 Lucena grading remain pending as already documented under Verification.
Disclosure: pending | integration | [Stage-3 review](#resolution-2026-11-08): criterion 4 parser repair is committed and verified below; stage 3 must re-review it before this ticket integrates.
Disclosure: pending | release | [Verification](#verification): Windows CI execution, release startup in an accented folder and LEARN-006 Lucena grading remain unverified; Linux evidence does not claim those checks passed.


### Stage 2 repair after review (2026-11-08)

- Resuming the existing `LEARN-010` branch at `c2eeafe`; only criterion 4's ❌ items remain. Existing helper, build, packaging and real-file evidence are retained. Callers affected: `probe` completion, `poll` stdout dispatch and queued callbacks on parser failure; `start` must preserve handshake/barrier handling. Degenerate inputs include unknown/empty stdout, malformed completion tokens, queued requests and later requests after failure. `engine/uci.gd` remains unchanged.
- Regression tests at the approved fake-UCI seam: `test_malformed_completion_tokens_fail_closed_after_a_complete_move_set` reproduces both `bestmoves` and `bestmoveX`; `test_unknown_stdout_fails_active_queued_and_later_probes_once` reproduces unknown, empty and malformed stdout before valid completion. The harness now polls through the adapter's public `poll()` and retains the reader's original queue reference, matching UCI's worker-thread capture. All pre-existing assertions remain unchanged.
- Red proof: rebuilt the pinned helper and restored the ignored HDD tablebase symlink. Focused run: **12 passed, 2 failed**, exit 1; all three real-file tests ran. Failures are successful callbacks/available probes for malformed output and unanswered pending requests, matching the review. Log: `/run/media/lage/New Volume/Scratch/LEARN-010/reopen-red.log`.

- Green repair: `tablebase.gd` retains the reader-thread inbox and hands UCI a separate main-thread queue. Each raw line is inspected before generic dispatch, with unknown stdout converted to UCI's fatal error path in arrival order; detaching the queues prevents a line arriving between inspection and generic polling from escaping validation. Completion now requires the exact `bestmove` token. Focused run: **14 passed, 0 failed**, exit 0, all real-file tests ran (`reopen-green.log`).


### Stage 2 repair criteria check and handoff (2026-11-08)

Fresh read-only Codex subagent checked the full ticket and diff from session base `882c182`, focusing on the repair `c2eeafe..ee7cae3`. No actionable miss found in the reopened criterion. The previous nine-criterion check remains recorded above; this pass preserves the helper, build, workflows, licenses and packaging unchanged.

- ✅ 4 (reopened items): `engine/tablebase.gd:138` requires the exact completion token; `tests/test_tablebase.gd:258` fails on both malformed prefixes without that check. `engine/tablebase.gd:82` converts unknown raw stdout into a fatal bridge error; `tests/test_tablebase.gd:278` fails without it and verifies active, queued and later requests each receive exactly one error. `engine/tablebase.gd:65` separates the worker inbox from the validated queue so arrivals during generic polling cannot escape the next validation. Handshake, barrier, normal replies, callback reentry, crash/error/free and all real-file cases pass the existing assertions.
- Independent focused run: **14 passed, 0 failed**, all real-file checks ran (`criteria-focused.log`). An external diagnostic (`criteria-late-stdout.gd`) injected unknown stdout plus a complete valid answer from the fake bridge's `poll()`, after the adapter drained its inbox: the first poll safely deferred the new data, the next poll rejected it exactly once. Both evidence files are under `/run/media/lage/New Volume/Scratch/LEARN-010/`.
- Red/green commits for this repair: `976b820` test-only (12 passed, 2 failed against the reviewed production code) → `ee7cae3` production-only (14 passed, 0 failed). Existing tests only changed their injection harness to retain the reader queue and call public adapter polling; pre-existing behavior assertions were preserved.
- Fresh foreground gate through `gate-evidence.ps1`: `godot --headless -s tests/run.gd`, tested commit `ee7cae3a88dd686753ade9ef4577692f747fcdf9`, **617 passed, 0 failed**, exit 0. All three real-file tablebase tests ran, with no tablebase SKIPs. Receipt: `/run/media/lage/New Volume/Scratch/LEARN-010/reopen-gate.json`; log: `/run/media/lage/New Volume/Scratch/LEARN-010/reopen-gate.log`. Only this ticket changes after the tested commit.
- `engine/uci.gd` is byte-for-byte unchanged against the session base (SHA-256 `176b600971b0dd38211849f91de7a24ce39b9dc3f5542292a6fafdce1ab2fd03`). Actual Windows CI, accented-folder release startup and LEARN-006's end-to-end Lucena grading remain pending as previously authorized.

Stage 2 hands off at `to-review`; no merge or ledger entry.

### Stage 3 re-review after parser repair (2026-11-08)

#### Resolution (2026-11-08)
Verdict: Reopen — criterion 4 still ignores malformed output and `tberror` while a pending probe waits for the startup handshake.

Standards: **0 findings**. Independent read-only reviewer `standards_review` examined `c2eeafe...62f6fd7`, the complete ticket, repository rules and the affected adapter/UCI/test paths. No documented-standard violation, actionable baseline smell, Primary-files breach or test-first breach. `976b820` is test-only, `ee7cae3` production-only and `62f6fd7` metadata-only; `engine/uci.gd` remains unchanged.

Spec: **1 finding**, independently reproduced by reviewer `spec_review` and the stage-3 reviewer. The prior active-search reproductions are fixed: after a complete move set, `bestmoves a1h1`, `bestmoveX a1h1` and `garbage` now each produce one error callback and an unavailable probe. The separate worker inbox also prevents late arrivals from bypassing validation. However, criterion 4 requires failure "on `tberror`, on a line it cannot parse", and that requirement still fails before either startup barrier:

- At `engine/tablebase.gd:82–86`, the raw-line filter passes every `info ` and `bestmove` prefix to the generic bridge. Strict validation remains in `_on_line()` at `:119–147`.
- At unchanged `engine/uci.gd:181–182`, those lines reach `_on_line()` only while `_awaiting == "bestmove"`. A probe can already be pending in the adapter while the bridge awaits `uciok` or `readyok`, so the bridge silently drops the invalid line instead.
- Confirmed examples before each barrier: `bestmoves a1h1`, `bestmoveX a1h1`, `info garbage`, `info string tbmove a1h1 win -1` and `info string tberror missing table`. After a subsequent valid handshake and complete replies, the pending request, a queued request and a later request each receive one `{ok: true, ...}` callback; `available` stays true. Expected: failure callbacks and an unavailable probe. The same invalid lines are also ignored while idle; ordinary `garbage` and empty stdout correctly fail in all three phases.

**Prior-pass miss:** this startup/barrier path already existed in `c2eeafe`; the earlier review exercised malformed output only after the search began. The Spec reviewer loaded that commit's adapter from an external copy and reproduced the same five ignored line types before both barriers and while idle (`stage3-prior-handshake-parser-summary.log`, beside the diagnostic below). This is an uncovered part of the same numbered criterion, not a new regression or a contract change.

Reproduction at the approved FakeUCI seam: create the bridge and adapter as `_setup()` does, but withhold `uciok` (or send `uciok` and withhold `readyok`); call `probe(RES_FEN, callback)` twice; inject one invalid line through `bridge.output()`; then supply the remaining handshake lines and a complete valid move set plus `bestmove a1h1` for each request. Finally issue and answer a third request. Observe three successes and `available == true`. The diagnostic reports `HARNESS_FAILURES []` and also checks the idle phase. Local script and captured log:

```sh
godot --headless --path . -s '/run/media/lage/New Volume/Scratch/LEARN-010/stage3-handshake-parser-probe.gd'
# Captured output: /run/media/lage/New Volume/Scratch/LEARN-010/stage3-handshake-parser-probe.log
```

Criterion 4: ❌ for the startup/barrier cases above; its active-search malformed-token and unknown-stdout cases now pass. Criteria 1–3 and 5–9 retain their previous approved assessments; their implementation is unchanged by this repair. Reviewed interactions: retained reader inbox, raw-line ordering, UCI handshake/ready barriers, pending and queued requests, completion parsing, callback reentry, process-stop/error/free paths and later requests after failure. Windows execution and end-to-end Lucena grading remain outside this local review as previously documented.

Verification retained: red commit `976b820` recorded **12 passed, 2 failed**; production commit `ee7cae3` recorded **14 passed, 0 failed** in the focused suite. `Assert-GateEvidence` verified the bound command, tested commit `ee7cae3a88dd686753ade9ef4577692f747fcdf9`, exit marker, log SHA-256 and identical tested code at `62f6fd7`: **617 passed, 0 failed**, including all three real-file tablebase tests. Reused this valid receipt because no production or committed tests changed in review. Passing tests do not cover the startup/barrier finding. `git diff --check` passed.

Next stage 2 addresses only the remaining ❌: add regression tests at the existing FakeUCI seam before both handshake barriers, prove them red, and make invalid output and `tberror` fail closed for pending, queued and later probes while preserving valid startup and reply ordering. Keep `engine/uci.gd` unchanged; the existing stop-and-ask rule still applies if a bridge change proves necessary. Stage 3 changed only this ticket; no merge, ledger entry, proxy decision or contract change.

Acceptance: pending | [Stage-3 re-review](#stage-3-re-review-after-parser-repair-2026-11-08): criterion 4 startup/barrier repair and re-review remain open.
Disclosure: pending | integration | [Stage-3 re-review](#stage-3-re-review-after-parser-repair-2026-11-08): pending probes can succeed after invalid helper output or `tberror` during startup; resolve before session integration.
Disclosure: pending | release | [Verification](#verification): actual Windows CI, accented-folder release startup and LEARN-006 Lucena grading remain unverified under the approved ticket.

- 2026-11-08 Reopen diagnosis (foreman): earlier review miss plus an incomplete stage-2 repair; one consolidated stage-2 repair of the adapter's line handling, then re-review.
  - Cause 1, earlier review miss (drip-feed): round 2's finding (invalid `info`/`bestmove`/`tberror` lines dropped before the `uciok`/`readyok` barriers and while idle) already existed at `fcf2f67`. Round 2 reproduced it on `c2eeafe`'s adapter (`stage3-prior-handshake-parser-summary.log`). Round 1 exercised malformed output only during an active search.
  - Cause 2, incomplete repair: `ee7cae3`'s raw-line filter (`engine/tablebase.gd:79-86`) says it fails closed "including during startup", but it passes every `info `/`bestmove` prefix to the unchanged bridge. `engine/uci.gd:181` forwards those only while `_awaiting == "bestmove"` and drops them otherwise. No test covered the handshake or idle phases.
  - Not a contract gap: criterion 4 ("fails closed ... on `tberror`, on a line it cannot parse") and the helper protocol table settle it, and the repair fits the Primary files with `engine/uci.gd` unchanged. No regression from review advice.
  - Consolidated review of the affected paths (`engine/tablebase.gd` `poll`, `_on_line`, `_finish`, `stop` against `engine/uci.gd:164-193`), done so the next pass fixes everything at once:
    1. Phase: the adapter, not the bridge, must decide whether each raw line is legal in its current protocol phase, in arrival order. Handshake: only `id name P-Chess tbprobe (Fathom <commit>)`, `uciok`, `readyok`, or `error ...`. Active search: only `info string tbmove ...`, `info string tberror ...` (fails the probe), and `bestmove <move>`. Idle, between searches: any line fails. Today the bridge silently drops these lines out of phase: `info`/`bestmove`/`tberror` before either barrier or while idle (round 2), and stray `id name`/`uciok`/`readyok` during a search (same root cause, not yet reported).
    2. Shape: the filter accepts any `id name ` text; the protocol fixes `id name P-Chess tbprobe (Fathom <commit>)`.
    3. Values: `_on_line` (`:131`) rejects a `draw` with nonzero dtz, but accepts `win`/`cursed-win`/`blessed-loss`/`loss` with dtz `0`. The protocol counts dtz "with the move included", so only a draw can be 0.
  - Next action: back to `to-implement` on `LEARN-010`. Write red tests at the FakeUCI seam for each phase (a pending and a queued probe before `uciok`, between `uciok` and `readyok`, idle after a `bestmove`, out-of-phase handshake lines during a search) and for items 2 and 3. Then make one adapter repair, with `engine/uci.gd` unchanged; the stop-and-ask rule still applies if it must change. Every pending, queued and later probe gets exactly one `{ok = false}` and `available` turns false. Fresh gate. Stage 3 re-reviews criterion 4 across all phases, not only the cases listed.

### Stage 2 consolidated phase repair (2026-11-08)

- Callers and boundaries checked before writing tests: `poll()` is called by `_process()` and the approved FakeUCI harness; it dispatches `_on_line()` through the unchanged UCI queue. `_finish()` calls the user's callback and `_next()`, which can queue another search before the bridge consumes the previous `bestmove`. `stop()` is reached by parsing, the stopped signal and PREDELETE, and must drain active/queued callbacks before rejecting later requests. There are no production callers of this new adapter yet. Regression cases cover split/coalesced reader batches, both startup barriers (including identity not received), idle lines immediately after completion, queued searches, callback reentry, malformed identity/order, and zero DTZ in all four decisive WDL classes. All tests stay at the approved FakeUCI/probe seam; all three real-file tests will run with the HDD tables.
- Red before production changes: focused suite **15 passed, 5 failed**, exit 1 (`/run/media/lage/New Volume/Scratch/LEARN-010/phase-red.log`). The five failures reproduce ignored startup output, invalid identity/barrier ordering, handshake lines during search, idle output (separate/coalesced batches), and decisive moves with DTZ 0. Existing tests and the new positive fragmented/coalesced ordering test pass; all three live tests ran. The fake identity now uses the pinned helper's actual commit. Helper rebuilt from verified cached sources; the 40-file table directory is an ignored symlink to the HDD installation.
- Fresh read-only criteria check of `a541507` found one additional criterion-4 path: the successful client's callback can reenter public `poll()` while UCI still awaits the completed `bestmove`. `_active` has already been cleared, so `_on_line()` drops a late `tbmove`/`tberror` and the next requests can succeed. Reproduction: `/run/media/lage/New Volume/Scratch/LEARN-010/criteria-reentrant-poll.gd` and `.log`. Added a FakeUCI regression covering no queued request, an already queued request, and a request queued by the callback, with late `tbmove`, `tberror` and `bestmove`. Red on `a541507`: **20 passed, 1 failed**, exit 1 (`callback-phase-red.log`), before changing production. Criteria 1–3 and 5–9 had no concrete miss in the independent check; criterion 4 will be rechecked after this cycle.

#### Consolidated repair and verification

- `b826327` (test-only plus ticket): **15 passed, 5 failed** → `a541507` (production-only): **20 passed, 0 failed**. Raw lines are validated against the bridge's current barrier, and dispatched individually so every next line sees the updated phase. Identity must have the helper's specified name and a commit SHA; duplicate/out-of-order handshake tokens and all idle output fail closed. Only `draw` may have move DTZ 0.
- `3c3b200` (test-only plus ticket): **20 passed, 1 failed** → `64469e0` (production-only): **21 passed, 0 failed**, including all three live tests (`callback-phase-green.log`). A success callback is explicitly marked as a completion interval: a reentrant poll cannot treat idle output as the completed search or a request queued by that callback. A valid completed answer stays successful; queued and later requests fail exactly once when new output violates the protocol.
- The same fresh read-only subagent rechecked criterion 4 at `64469e0`, including all phases and completion reentry: no remaining concrete miss found. Its 18 fake-seam tests passed (`criteria-phase-focused.log`), and the independent reproduction now returns `[true, false, false]` with `available == false` and no harness failures for late `tbmove`, `tberror` and duplicate `bestmove` (`criteria-reentrant-poll-fixed.log`). Other criteria retain the initial independent check below. No contract change or proxy decision.

#### Stage 2 criteria check after consolidated repair

Fresh independent check of the complete ticket and diff against the session base, with criterion 4 rechecked after the additional red/green cycle:

- ✅ 1: `scripts/build-tbprobe.ps1:9`, `:32`, `:44`, `:88`, `:93`, `:103` pin/hash files, locate a compiler, keep caches external, build single-threaded/static and remove failed output. Approved manual failure checks remain recorded above; a fresh successful Linux build is in `phase-build.log`.
- ✅ 2: `native/tbprobe/main.c:31`, `:62`, `:180`, `:223` implement own-directory startup, FEN validation, root/child probes and protocol. `test_real_helper_protocol_and_missing_position_or_child_tables` and `test_real_promotions_nonzeroing_distance_rule50_and_bare_kings` cover these behaviors.
- ✅ 3: `engine/tablebase.gd:42`, `:52`, `:71` discover the helper, check the 40 files and send the relative Syzygy path. `test_start_checks_the_helper_and_each_required_table` and `test_start_sets_a_relative_path_and_probe_returns_every_move_once` cover the exact diagnostics and command.
- ✅ 4: `engine/tablebase.gd:86`, `:97`, `:112`, `:144`, `:153`, `:173`, `:177`, `:193` cover all protocol phases, callback reentry, asynchronous queuing, strict move parsing/sets, DTZ, normalization and ranking. FakeUCI tests cover both startup barriers, identity/order, active search, idle output in split/coalesced batches, terminal/castling/malformed positions, ranking ties, and reentrant callbacks with requests queued before or during completion. Red/green proof and the independent reproduction above exercise production code, not a parser copy.
- ✅ 5: `engine/tablebase.gd:35`, `:113`, `:199`, `:203` stop on free/crash/error, drain active and queued callbacks and reject later requests. `test_stop_error_and_free_finish_all_pending_callbacks_once` and the new phase/reentry regressions assert exact callback counts and unavailable state.
- ✅ 6: `native/tbprobe/main.c:185`, `:201`, `:209` enforce real-file availability/child probing and DTZ normalization. All three live tests at `tests/test_tablebase.gd:548`, `:570`, `:610` passed in the focused suite and full gate; none were skipped. All 40 installed SHA-256 hashes were freshly verified against `scripts/fetch-engine.ps1` (`phase-table-hashes.log`). Independent-reader commands and warm median remain recorded above; native probing is unchanged by this repair.
- ✅ 7: `.github/workflows/release.yml:69`, `:119`, `:133` build/inspect the helper, verify Fathom's license and require both artifacts. Approved manual/CI verification remains as above; actual Windows execution is still pending.
- ✅ 8: `.github/workflows/ci.yml:9`, `:19`, `:23`, `:27`, `:54` provide the Windows build and spaced/accented-path smoke probe with the pinned KRvK pair. The actual Windows job remains pending a push, as authorized in the ticket.
- ✅ 9: `docs/THIRD_PARTY.md:3`, `docs/spec.md:41`, `.gitignore:5`, `export_presets.cfg:8` document/license the helper and exclude its binary/native sources from the pack. The recorded export/pack inspection remains applicable; these files are unchanged by the repair.

Fresh bound foreground gate at tested commit `64469e0ffea8994a3f461361a4e6e0bea554cd16`: `godot --headless -s tests/run.gd`, **624 passed, 0 failed**, exit 0. All 21 tablebase tests, including the three real-file checks, passed. Log: `/run/media/lage/New Volume/Scratch/LEARN-010/consolidated-gate.log`; receipt is the `Gate evidence:` line above. Only this ticket changes after that tested commit. `git diff --check` passed, and `engine/uci.gd` remains byte-for-byte unchanged against the session base.

Stage 2 hands off at `to-review`; no merge or ledger entry. Actual Windows CI/release startup in an accented folder and LEARN-006's end-to-end Lucena grading remain pending under the original approved verification limits. Stage 3 must re-review criterion 4 across all phases, including completion callback reentry, before session integration.
