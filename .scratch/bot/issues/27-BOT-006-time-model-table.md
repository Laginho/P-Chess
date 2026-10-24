# BOT-006: Time-model table
Stage: done
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

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 (opus-5.5). The Standards and Spec axes ran as separate sub-agents. Standards: no documented-standard breach (the repo documents none); one judgement call, the test logger's name `Warnings`, not worth a change. Spec: all six criteria met; its one finding (`bot/maia_player.gd` and `ui/main.gd` outside Primary files) is wrong, both joined Primary files by the proxy's decision. No fix in review.

Criteria:

1. ✅ `clock_bins` and `top_p_bins` hold the edges; each bucket holds control, level, clock bin, top-p bin, `median` (s) and `log_sigma`. The format is documented at `TABLE` in `bot/time_model.gd`, matching §4.1.
2. ✅ `median × exp(N(0, log_sigma))` is the log-normal with that median; the one-legal-move and premove overrides are checked before it, and `minf(maxf(seconds, FLOOR), clock_left)` clamps after. `test_a_bucket_s_delay_keeps_the_overrides_and_the_clamps` covers each.
3. ✅ A missing file loads as `{}` with no warning; a missing bucket returns `{}`; `delay` with `{}` is the formula, equal to it over 20 seeds.
4. ✅ Parse errors, wrong top-level shape, bad edges and bad buckets each give one `push_warning` and `{}`, tested over 16 malformed cases through a `Logger`. Every field is type-checked before use, so nothing indexes a wrong type.
5. ✅ Seed 11, 10,000 draws from the 4 s bucket: median within ±0.2 s (5%), log-σ within ±0.03 of 0.5. The clamps cannot move the median there (the floor and 180 s are both past 7σ).
6. ✅ `maia_player` passes `TimeModel.bucket(time_table, control, level, left / start, top_p)`; `test_in_a_game_maia_s_delay_comes_from_its_bucket` gets the floor from maia-1500's bucket and the ~6 s formula for maia-1100, which has no 3+2 bucket.

Test-first: `diff --stat` on every commit (hashes after the rebase). 7e944b8 is the test, the fixture and this ticket; 5a44fe1 is `bot/` only; 4efb13f is `ui/main.gd` only, as the proxy asked; 39ba456 and 2568cca are this ticket only.

Red-green:
- From stage 2: red at 4b33e29 (102 passed, 1 failed, test_time_model.gd fails to load); green at 6b57c78 (119 passed, 0 failed). Its two mutants are in its comment above.
- Checked by me, on the lane worktree then restored (`git status` clean): with the `median > 0` check removed and the bucket's σ replaced by 0.6, the gate gave 116 passed, 3 failed: `test_a_bucket_s_delay_is_log_normal_around_its_median` (log-sigma 0.606), `test_a_bucket_s_delay_keeps_the_overrides_and_the_clamps` (expected 4.0, got 3.447) and `test_a_malformed_table_warns_and_is_empty` ("median zero", both asserts).

Examined:
- Callers: `TimeModel.delay`, `bucket` and `load_table` are called only from `bot/maia_player.gd` and the tests; `delay`'s new parameter defaults to `{}`, so BOT-005's calls and tests are unchanged. `MaiaPlayer` is built once in `ui/main.gd` and in tests; each build reads the table, and a missing file is silent. `tests/test_maia_player.gd` sets no clock, so it never looks up a bucket.
- Level strings: `ui/setup.gd` `LEVELS` (`"maia-1100"` … `"maia-1900"`) → `started` → `_start(colour, level, control)` → `maia.level`; the same strings name the nets, and the format's keys use them. The `ui/main.gd` line is checked by reading only: no test drives `_start`.
- Failure paths: empty `level` or an unknown control misses and uses the formula; a clock past its start (increments) falls in the top bin, a clock at 0 in bin 0; no legal move in the policy gives `top_p` 0, bin 0; a bucket with σ 0 gives its median exactly; a huge median is clamped to the clock left; duplicate buckets keep the last one.
- Cross-feature: BOT-007 c6 writes "in the BOT-006 format", and c3 names the controls the Lichess way (180+2); the format's keys are the game's (`"3+2"`), so a table keyed "180+2" would miss every lookup and silently use the formula. The documented format binds BOT-007; worth a look at its review.
- Spec §4.1–4.2 still describes the result; the `bot/time_model.gd` header was updated with the change; no doc went stale.
- Not examined: exported builds (no `export_presets.cfg` yet, so whether `data/*.json` ships is open), a manual game with a real table.

Rebase: onto session 359a2ab, whose tree equals 75ca899's (the stop commit and its revert cancel out); clean. The merge e064054 differs from the tested 6b57c78 only in this ticket file, so the gate receipt above stands (exit 0, 119 passed, 0 failed, log hash verified).

Proxy decided (opus), named for the session PR: option B, which added `bot/maia_player.gd`, `ui/main.gd` and c6. Its conditions held: `time_model.gd` stays static and pure, empty `level` misses, the wiring has a mutant, the `ui/main.gd` line is its own commit.

Acceptance: pending | BOT-006 makes Maia read data/time_model.json, which does not exist until BOT-007 writes it; M8's "delays feel human" is checked there. Gate 119/0 at 6b57c78, receipt above.
Disclosure: pending | integration | ui/main.gd _start: BOT-005's maia.clock/maia.control plus BOT-006's maia.level conflict with the core lane's _start(new_settings); resolve as maia.clock = clock, maia.control = settings.control, maia.level = settings.level. From the proxy's decision above. Today origin/main and every pushed core lane still have `_start(colour, level, control)`, so the conflict is with core work not pushed yet.
