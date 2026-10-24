# BOT-006: Time-model table
Stage: blocked
Blocked by: BOT-005
Review: agent
Difficulty: normal

- Primary files:
  - bot/time_model.gd
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

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_time_model.gd`: bucket lookup at bin edges, the sample median, missing-bucket and malformed-file fallback, using the fixture table. Red because the table loader does not exist.

## Comments

- 2026-10-24 Stage stopped (incomplete handoff): Invalid committed handoff: BOT-006: missing Gate evidence receipt. See D:\Desktop\Projects\P-Chess\.artifacts-build\lanes\bot\.scratch\run-log\BOT-006-implement-20261024-195047.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
