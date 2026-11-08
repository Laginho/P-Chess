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

- 2026-11-06 Foreman measured one queue-state rebuild (HIST-007 probe trimmed: 50 finished 40-ply games, 20 cards, fake runner, headless, rendering excluded, 3 runs each, Windows i5-12400F): main f6daf32 438/460/450 ms; session adf06bf 773/792/800 ms. REV-010 adds about 340 ms (positions_from_game per card); main already exceeds the 200 ms bar. Reopen attribution row: session-review, REV-010.
- 2026-11-08 Triaged in a stage-1 grill with Bruno through the proxy. Incremental in-place card rebuild on queue changes; the full-refresh cost moved to HIST-011; agent/hard.
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt /tmp/sweatshop-proxy/20261108-125958-HIST-010-b9505f.json)
- Proxy decided (opus-5.5 xhigh): 3 settled, 0 escalated (receipt /tmp/sweatshop-proxy/20261108-130224-HIST-010-5b620a.json)

Disclosure: deferred | none | The full-refresh cost on open, tab change and delete stays and is tracked in HIST-011.
