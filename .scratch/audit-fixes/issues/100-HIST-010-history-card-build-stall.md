# HIST-010: History card builds stall on queue state changes
Status: needs-triage

HIST-007 measured one visible `_refresh()` with 50 finished 40-ply PGNs, 20 visible cards, a fake runner and rendering excluded at 805?891 ms; cached `history.games()` took 6?10 ms. With a legacy fixture without a `Reason` header, it took about 1.5?1.6 s. Component timings and the probe are recorded in [HIST-007](94-HIST-007-history-rebuild-measurement.md). The independent per-component timings attribute about 331?339 ms to `Analyser.positions_from_game`, 157?161 ms to thumbnail board replay and 285?357 ms to remaining work; the legacy fixture adds about 679?696 ms to `history.reason`. Synthetic saved analysis adds roughly 30 ms in the analysis calls. These are separate microbenchmarks, and the residual is approximate.

`_refresh()` runs for queue state changes, so History can freeze on game start, completion or failure. `positions_from_game` was added by REV-010; the benchmark does not establish how much slower the full path is than `main`.

For the grill (not decided): cache derived per-record data with the parsed record keyed by path, modified time and size; update affected cards in `_queue_changed` instead of rebuilding; or combine both. Candidate bar: a rebuild at most 200 ms on the HIST-007 probe, without a timing assertion in the gate.

Links: [HIST-007](94-HIST-007-history-rebuild-measurement.md), [REV-010](97-REV-010-analysis-cache-validation.md), audit finding 1.
