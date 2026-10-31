# HIST-006: The analysis queue
Stage: to-implement
Blocked by: REV-002, HIST-004
Review: agent
Difficulty: hard
Gate evidence: C:\Users\bruno\AppData\Local\Temp\hist006-final-gate.json
Acceptance: pending | Manual batch pause/resume and app restart with Stockfish installed; see Verification below.
Disclosure: pending | release | [HIST-006 manual verification](61-HIST-006-analysis-queue.md): real Stockfish and interactive batch pause/restart remain to be checked.

- Primary files:
  - New: core/analysis_queue.gd
  - ui/history_screen.gd, ui/history_screen.tscn
  - ui/review.gd (Analyze jumps the queue)
  - ui/main.gd (pause while a game is played)
  - core/settings.gd (`analysis_threads`)
  - ui/settings.gd (its row)
  - New: tests/test_analysis_queue.gd
  - tests/test_settings.gd
  - docs/spec.md (§15.7, §15.10)

#### What to build

Games can be queued for analysis from the history, alone or in batches, and are analysed one at a time in the background (§15.7).

#### Acceptance criteria

1. Each card gets Analyze, or Re-analyze when its analysis is stale; cards can be multi-selected with "Analyze selected"; each tab has "Analyze all", which queues that tab's unanalysed and stale games.
2. Games run one at a time with the `analysis_threads` setting (Background, 1 thread, by default; or Max).
3. Cards show queued and "analysing x%"; a status line reads like "Analysing 2 of 7 · Background".
4. Review on a queued game, or Analyze in the review of an unqueued one, runs that game first on Max; the batch then resumes where it stopped, on its own setting.
5. The queue pauses when a game starts and resumes after it ends; the game never waits on Stockfish.
6. The queue survives restarting the app: queued games are still queued, and a game cut off mid-analysis starts over.
7. A game deleted while queued leaves the queue.

#### Verification

    Manual: Analyze all on a tab, start a game mid-batch, finish it, check it resumes; restart the app mid-batch.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_analysis_queue.gd`, with a fake analyser: order and one-at-a-time; a jump-ahead runs on Max then the batch resumes; pause/resume around a game; a saved queue reloads; a deleted game leaves it (red: no queue).
- `tests/test_settings.gd`: `analysis_threads` default and choices.

## Comments

- 2026-10-30 Written from spec §15.7 and §15.10.


- Stage 2: the serial/persistence test failed before the queue existed; the priority and settings tests failed before their implementations. A temporary removal of the active guard made the delayed-cancellation test fail. The prior history-review test now injects the shared queue analyser, preserving its Max assertion.
- Final gate at 6f7d6f8: 365 passed, 0 failed, exit 0; the real Stockfish executable is absent in this checkout. The cached queued-review test failed before the priority fix and passed afterwards.

#### Stage 3 review (2026-10-31)

Verdict: Reopen — criterion 3 lacks batch progress; post-game current-cache reuse regressed.

Reviewed `83a815cf2efb6773ae93ebc689b8729c2e601d04...bd87a8a48677532cb84c2f610ada7383618086bc`, the session merge-base through the stage-2 handoff. All 11 changed files were read; none skipped. No production behavior was authored during review. The implementation commits remain on `HIST-006-analysis-queue`; no merge or ledger entry was made.

Standards: no blocking documented violation. All 11 commits separate tests, production and tracker metadata. The existing history-review test adaptation preserves its assertions and is permitted by the test-only Primary-file exception in `ticket-flow/stage2.md`.

Spec findings, all in this pass:

- **P2 — Current cache bypassed in post-game Review**, `ui/review.gd:130-137`. With a saved PGN and a current analysis file, `open_analysis()` unconditionally prioritizes the PGN and returns before the previous `_check_engine()` cache-read path. This regresses [REV-005 criterion 6](57-REV-005-review-screen-core.md): an existing nonstale analysis is read instead of recomputed. For example, analyse the saved PGN with `scripts/analyse.gd` before requesting its post-game Review. The production-path probe used a matching three-position cache (`Stockfish 19`, 3000000 nodes): it reported `CACHE_STATE=analysed`, then a new Max runner start and `CACHE_FIRST_POSITION_LOADED=false`. The base implementation loaded that same fixture with zero analyser-factory calls. Reuse current cache for an ordinary, nonqueued post-game entry; retain HIST-006 criterion 4's promotion of already queued games, including cached ones, and explicit Analyze. Cover a real `<saved PGN>.json` path with a corresponding PGN and shared queue: `tests/test_review.gd:489` currently uses an unrelated cache filename, so it takes the old fallback and misses this regression.
- **P2 — Batch ordinal and total absent**, `ui/history_screen.gd:167`. Criterion 3 requires a status like `Analysing 2 of 7 · Background`. After completing one game in a seven-game batch, the probe reported `batch_done=1`, `batch_total=7`, but the UI showed only `Analysing · 6 queued · Background`. Use the queue's batch counters for the ordinal and original total; initialize the status when presenting/restoring an existing queue as well as on subsequent changes. Add a focused UI regression for advancement and restored/presented state.

Criterion verdicts:

1. ✅ Analyze/Re-analyze, selection and tab-filtered Analyze all are present.
2. ✅ Serial execution and Background/Max settings are implemented; synchronous and delayed cancellation are covered.
3. ❌ Card states are present, but the required batch ordinal and total are missing.
4. ✅ Queued Review and explicit Analyze prioritize Max; the remaining batch resumes with its own setting. The cached queued-game fix is present and must be preserved.
5. ✅ Game start pauses without awaiting cancellation; completion, setup return and failed startup resume the queue.
6. ✅ Pending paths, priority and counters persist; a restored in-flight game starts from the beginning in the production runner.
7. ✅ Missing PGNs are removed by the periodic scan; deleting an active entry waits for cancellation before starting another.

Coverage: examined queue enqueue/priority/removal and success/cancel/start-failure/engine-stop paths; Main startup/result/setup/engine-failure callers; history filtering, selection and cache-state display; post-game and history Review entry, cache reuse and incremental positions; settings; analyser validation/handshake/cancellation/output; and UCI search/stop/cleanup. No rendered layout, physical input, long-batch responsiveness, real Stockfish run or interactive restart acceptance was performed.

Verification: validated the existing receipt `C:\Users\bruno\AppData\Local\Temp\hist006-final-gate.json`, its available tested commit `6f7d6f819b5b7fafd8a74366a3d43bef15c8e205`, unchanged non-tracker files, matching SHA256 and `ExitCode: 0`. Its log prints **365 passed, 0 failed**; the gate was reused, not rerun. Focused observational Godot 4.7 probes both exited 0 without script errors; their printed state demonstrates the two defects, rather than acceptance success. Probe/log pairs: `C:\Users\bruno\AppData\Local\Temp\hist006-stage3-review-probe.gd` / `.log` and `C:\Users\bruno\AppData\Local\Temp\hist006-stage3-base-cache-probe.gd` / `.log`. The latter loads the base Review script from an external temporary file. Each probe removed its isolated queue/cache/PGN fixtures.

Disclosure: pending | integration | [Stage 3 review](#stage-3-review-2026-10-31): restore current-cache reuse for nonqueued post-game Review without undoing queued-game promotion.
Disclosure: pending | integration | [Stage 3 review](#stage-3-review-2026-10-31): satisfy criterion 3's batch ordinal/total status, including presentation of a restored queue.
