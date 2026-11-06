# HIST-007: Measure History's rebuild during analysis, fix only if it stalls
Stage: implementing
Status: ready-for-agent
Blocked by: HIST-008, REV-010
Review: agent
Difficulty: normal

- Primary files:
  - ui/history_screen.gd (`_refresh`, `_queue_changed`)
  - core/history.gd (`games`), only if the cache is built
  - tests/test_history_screen.gd, tests/test_history.gd

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 1. The audit measured 3,857 ms per progress event on the old path, which rebuilt History on every event. Since PR #41, progress updates the active card in place, and `_refresh()` runs only when the queue state changes: a game starts, finishes or fails. Each rebuild still reparses every saved PGN through `history.games()`. Measure what one rebuild costs now, and fix it only if it stalls.

#### Acceptance criteria

1. Stage 2 measures one `_refresh()` at HEAD (after REV-010) with History visible and 50 valid 40-ply saved games. It uses a probe outside the gate: generated PGNs in temporary storage, a fake engine runner and one queue state change, with rendering time excluded. The probe script and its output go in Comments, inline or as a pasted log, together with the machine it ran on.
2. If one rebuild takes **200 ms or less**, the ticket ends with that measurement and no source change.
3. If it takes longer, parsed records are cached and reused across rebuilds while a file is unchanged. The cache key is the path plus the modified time **and** the size, because Godot's modified time has whole-second resolution. Run the probe again and record the result.
   - A changed, added or deleted game still shows correctly on the next rebuild.
   - Focus, selection, paging and the inline delete confirmation behave as today.
4. No timing assertion goes into the gate.
5. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- Only if criterion 3 applies, in tests/test_history_screen.gd or tests/test_history.gd:
  - After a rebuild, rewrite a game's PGN, setting the modified time explicitly or changing its size. The next rebuild shows the new content.
  - A deleted game disappears.

  These tests pass on today's uncached code, so they cannot be red first. Write them first, confirm they pass now, and keep them green through the cache change.

## Comments

- 2026-11-06 Written from the grill ([spec](../spec.md)). Both endings are valid: measurement-only (â‰¤ 200 ms) or the cache.
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)
