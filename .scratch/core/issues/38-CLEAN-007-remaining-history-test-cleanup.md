# CLEAN-007: Consider the shared History cleanup in the remaining scene-test harnesses
Stage: to-review
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - tests/test_review.gd (isolated-storage cleanup: inline `tree_exiting` lambda -> `HistoryStorage.clean(folder)`)
  - tests/test_clock_input_order.gd (same)

#### What to build

[CLEAN-003](34-CLEAN-003-history-test-cleanup.md) moved the isolated History cleanup of four harnesses into `tests/history_storage.gd`. Two more harnesses outside its Primary files still carry the identical inline `tree_exiting` lambda (`games` child then root): `tests/test_review.gd` and `tests/test_clock_input_order.gd`. `tests/test_badges.gd` and `tests/test_book.gd` keep their own `_clean` helpers, which also remove `openings` (and in badges `repertoires`) children, so they match the helper only if it is widened. No runtime defect was found.

Each file gains `const HistoryStorage = preload("res://tests/history_storage.gd")`, as the other four callers do. `tests/history_storage.gd` is unchanged. `test_badges.gd`/`test_book.gd` keep their own `_clean` (they also remove `openings`/`repertoires`; not duplicates).

#### Acceptance criteria

1. Each migrated harness keeps cleanup restricted to its own storage root and the children it already removed, tolerating absent directories, without touching normal player history, stats, books or repertoires.
2. Existing isolated injection, startup assertions and behavior assertions remain unchanged; no production code changes.
3. The bound gate passes with the refactored harnesses, unchanged in test count.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None new: behaviour-preserving, test-only harness refactor; no red commit. Validation: the diff adds or removes no `func test_` line; afterwards `path_join("games"), folder]` matches only `tests/history_storage.gd` under tests/; gate green with the test count unchanged against main at the time.

## Comments

- Created by CLEAN-003 stage 3 on 2026-10-25 to give the remaining duplicates an open destination: the two identical lambdas found by the review's grep, plus stage 2's out-of-scope note on test_badges/test_book. Optional Duplicated Code observation; does not block CLEAN-003 integration or release.
- Blocked for stage-1 triage and confirmation of the proposed scope. No refactor was implemented during review.
- 2026-10-25 Stage 1 triage through the proxy (foreman run):
- Proxy decided (opus): narrow scope, test_review + test_clock_input_order switch to `HistoryStorage.clean`; helper, test_badges, test_book unchanged — they are byte-for-byte the CLEAN-003 helper, badges/book also remove openings/repertoires so are not duplicates, and widening the helper's interface was not asked for.
- Proxy decided (opus): no red test; validation = no `func test_` line changed, grep `path_join("games"), folder]` hits only history_storage.gd, gate green with count unchanged against main — CLEAN-003 precedent for a mechanical test-only refactor.
- Proxy decided (opus): do it, low priority (not wontfix) — the owner's CLEAN-003 reason (the same fix had to be repeated across copies) applies to these two remaining identical copies.
- Proxy decided (opus): Status ready-for-agent, Stage to-implement, Blocked by none, Review agent, Difficulty normal — scope and validation settled; CLEAN-003 done.
- Disclosure: decision | none | test-only harness refactor; the Proxy decided lines above record the scope.
- 2026-10-25 Stage 2: replaced only the two inline `tree_exiting` cleanup loops with the existing `HistoryStorage.clean(folder)` and matching preload. The same isolated roots are captured; missing-directory handling and child-first removal remain in the unchanged helper. All `_session` callers still use the same setup, injections and assertions. `tests/test_badges.gd`, `tests/test_book.gd`, fixtures, runner and production are unchanged. No new or red test, per the explicit test-only refactor exception above.
- Static verification: `git diff --check` passed; no added/removed `func test_` lines; `path_join("games"), folder]` occurs only in `tests/history_storage.gd`. Both main and this branch contain 258 textual test declarations, including five declarations inside runner fixture strings; the suite therefore runs 253 actual tests. No test body or runner changed.
- Gate on test-only commit `b1fb2d568c2cadeceaa8ea93bcba07c2242f373f`: `godot --headless -s tests/run.gd`, Godot 4.7 stable, one foreground run, exit 0: **253 passed, 0 failed**, no SKIP, FAIL, script-error or parse-error lines. Existing malformed-theme/time-model fixtures emit warnings. Log: `C:\Users\bruno\AppData\Local\Temp\CLEAN-007-b1fb2d5-gate.log`; SHA-256 `B195C9030991E8688E0B6E3C8416EB9A0AD4951C58C7A0AE3A9D29B59ED5D50A`. No production changes after this run; this handoff changes only the ticket.

Acceptance: passed | the gate and static verification above cover this test-only refactor; stage 3 review remains pending.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\CLEAN-007-b1fb2d5-gate.json
