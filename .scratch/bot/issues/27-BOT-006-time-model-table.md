# BOT-006: Time-model table
Stage: to-review
Blocked by: BOT-005
Review: agent
Difficulty: normal

- Primary files:
  - bot/time_model.gd
  - bot/maia_player.gd (scope: a `level` var; loads `data/time_model.json` once; passes the game's bucket to `TimeModel.delay`)
  - ui/main.gd (scope: `_start` sets `maia.level = level`, one line next to `maia.control`)
  - New: tests/fixtures/time_model_small.json
  - tests/test_time_model.gd

#### What to build

Maia's think time comes from `data/time_model.json` when it exists (§4.1), and from the BOT-005 formula otherwise. This ticket fixes the file's format, which BOT-007 writes.

#### Acceptance criteria

1. The file holds the bin edges for clock fraction left and for top-move probability, and one bucket per (time control, level, clock bin, top-p bin) with a median think time in seconds and a log-σ.
2. The delay is sampled from the bucket's log-normal distribution, then clamped to `[0.05 s, clock_left]`; the BOT-005 overrides still apply first.
3. A missing file or a missing bucket uses the BOT-005 formula.
4. A malformed file logs a warning and uses the formula; it never crashes.
5. With a fixed seed, the median of 10,000 samples from one bucket is within ±5% of that bucket's median.
6. In a game, Maia's delay comes from the bucket for the game's control and level when the table holds it; tested in `tests/test_time_model.gd` with the fixture table.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_time_model.gd`: bucket lookup at bin edges, the sample median, missing-bucket and malformed-file fallback, using the fixture table. Red because the table loader does not exist.

## Comments

- Proxy decided (opus): option B — bot/maia_player.gd (level var, load the table once, pass the bucket) and ui/main.gd (one line in _start: maia.level = level) join Primary files, plus c6 "in a game, Maia's delay comes from the game's bucket" — "What to build" and M8 need the table loaded in the game, BOT-007 cannot do it, and the main.gd line lands in the conflict BOT-005 already disclosed. Conditions: time_model.gd stays pure (static loader, lookup, sampler); an empty `level` misses the lookup, so BOT-005's wiring tests stay unchanged; the wiring is proven by a mutant; the `ui/main.gd` line is its own commit. For stage 3: `Disclosure: pending | integration | ui/main.gd _start: BOT-005's maia.clock/maia.control plus BOT-006's maia.level conflict with the core lane's _start(new_settings); resolve as maia.clock = clock, maia.control = settings.control, maia.level = settings.level`
- Stage 2 (2026-10-24): red at 4b33e29 (`Static function "load_table()" not found`, `Too many arguments for "delay()"`; test_time_model.gd fails to load; 102 passed, 1 failed). Green at 6b57c78: 119 passed, 0 failed (102 + 17 in test_time_model.gd, 7 new). Mutants: `maia_player` not passing the bucket fails `test_in_a_game_maia_s_delay_comes_from_its_bucket`; `_bin` with `bsearch(value, true)` (an edge in the bin below) fails four lookups in `test_the_table_buckets_by_control_level_clock_and_top_p`. Format choices (the ticket owns them): keys are the game's own strings (`"3+2"`, `"maia-1500"`); n ascending edges make n − 1 bins, bin i is [edge i, edge i+1), and values past either end fall in the end bins, so a clock past its start (increments) uses the top bin; the format is documented at `TABLE` in `bot/time_model.gd`. Callers of `TimeModel.delay`: only `bot/maia_player.gd`; the new parameter defaults to `{}`, so BOT-005's calls are unchanged.
Gate evidence: C:/Users/Lage/AppData/Local/Temp/claude/D--Desktop-Projects-P-Chess--artifacts-build-lanes-bot/6a80a8f4-fd2f-4279-a50f-d09df80694a4/scratchpad/bot-006-gate.json
