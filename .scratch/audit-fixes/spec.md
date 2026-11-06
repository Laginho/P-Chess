# Audit fixes (d0920a0)

Decided in a grilling session with Bruno on 2026-11-06 (grill-proxy; proxy receipts `%TEMP%/sweatshop-proxy/20261106-141649-audit-fixes-c4b5e4.json` and `20261106-142124-audit-fixes-9f40af.json`). Source: [the d0920a0 audit](../../docs/audits/2026-11-05-d0920a0.md). One sweatshop lane `audit-fixes` from `main`, one PR, six tickets, all `Review: agent`. After it merges, `v0.1.0` is tagged on main; pushing the tag waits for Bruno's go.

## What it is

The audit ran at d0920a0 (2026-11-02), before PR #41 (History pages, stop analysis) and PR #42 (Review side lines). Re-checked at 52985b2 on 2026-11-06:

| Audit finding | State at 52985b2 | Ticket |
|---|---|---|
| 1. History rebuilds on every progress event | Progress updates the active card in place; `_refresh()` runs for queue state changes. Parsed PGNs are cached (HIST-007 added size to the key), but building visible cards took 0.8?0.9 s for saved games and about 1.6 s for a legacy fixture | HIST-007 (measurement and cache key), HIST-010 (card build) |
| 2. Failed stats write leaves PGN and counters inconsistent | Present (`core/history.gd` `save`) | HIST-008 |
| 3. Review merges a cache checked only by metadata and length | Present (`engine/analyser.gd` `read_analysis`, `ui/review.gd`) | REV-010 |
| 4. `Settings.set_value` ignores a failed save and returns true | Present (`core/settings.gd`) | UI-038 |
| 5. Malformed `analysis_queue.cfg` leaves the queue active with no game | Present (`core/analysis_queue.gd` `_init`) | HIST-009 |
| 6. Unused `_class_help` / `_wrap_help` | Present (`ui/review.gd`) | CLEAN-015 |

## Decisions

- **One ticket per finding** (Bruno). Run order 95 → 96 → 97 → 94 → 98 → 99; HIST-007 waits for HIST-008 and REV-010 (it measures History after REV-010 changes its cache reads); CLEAN-015 waits for REV-010 (same file).
- **Cache validation lives in `Analyser.read_analysis`** (Bruno), which takes the expected FENs. An incomplete or mismatched cache reads as `{"state": "stale"}`. History, Profile and every Review read site use it; their own copies of the checks go away. Incremental, not-yet-scored live data is not a complete cache and is untouched.
- **History save rollback** only when the stats write fails; HIST-003 criterion 3 (a snapshot-only failure still saves PGN and stats) is unchanged. No crash-safe multi-file recovery.
- **Settings write failure** returns false with nothing changed; the screens that set values say so or show the stored value again.
- **Malformed queue** is repaired on load, never left active without a current game.
- **No timing assertion in the gate.** HIST-007 measures with a probe and records the log.
- Out of scope: CLEAN-014 (Review line autoscroll, still needs-triage, not a v0.1.0 blocker); the audit's process note about Python calibration tests.

## Test seams

- **Existing test files with temp storage.** A failed write is a directory where the target file goes, as `tests/test_history.gd` already does for `stats.cfg`; persisted state is asserted by reloading a fresh instance. Catches: state that disagrees after restart, false success. Escapes: real disk-full or permission errors on Windows. No new seam.
- **`Analyser.read_analysis` alone** (tests/test_analyser.gd) for each invalid cache shape, plus **the Review scene with a fake engine** (tests/test_review.gd) for one invalid and one valid cache. Catches: script errors on bad caches, valid caches no longer loading, Stockfish started when it should not be. Escapes: caches written by future engine versions.
