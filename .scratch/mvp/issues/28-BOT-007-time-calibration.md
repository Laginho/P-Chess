# BOT-007: Time-model calibration from Lichess data
Stage: to-implement
Blocked by: BOT-001, BOT-006
Review: human
Difficulty: normal
Gate evidence: C:\Users\Lage\AppData\Local\Temp\BOT-007-aa5e1b1-gate-permitted.json

- Primary files:
  - New: scripts/calibrate_time.py
  - New: scripts/requirements-calibrate.txt
  - New: scripts/test_calibrate_time.py
  - New: tests/fixtures/lichess_sample.pgn
  - New: data/time_model.json

#### What to build

An offline script that measures how humans at 1100–1900 spend time in bullet and blitz, and writes `data/time_model.json` in the BOT-006 format (§4.3). Review is `human`: the download is several GB and **Bruno must say yes before it starts**.

#### Acceptance criteria

1. The script takes the dump URL and a byte limit as required arguments and prints the planned download size; no session runs the download without Bruno's go-ahead in chat.
2. It streams the start of one monthly Lichess `.pgn.zst` file without saving the whole file.
3. It keeps games at 60+0, 180+2 and 300+0 in the 1100–1900 bands, each band matched to the nearest Maia level.
4. Think time per move comes from consecutive `%clk` values plus the increment.
5. It runs Lc0 with the band's Maia net on a sample of positions to get the top-move probability.
6. It writes `data/time_model.json` in the BOT-006 format; buckets with too few samples are left out, so the game falls back to the formula there.
7. Python dependencies (`zstandard`, `python-chess`) are only in `scripts/requirements-calibrate.txt`; the game does not need them.
8. The extraction and bucketing logic is tested on a small fixture PGN with no download.

#### Verification

    python -m pytest scripts/test_calibrate_time.py
    Plan only: python scripts/calibrate_time.py --url <dump> --max-bytes <limit>
    After Bruno approves the download: python scripts/calibrate_time.py --url <dump> --max-bytes <limit> --download-approved
    godot --headless -s tests/run.gd

Offline tests establish script behavior before download approval. The real `data/time_model.json` is generated only after Bruno approves the planned download in chat. Until then, real calibration and M8 product acceptance remain pending; fixture output must not be committed as calibrated data.

## Tests stage 2 writes (own commit, red)

- `scripts/test_calibrate_time.py`: think times from `%clk` with increment, the time-control and rating filters, and bucket assignment on the fixture PGN. Red because the script does not exist.
- `scripts/test_calibrate_time.py`: CLI plan and explicit download opt-in at `main(argv)`, fixture-to-table execution with a mocked HTTP boundary, seeded bounded reservoir sampling, and `lc0_policy` through a local fake UCI process. No network. Red for missing CLI, sampling, or engine-boundary behavior.

## Comments

- 2026-10-25 Additional regression coverage starts green: seeded reservoir bounds/reproducibility (including empty and undersized input) and an engine that exits before `uciok`, which must return an error without replacing the previous output. The reservoir test fails with a first-N mutant; no production fix was needed. Fixture-based pipeline checks `Range`, exact consumed bytes, all three sampled Maia nets, `go nodes 1`, legal-move filtering and BOT-006 JSON keys. Six Python tests pass. python-chess emits its upstream Python 3.14 `DefaultEventLoopPolicy` deprecation warning; it does not affect these results.

- Proxy decided (gpt-6-astra high, fallback): Approve CLI, reservoir and local UCI-fake tests in the existing Primary test file, with real calibration pending Bruno's download approval — they verify existing criteria without expanding production scope or authorizing a download.
- 2026-10-25 Coverage chronology: CLI/engine/sampling implementation already existed uncommitted before the proxy approved these additional seams. It was preserved outside the repository and the committed production restored before committing the additional tests. Their subsequent red/green evidence verifies behavior, but is not evidence that those tests preceded initial authoring. Separate real-Lc0 smoke on the fixture evaluated 8 moves with maia-1100/1500/1900, top P 0.1968–0.4014, producing 6 buckets at a demonstration-only minimum of 1; no fixture table was committed.

- 2026-10-25 Streaming test harness correction: truncating a tiny single-block zstd frame produces no decompressed text, so the original assertion that earlier games survived was invalid. The fixture stream now flushes a complete block before truncating a later block in that same frame. The byte-cap assertion is re-proven red with the production LimitedReader cap disabled, then green with the cap restored.

- 2026-10-25 Stage 2 resumed on `BOT-007` from the MVP session. Dependencies are already installed in Python 3.14 (pytest 9.1.1, python-chess 1.999, zstandard 0.25.0). The WindowsApps Python alias is inaccessible in this sandbox; validation uses the installed interpreter directly. New script has no existing callers. Its table consumer is `bot/time_model.gd` through `bot/maia_player.gd`; controls and bin boundaries must match BOT-006. Extraction tests cover separate player clocks/ratings, rating boundaries and ties (ties round upward), unsupported controls, missing clocks, negative elapsed time, and the untimed first move. No download authorized or attempted.

- 2026-10-24 From BOT-004's close (a note, not a criterion; Bruno's call, before the download): c5's top-move probability must come from the same Lc0 `PolicyTemperature` the game uses, or the table's top_p bins will not match the game's `top_p`. The game leaves Lc0 v0.32.1's default, 1.359, which is flatter than Maia's raw policy (1). Pick one value. If it is not 1.359, the game sets it with one `setoption name PolicyTemperature value <v>` in `engine/uci.gd` `start()` (BOT-008, if still open), and c5 sends the same. Proxy's reading, not a decision: spec §3.2 calls `P:` "Maia's policy", which points to 1. History: BOT-002 Resolution, BOT-004 ## Comments.
- 2026-10-25 Stage 2 blocked before any code: BOT-007 stage 2 needs `python` (pytest for the red-green proof, plus `pip install -r scripts/requirements-calibrate.txt`), and the unattended driver's allowlist does not include it (`sweatshop/scripts/driver.ps1` line 148, source of truth in Agent-Skills). Every `python -c` / `python -m pytest` call was refused ("requires approval"); only `python --version` ran (3.14.6), so whether pytest, python-chess and zstandard are installed is unknown. Wrapping python in the allowed `powershell` prefix would get around the refusal, so it was not done. Pick one: (1) add `'python'` to that list (it allows any Python code, the same exposure the list already accepts with `node`/`npx`/`powershell`, and it applies to every lane and repo the driver runs); or (2) run BOT-007 stage 2 attended. Either way the machine needs pytest, zstandard and python-chess installed, or allowed to be installed. Then set `Stage: to-implement`.
  Proxy escalated (opus): stage 2 cannot run python headless and must not work around the permission gate.
- Proxy decided (opus): the script sends no PolicyTemperature, so c5 reads `P:` at the same Lc0 v0.32.1 default (1.359) that `engine/uci.gd` uses, with a one-line comment at the Lc0 start naming the coupling (`engine/uci.gd` `start()`, BOT-008, this note) — it keeps the "same value as the game" rule true without picking a value and touches no file outside Primary files. Picking a different value stays Bruno's call, at the download go-ahead c1 already requires; if it is not 1.359, BOT-008 adds the `setoption` in `start()` and the script sends the same line before the download run. Answer only if you want a value other than 1.359.

- 2026-10-25 Attempt 1 stopped to ask: I've blocked BOT-007 before writing any code (commit `26128d9` on `sweatshop/mvp/2026-10-25-0006`). This headless session isn't allowed to run Python, so I couldn't run the new tests or install the script's dependencies. /  / **Why it's blocked:** the driver's list of allowed commands (`driver.ps1` line 148) doesn't include `python`. Every `python -c` and `python -m pytest` call was refused; only `python --version` ran (3.14.6). Without pytest there's no proof that the tests fail before the change and pass after it, which the loop requires. I could have got past the refusal by wrapping `python` in the allowed `powershell` command. I didn't, and the proxy agreed that would get around the permission check. It sent this question back to you. /  / **What you need to decide (one of these):** / 1. Add `'python'` to the driver's allowed list. That lets every lane and repo the driver runs execute any Python code, the same exposure it already accepts for `node` and `powershell`. / 2. Run BOT-007 stage 2 yourself, in an attended session. /  / Either way, this machine needs pytest, python-chess and zstandard installed. I couldn't check whether they already are. After that, set the ticket back to `Stage: to-implement`. /  / **Also recorded for later:** the open question about the Lc0 setting that controls how spread out Maia's move probabilities are (`PolicyTemperature`). The proxy decided the script sends nothing, so it uses the same default (1.359) as the game. That keeps the script and the game matched without touching files outside the ticket. Answer only if you want a different value; it has to be settled before the download, which already waits for your go-ahead. /  / A `STOP` file appeared in `.scratch/run-log/` at 00:07, so the driver will probably end this run after this stage.
- 2026-10-25 Bruno decided (relayed by the supervising foreman, in Bruno's words): "Pode: o foreman instala pytest, python-chess e zstandard no meu Python global, volta o BOT-007 pra to-implement e relança com gpt-6.1-sol." Answers the python escalation: stage 2 runs on the gpt-6.1-sol (Codex) lineup, outside the Claude allowlist; the dependencies go in Bruno's global Python.

#### Stage 2 handoff (2026-10-25)

- Branch: `BOT-007`, based on `sweatshop/mvp/2026-10-25-0006`. Only Primary files plus this ticket changed. No production game code or runtime dependencies changed. `data/time_model.json` has not been generated or committed.
- Implemented required URL/byte-cap arguments and a printed plan by default; `--download-approved` enables HTTP streaming only after Bruno's chat approval. A Range request plus a capped reader bounds compressed bytes even when a server ignores Range. No monthly archive is saved. The script retains at most 10,000 seeded reservoir positions by default, evaluates them grouped by matching Maia net, and atomically writes BOT-006 JSON after successful evaluation. Default bins: clock `[0, .15, .5, 1]`, top-P `[0, .3, .6, 1]`; minimum 50 samples per bucket, configurable. Tied rating bands round upward. Zero-second observations use the game's 0.05 s floor for the logarithmic fit.
- Red/green commits: `0d12400` missing extraction module → `fbf40e2` (1 Python pass); `6b7fd87` missing table builder → `3093152` (2 passes); `727bf68` missing bounded stream → `e52af8a` plus test-only harness correction `2983699` (3 passes; cap-disabled mutant fails). `3f173a0` missing CLI/HTTP boundary → `b6bcc13` (4 passes). Test-only `aa5e1b1` adds already-green reservoir/engine-stop regression checks (6 passes); first-N mutant fails. The chronology limitation for the additional CLI tests is recorded above. Every commit separates test and production files; tracker metadata accompanies some test commits.
- Python validation: installed Python 3.14.6 invoked directly at `C:\Users\Lage\AppData\Local\Python\pythoncore-3.14-64\python.exe -B -m pytest -p no:cacheprovider scripts/test_calibrate_time.py`: **6 passed**, one upstream python-chess deprecation warning. The fixture-to-file test uses mocked HTTP and a real local fake UCI child process; it never contacts the dump server. A separate real Lc0 v0.32.1 smoke evaluated all 8 fixture positions across maia-1100/1500/1900; top P ranged 0.1968–0.4014. No fixture output was committed as calibrated data.
- Bound gate: `godot --headless -s tests/run.gd`, tested commit `aa5e1b10b95b1b57964f3132f55205b91853b0e8`, **137 passed, 0 failed**, exit 0; maia-1500 median latency 9.7 ms over 30 moves. The first sandboxed attempt could not write existing tests' `user://` files and was terminated; the successful foreground run used approved filesystem access. The receipt above was produced by `gate-evidence.ps1`; log SHA-256 `BE06A7ABC033309ADB8CB4DDB7203756C4D267015758D4F5D0BD7E4CD2DCEC7E`. Only ticket metadata changes after this tested commit.
- Final scope/whitespace review: clean; five changed files, all in the ticket boundary. No download, push, merge or stage-3 review performed.

Acceptance: pending | BOT-007 Verification above: approved real-data calibration, generated table validation and M8's human assessment of delays remain outstanding.

Disclosure: decision | none | BOT-007 Comments, proxy decision (gpt-6-astra high, fallback): added offline CLI/reservoir/UCI test seams for existing criteria, without production scope expansion or download authorization.
Disclosure: decision | none | BOT-007 Comments, proxy decision (opus): script sends no PolicyTemperature, matching the game's Lc0 v0.32.1 default 1.359; any different value remains Bruno's choice and must be coordinated with engine/uci.gd before calibration.
Disclosure: pending | release | BOT-007 Verification: data/time_model.json remains absent until Bruno approves the download and the generated table is validated; the game uses its documented formula fallback meanwhile.

#### Resolution (2026-10-25)

Verdict: Reopen — criterion 5 measures a different Maia policy from the game's by dropping move history.

##### Standards

No confirmed findings. Independent Standards review covered all five changed files against AGENTS.md, the engineering workflow, tracker conventions and the code-review smell baseline. Scope, dependency isolation, usage documentation and offline tests are appropriate; no actionable standard violation or code smell was found.

##### Spec

- [P1] Criterion 5 fails at `scripts/calibrate_time.py:203`: `Sample` retains only the current FEN (lines 47–52, 110), and `lc0_policy` sends `position fen <current FEN>`. The game sends its initial FEN and preceding moves in `engine/uci.gd::request_policy()`. With the installed Lc0 v0.32.1, maia-1500, default PolicyTemperature and `go nodes 1`, the fixture position before `2.Nf3` gives top P **0.4694 with history, bin 1**, versus **0.2734 with the script's FEN-only request, bin 0**. The position before `3.Bb5` likewise gives 0.3439 versus 0.2189, crossing the same boundary. These are different inputs to BOT-006's table lookup for the same game position.
- Repair criterion 5 within the existing Primary files: retain the initial FEN and preceding move sequence in each sample, send the same UCI position context as the game, and add a red regression at the already-approved extraction/local-UCI seam. Preserve the current position FEN for legal-move checks. No other criterion or Primary-file expansion is requested.
- No additional Spec findings or scope creep after reading the whole diff. The missing real-data table is the explicitly documented pending product check, not another implementation finding.

##### Criteria and examined interactions

1. ✅ Required URL/byte cap and printed plan; planning returns before HTTP. No download was performed or authorized.
2. ✅ Bounded streaming of compressed prefixes; local cap also applies when HTTP ignores Range. Truncation after a complete zstd block is covered.
3. ✅ All three controls, mover-specific 1100–1900 ratings and nearest Maia bands, including boundaries and ties.
4. ✅ Consecutive clocks per player plus increment; missing-clock intervals and negative elapsed times are excluded, first moves establish baselines.
5. ❌ Lc0 uses the matching net but loses the PGN history, producing policy probabilities and bins different from the game's. Only this repair and its regression remain for stage 2.
6. ✅ Offline output matches BOT-006's fields, bin edges and control names; sparse buckets are omitted. Real output remains pending approved calibration as stated in Verification.
7. ✅ Python dependencies remain script-only.
8. ✅ Extraction and bucketing use the local PGN fixture without network access.

Reviewed callers and cross-feature paths: `main` → capped zstd stream → `extract_samples` → reservoir → `lc0_policy` → `build_table` → atomic replacement; consumers `bot/time_model.gd` and `bot/maia_player.gd`; and the game's UCI setup/request flow in `engine/uci.gd`. Examined empty/undersized samples, missing clocks, unsupported controls/variants, invalid clock intervals, rating/bin boundaries, engine EOF/timeouts, legal-move filtering and preservation of existing output after engine failure. Not examined: a real monthly dump, a generated production table or M8's human assessment; those still require the documented download approval and product verification.

##### Verification and handoff

- Independent Spec reviewer reproduced the policy mismatch with local Lc0; the stage-3 owner independently reproduced 0.2734/bin 0 versus 0.4694/bin 1 using the actual `lc0_policy` and changing only the outgoing position command to `position startpos moves e2e4 e7e5`. Each run used a fresh engine with the same weights/options. No download occurred.
- Python suite rerun on reviewed commit `4a6e2db`: **6 passed**, one upstream python-chess Python 3.14 deprecation warning. A separate plan-only invocation printed the 2,000,000,000-byte limit and returned without HTTP.
- Independently replayed historical red commits in temporary directories: `0d12400` fails collection for the absent module; `6b7fd87` gives **1 failed, 1 passed** for missing `build_table`; `727bf68` gives **1 failed, 2 passed** for missing `pgn_stream`; `3f173a0` gives **1 failed, 3 passed** for missing CLI HTTP boundary. Current green suite calls production code. Every commit's stat separates tests from production. The previously recorded limitation that the additional CLI implementation was authored before its tests remains disclosed; the replay proves their failure without the implementation, not original authoring order.
- Existing gate receipt reused: SHA-256 matches its log, exit 0, **137 passed, 0 failed** at `aa5e1b1`; only this ticket changed since that tested commit. No production fix was authored during review, so the gate was not rerun.
- Both existing proxy decisions were examined: the additional offline CLI/reservoir/UCI seams stay within the original criteria; omitting PolicyTemperature matches the game's default 1.359. Neither decision authorizes a download or resolves the newly demonstrated history mismatch.
- Review totals: **Standards 0; Spec 1 (P1, criterion 5)**. Reopened on `BOT-007`; no ledger entry existed to remove. No merge or push. Stage 2 must repair criterion 5 test-first and produce fresh green gate evidence before returning to review.

Acceptance: pending | Verification and this Resolution: real-data calibration and M8 remain outstanding; criterion 5 also needs the history-context repair.
Disclosure: pending | integration | This Resolution, criterion 5: calibration policy bins differ from the game's because samples discard history; keep BOT-007 open until the implementation and regression are reviewed.
