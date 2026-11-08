# LEARN-010: The tablebase probe (Fathom helper)
Stage: to-implement
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

- 2026-11-08 Split out of LEARN-006 (proxy). Named limits:
  - The probe sees only the FEN, so repetition is outside it.
  - A helper that hangs while still alive has no timeout.
  - The Windows release package and the accented-folder check are pending Bruno before release. The CI Windows job covers only the build and one smoke probe, and only once the branch is pushed.
  - Running the game from the editor on Bruno's Windows machine needs a C compiler (VS Build Tools) to build the helper.

- Draft application: `export_presets.cfg` is included in Primary files because criterion 9 explicitly requires those export exclusions. The helper's startup error is for no tables loaded, allowing criterion 8's KRvK-only smoke fixture; the application's adapter still requires all 40 files under criterion 3. The spec distinguishes that Windows smoke fixture from the full real-file suite. These reconcile supporting files and verification wording in the approved draft. Fathom source/API details and the static-CRT build remain to be verified by stage 2; this ticket does not claim those checks have run.

- 2026-11-08 Second reopen: foreman diagnosis required before retrying. Classify new defect, earlier review miss, contract gap, or review-induced churn; record cause and next action, then return to-implement only when ready.

- 2026-11-08 Reopen diagnosis (foreman): earlier review miss plus an incomplete stage-2 repair; one consolidated stage-2 repair of the adapter's line handling, then re-review.
  - Cause 1, earlier review miss (drip-feed): round 2's finding (invalid `info`/`bestmove`/`tberror` lines dropped before the `uciok`/`readyok` barriers and while idle) already existed at `fcf2f67`. Round 2 reproduced it on `c2eeafe`'s adapter (`stage3-prior-handshake-parser-summary.log`). Round 1 exercised malformed output only during an active search.
  - Cause 2, incomplete repair: `ee7cae3`'s raw-line filter (`engine/tablebase.gd:79-86`) says it fails closed "including during startup", but it passes every `info `/`bestmove` prefix to the unchanged bridge. `engine/uci.gd:181` forwards those only while `_awaiting == "bestmove"` and drops them otherwise. No test covered the handshake or idle phases.
  - Not a contract gap: criterion 4 ("fails closed ... on `tberror`, on a line it cannot parse") and the helper protocol table settle it, and the repair fits the Primary files with `engine/uci.gd` unchanged. No regression from review advice.
  - Consolidated review of the affected paths (`engine/tablebase.gd` `poll`, `_on_line`, `_finish`, `stop` against `engine/uci.gd:164-193`), done so the next pass fixes everything at once:
    1. Phase: the adapter, not the bridge, must decide whether each raw line is legal in its current protocol phase, in arrival order. Handshake: only `id name P-Chess tbprobe (Fathom <commit>)`, `uciok`, `readyok`, or `error ...`. Active search: only `info string tbmove ...`, `info string tberror ...` (fails the probe), and `bestmove <move>`. Idle, between searches: any line fails. Today the bridge silently drops these lines out of phase: `info`/`bestmove`/`tberror` before either barrier or while idle (round 2), and stray `id name`/`uciok`/`readyok` during a search (same root cause, not yet reported).
    2. Shape: the filter accepts any `id name ` text; the protocol fixes `id name P-Chess tbprobe (Fathom <commit>)`.
    3. Values: `_on_line` (`:131`) rejects a `draw` with nonzero dtz, but accepts `win`/`cursed-win`/`blessed-loss`/`loss` with dtz `0`. The protocol counts dtz "with the move included", so only a draw can be 0.
  - Next action: back to `to-implement` on `LEARN-010`. Write red tests at the FakeUCI seam for each phase (a pending and a queued probe before `uciok`, between `uciok` and `readyok`, idle after a `bestmove`, out-of-phase handshake lines during a search) and for items 2 and 3. Then make one adapter repair, with `engine/uci.gd` unchanged; the stop-and-ask rule still applies if it must change. Every pending, queued and later probe gets exactly one `{ok = false}` and `available` turns false. Fresh gate. Stage 3 re-reviews criterion 4 across all phases, not only the cases listed.
