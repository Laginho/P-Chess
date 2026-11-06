# HIST-009: A malformed analysis queue repairs itself on load
Stage: done
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
- Red: focused queue tests failed against the original code, including invalid types, inconsistent counters and activation without a game. Green: 10 focused tests passed after the fix.
- Gate: 569 passed, 0 failed, exit 0. One graphical pixel check and six live Lc0 checks were skipped because the display or engine was unavailable.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\HIST-009-gate.json

#### Resolution (2026-11-06)
Verdict: Approve

- Standards: 0 findings in the independent Standards review. The complete three-file diff `2dcd63ed25914000df188e30aa6e8a41164ced56...c26d4f697c7f53ed565b2697df2d94e59d7858c2` respects Primary files and repository conventions. No production or test fixes were authored during review.
- Spec: 0 findings in the independent Spec review. All numbered criteria pass:
  1. Loaded games retain only non-empty Strings; non-String priority becomes empty. Mixed entries, a non-Array container and valid priority are covered.
  2. Both counters must be ints with `0 <= done <= total` and enough remaining capacity for the retained games. Invalid values reset done to zero and total to the retained count; valid counters survive. Subtraction avoids overflow when validating the remaining capacity.
  3. One warning names the configuration file per repaired load. The isolated green log contains nine named warnings for nine repaired loads, including the case that repairs several fields together.
  4. `_start_next` assigns and checks the current path before setting `_active`. The empty-path check leaves the queue inactive; cancellation, removal and failed starts retain their existing behavior.
  5. Loading `[42]` with broken counters and then enqueueing a valid game starts that game. The mixed-list case also completes and drains the repaired queue.
  6. The validated gate receipt reports 569 passed, 0 failed, exit 0.
- Coverage: 3/3 changed files reviewed, none skipped. Examined production initialization in Main, History enqueue/batch counters and status updates, Review prioritization and pause/resume, and the queue's persistence, missing-file defaults, removal, clear, cancellation, successful completion and failed-start paths. Existing fake-runner tests cover sequential work and delayed cancellation. No graphical interaction or live-engine execution was performed during review.
- Test-first proof: `d4b5648` and `3ce63f0` contain tests (the first also commits `implementing`), `6b424dc` contains production only, and `c26d4f6` records the handoff. Independently ran the current queue tests against an isolated copy of the session-base queue: 6 passed, 4 failed, exit 1, including invalid assignments and failure to start a valid game after malformed input. Log: `C:\Users\bruno\AppData\Local\Temp\hist009-stage3-red.log`. Ran the unmodified tests against current production: 10 passed, 0 failed, exit 0; log `C:\Users\bruno\AppData\Local\Temp\hist009-stage3-green.log`. Temporary review files were removed.
- Gate: reused `HIST-009-gate.json`, tested commit `6b424dc358c767e994875d57122fe6765906e957`. `Assert-GateEvidence` verified the bound command, exit status, log hash, exit marker and unchanged non-tracker files. Rebase was already up to date and integration changed no tested code, so the gate was not rerun. The gate skipped one graphical pixel check and six live Lc0 checks because the display or engine was unavailable.
- Proxy records: verified `Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated` and `Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated` against the receipts in Comments. Q8 defines queue filtering, counter repair and the active-game invariant; Q14 confirms the existing persisted-load test seam; Q9 accepts automated verification without Windows manual acceptance.
- Integration: merged locally into `sweatshop/audit-fixes/2026-11-06-1433` as `7062993e24c61695e9039ecb14328d7259ba5f84`; this closure sets `done` and records the merge in the ledger. No push or PR in this stage. Export and CI were not run.

Acceptance: passed | Persisted-load recovery is covered by the isolated red/green logs and the validated gate above, using the automated seam approved in the proxy receipts.
Disclosure: decision | none | The two proxy receipts in Comments approve repairing malformed state on load and using fake runners with temporary storage; no separate Windows manual acceptance is required for HIST-009.
