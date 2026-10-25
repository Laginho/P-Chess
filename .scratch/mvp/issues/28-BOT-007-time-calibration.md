# BOT-007: Time-model calibration from Lichess data
Stage: implementing
Blocked by: BOT-001, BOT-006
Review: human
Difficulty: normal

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
    After Bruno approves the download: python scripts/calibrate_time.py --url <dump> --max-bytes <limit>
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
