# HIST-009: A malformed analysis queue repairs itself on load
Stage: to-implement
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: easy

- Primary files:
  - core/analysis_queue.gd (`_init`, `_start_next`)
  - tests/test_analysis_queue.gd

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 5. `_init` assigns the persisted `games`, `priority`, `total` and `done` without checking them. With `games=[42]`, `_start_next()` sets `_active` and then fails on the int-to-String assignment. The queue is left active with no current game, so nothing ever runs again.

#### Acceptance criteria

1. On load, `games` keeps only non-empty String entries, and a `priority` that is not a String becomes "".
2. `batch_done` and `batch_total` are kept only if both are ints with `0 <= done <= total` and `total >= done + kept games`. Otherwise `done = 0` and `total = kept games`.
3. Anything dropped or reset produces one `push_warning` that names the file.
4. `_active` is never true without a current game.
5. After loading `games=[42]` with broken counters, enqueueing a valid game makes it run and progress.
6. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_analysis_queue.gd:
  - Write an `analysis_queue.cfg` with `games=[42, "", "<valid path>"]`, `priority=7`, `done=-3` and `total="x"`, and load it with a fake runner. Assert that the pending list holds only the valid path, priority is "", the counters are reset and the queue progresses (red: a script error and a queue stuck active).
  - Load `games=[42]` alone, enqueue a valid game and assert it starts.

## Comments

- 2026-11-06 Written from the grill ([spec](../spec.md)).
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)
