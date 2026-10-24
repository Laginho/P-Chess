# BOT-007: Time-model calibration from Lichess data
Stage: to-implement
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

## Tests stage 2 writes (own commit, red)

- `scripts/test_calibrate_time.py`: think times from `%clk` with increment, the time-control and rating filters, and bucket assignment on the fixture PGN. Red because the script does not exist.

## Comments

- 2026-10-24 From BOT-004's close (a note, not a criterion; Bruno's call, before the download): c5's top-move probability must come from the same Lc0 `PolicyTemperature` the game uses, or the table's top_p bins will not match the game's `top_p`. The game leaves Lc0 v0.32.1's default, 1.359, which is flatter than Maia's raw policy (1). Pick one value. If it is not 1.359, the game sets it with one `setoption name PolicyTemperature value <v>` in `engine/uci.gd` `start()` (BOT-008, if still open), and c5 sends the same. Proxy's reading, not a decision: spec §3.2 calls `P:` "Maia's policy", which points to 1. History: BOT-002 Resolution, BOT-004 ## Comments.
