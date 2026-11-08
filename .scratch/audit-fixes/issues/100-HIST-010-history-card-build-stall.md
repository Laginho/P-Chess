# HIST-010: History card builds stall on queue state changes
Stage: implementing
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: hard

- Primary files:
  - ui/history_screen.gd (`_queue_changed`, `present`, an in-place card replace)
  - tests/test_history_screen.gd

#### What to build

When the analysis queue changes state (a game starts, finishes or fails, a game is queued or removed), History rebuilds in place only the visible cards whose analysis state changed: a path that entered or left `pending`, plus the old and new `current`. It no longer frees and rebuilds the whole page, so History stops freezing while a batch runs. `present`, a tab change and a delete keep the full `_refresh()`. Their cost is [HIST-011](123-HIST-011-history-full-refresh-slow.md).

Background: HIST-007 measured one visible `_refresh()` with 50 finished 40-ply PGNs, 20 visible cards, a fake runner and rendering excluded at 805?891 ms; cached `history.games()` took 6?10 ms. With a legacy fixture without a `Reason` header, it took about 1.5?1.6 s. Component timings and the probe are recorded in [HIST-007](94-HIST-007-history-rebuild-measurement.md). The independent per-component timings attribute about 331?339 ms to `Analyser.positions_from_game`, 157?161 ms to thumbnail board replay and 285?357 ms to remaining work; the legacy fixture adds about 679?696 ms to `history.reason`. Synthetic saved analysis adds roughly 30 ms in the analysis calls. These are separate microbenchmarks, and the residual is approximate.

`_refresh()` runs for queue state changes, so History can freeze on game start, completion or failure. `positions_from_game` was added by REV-010; the benchmark does not establish how much slower the full path is than `main`.

Settled by the grill of 2026-11-08: caching derived per-record data on its own cannot reach the bar, because HIST-007's residual is 306–357 ms even with every replay cached. One card costs about 40 ms (80 ms on the legacy fixture), and each queue emit touches at most one card, since `_finished` and `_start_next` emit separately.

#### Acceptance criteria

1. A queue state change (start, finish, failure, enqueue, remove) rebuilds only the affected visible cards defined above. Other cards, date headings, tab counts and the scroll offset are untouched: unaffected cards are the same instances as before. `present`, a tab change and a delete still run the full `_refresh()`. `present` sets `_queue_state = []` and goes through `_queue_changed`, so it must still end in a full refresh.
2. A rebuilt card keeps its position in the list, its selection checkbox state and its keyboard focus. Paging ("Show 20 more") and the inline delete confirmation behave as before.
3. Stage 2 reruns the HIST-007 probe outside the gate for one queue state change, on the normal and the legacy fixture. It adds one informational row for "Analyze all" over the 50 games (today each `enqueue` emits `changed`, so this is probably one full refresh per game). The results and the machine go in Comments. Target: at most 200 ms per queue state change. No timing assertion in the gate.
4. The gate is green.

#### Verification

    HIST-007 probe (see 94-HIST-007), results in Comments
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- tests/test_history_screen.gd: with History visible and a fake runner, one game finishes and the next starts. The finished card shows its accuracy, the next one shows Analysing, and an unrelated visible card is the same instance (`is_instance_valid`, same object) as before the change. Red today because `_refresh()` frees every card.
- tests/test_history_screen.gd: a card rebuilt by a queue change keeps its selection checkbox state and its keyboard focus.

## Comments

- 2026-11-08 Stage 2 scope: `_queue_changed` is connected to `analysis_queue.changed` and called by `present`; `_add_card` is shared with paging. Keep full refresh for `present`, tabs, deletion, resize and catalog completion. Test real queue transitions with the existing fake-runner seam, including unchanged cards/headings, queued ordinals, empty/off-page changes, paging, selection, focus and inline deletion. No caller or persistence API changes.
- Test-first: `edbaea5` adds the finish/start regression and the `implementing` transition. Against the original production code, `hist010-red.log` reports 18 passed, 1 failed: unrelated card, still-queued card and date heading were replaced. Production commit `346fc3d` passes 19/0 (`hist010-green.log`).
- Interaction coverage: test-only `b02ae78` covers selection, focus, scroll after layout, 40 loaded cards, the paging footer, failure/retry/removal with inline confirmation, hidden/present and empty History. Running these tests against the original production file gives 18 passed, 2 failed (`hist010-interaction-red.log`); it does not report script errors. Additional test-only `ebbc7dd` exposes unnecessary rebuilding of the current card when another game is enqueued or removed (19 passed, 1 failed, `hist010-active-red.log`). Production `b82c8c9` passes 20/0 (`hist010-interaction-green.log`). All logs are under `C:\Users\bruno\AppData\Local\Temp`; temporary test copies and the baseline production replacement were removed/restored.
- Performance probe at `b82c8c9`: `C:\Users\bruno\AppData\Local\Temp\hist010_probe.gd`, output `C:\Users\bruno\AppData\Local\Temp\hist010-probe-results.txt`, exit 0. Godot 4.7.stable.official.5b4e0cb0f, Windows, Intel Core i5-12400F, 15.8 GiB usable RAM. Reuses HIST-007's exact 40-ply opening with 50 temporary PGNs, 20 visible cards, warmed parsed records and a held fake runner. Normal games have Result=1-0, Reason=resignation and Termination=Normal; legacy games omit Reason/Termination and use Result=*. No saved analysis cache or real engine. Rendering is excluded: no frame is awaited within a timed operation.
- Probe method: enqueue measures one `changed.emit()` after adding a visible path to `_items` and updating `batch_total`, as in HIST-007; it excludes queue persistence/start. Start measures `_start_next()` with the fake runner; failure emits the fake runner's `finished(false, ...)` signal through the real queue. Each has one queue state transition. Analyze all is the real toolbar button over all 50 initially unanalysed games after clearing the queue, including validation, enqueue/persistence and every synchronous UI callback. All six runs reach 50 queued games. Each individual transition is below 200 ms; no timing assertion was added to the gate.

| Fixture / run | Enqueue state (ms) | Start (ms) | Failure (ms) | Analyze all 50 (ms, informational) |
| --- | ---: | ---: | ---: | ---: |
| Normal 1 | 43.417 | 43.399 | 50.441 | 2002.030 |
| Normal 2 | 48.357 | 56.506 | 80.782 | 1987.396 |
| Normal 3 | 42.968 | 41.826 | 42.798 | 2180.724 |
| Legacy 1 | 78.948 | 83.094 | 91.530 | 2870.459 |
| Legacy 2 | 93.537 | 98.543 | 109.369 | 3117.037 |
| Legacy 3 | 75.518 | 77.186 | 79.542 | 2987.985 |

- Remaining measured limit: Analyze all still takes about 2.0–3.1 seconds synchronously for these 50 games. Criterion 3 requests an informational total, not a batch latency target. Full refresh on present, tab change and delete remains the separate HIST-011 scope.

- 2026-11-06 Foreman measured one queue-state rebuild (HIST-007 probe trimmed: 50 finished 40-ply games, 20 cards, fake runner, headless, rendering excluded, 3 runs each, Windows i5-12400F): main f6daf32 438/460/450 ms; session adf06bf 773/792/800 ms. REV-010 adds about 340 ms (positions_from_game per card); main already exceeds the 200 ms bar. Reopen attribution row: session-review, REV-010.
- 2026-11-08 Triaged in a stage-1 grill with Bruno through the proxy. Incremental in-place card rebuild on queue changes; the full-refresh cost moved to HIST-011; agent/hard.
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt /tmp/sweatshop-proxy/20261108-125958-HIST-010-b9505f.json)
- Proxy decided (opus-5.5 xhigh): 3 settled, 0 escalated (receipt /tmp/sweatshop-proxy/20261108-130224-HIST-010-5b620a.json)

Disclosure: deferred | none | The full-refresh cost on open, tab change and delete stays and is tracked in HIST-011.
