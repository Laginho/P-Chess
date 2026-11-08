# HIST-011: History's full refresh is slow on open, tab change and delete
Status: needs-triage
Blocked by: HIST-010

HIST-010 rebuilds only the affected cards on a queue state change. `present`, tab change and delete still run the full `_refresh()`, which builds every visible card (20).

HIST-007 measured that full refresh (50 finished 40-ply PGNs, 20 visible cards, fake runner, headless, rendering excluded, Windows i5-12400F): 805–891 ms with normal saved games, about 1.5–1.6 s with the legacy fixture without a `Reason` header. Per 20 cards: `Analyser.positions_from_game` 331–335 ms, thumbnail board replay 159–161 ms, `history.reason` 0.1 ms (679–696 ms on the legacy fixture), analysis reads 3–31 ms, residual 306–357 ms. Probe and full output in [HIST-007](94-HIST-007-history-rebuild-measurement.md).

For triage (not decided): whether this cost matters is Bruno's call. It carries no release hold; HIST-007's hold covered the queue-state stall, which [HIST-010](100-HIST-010-history-card-build-stall.md) fixes. Candidate: (a) cache derived per-record data (positions, reason, thumbnail, analysis state) keyed by path, modified time and size. The residual (306–357 ms, node building and the rest) stays even with every replay cached, so (a) alone would not reach a 200 ms bar; any bar is set at triage.

Links: [HIST-010](100-HIST-010-history-card-build-stall.md), [HIST-007](94-HIST-007-history-rebuild-measurement.md), [REV-010](97-REV-010-analysis-cache-validation.md).

## Comments

- 2026-11-08 Opened from the HIST-010 grill (round 1 Q2, proxy receipt /tmp/sweatshop-proxy/20261108-125958-HIST-010-b9505f.json). No Stage: waits for Bruno's triage, as HIST-010 did.
