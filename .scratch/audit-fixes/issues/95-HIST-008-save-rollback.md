# HIST-008: A failed stats write leaves no trace of the game
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/history.gd (`save`, around the `_results.save` of `stats.cfg`)
  - tests/test_history.gd

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 2. Today `save()` writes the PGN, bumps W/D/L (and the practice counter), then writes `stats.cfg`. When that write fails, it returns "" but restores only the practice counter. After a restart, the PGN is there but the counters never counted it. Make a failed stats write roll the whole save back.

#### Acceptance criteria

1. When the `stats.cfg` write fails, `save()` restores every counter it changed (W/D/L for the level and control, flag counters, practice). It deletes the PGN and the `.repertoire.json` snapshot it just wrote and returns "" with `error` set.
2. If deleting either file fails during that rollback, `error` reports that too: one message that names both failures.
3. After such a failure, a fresh `History` on the same storage sees the same game count and counters as before the attempt. The next successful save then counts normally.
4. HIST-003 criterion 3 is unchanged: when only the snapshot write fails, the error is reported and the PGN and stats are still saved.
5. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_history.gd: make `stats.cfg` fail the way the existing failed-stats test does, with a directory in its place, and save a finished game. Reload a fresh `History`. Assert that the game count, W/D/L, flag counters and practice count equal the pre-save state, and that no PGN or snapshot is left (red: the PGN stays and the counters disagree). Then remove the directory, save again and assert the game counts once. Mirror the reload pattern of `_check_delete_rollback`.

## Comments

- 2026-11-06 Written from the grill ([spec](../spec.md)).
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)
