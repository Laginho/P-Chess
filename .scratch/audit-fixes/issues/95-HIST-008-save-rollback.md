# HIST-008: A failed stats write leaves no trace of the game
Stage: done
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

- 2026-11-06: Red focused run: 27 passed, 2 failed, exposing retained files, changed counters and missing removal errors. Green focused run: 29 passed, 0 failed. Gate: 557 passed, 0 failed, exit 0; graphical pixels and six Lc0 checks skipped (headless / engine absent).
- Snapshot-only write failure remains reported while PGN and stats save by inspection; it was not injected dynamically. Crash-safe multi-file recovery is outside the spec.
- Historical acceptance at handoff (superseded by the Resolution below): pending stage 3 review; snapshot-only failure inspected but not injected.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\hist-008-gate.json

#### Resolution (2026-11-06)
Verdict: Approve

- Standards: 0 findings. The independent Standards review examined the complete pinned diff from `7c222b5a0e56f393534d6190fb25a8a1e51f7a0b` to `b6b8b8deb0d86ca8bd6a05697654212474cbfb71`. Changes stay within Primary files plus tracker metadata, follow the existing delete rollback pattern and reuse `_remove()`. No actionable baseline smell or documented-standard violation.
- Spec: 0 findings in the independent Spec review. Criterion 1 passes: the pre-save W/D/L and flag counters and the practice count are restored; newly written PGN and snapshot are removed; failure returns an empty path with an error. Criterion 2 passes: removal attempts are independent and both failures are appended to the stats error. Criterion 3 passes for the approved directory-obstruction seam: win/loss/draw tests preserve existing games and counters, reload after restoring the obstructed stats path, and verify the next successful save counts once. Criterion 4 passes by inspection: snapshot-only errors still permit PGN and stats persistence; rollback runs only for stats failure. Criterion 5 passes with the validated gate below.
- Coverage: 3/3 changed files reviewed, none skipped. Examined the only production `History.save` caller (`Main._show_result`), result/review error display and unsaved-analysis fallback, W/D/L and flag accounting, practice selection counts, snapshot write/read behavior, History game enumeration/cache, shared `_remove()` use in deletion and isolated test cleanup. No production or test edits were made during review. Graphical interaction, live Lc0, real disk-full/permission faults and a snapshot-only runtime fault were not exercised in this review.
- Test-first proof: `a600c74` contains tests plus the `implementing` tracker transition, `44d6a28` changes production only, and `b6b8b8d` records the handoff. Inspected retained logs: `C:\Users\bruno\AppData\Local\Temp\hist-008-red.log` reports 27 passed, 2 failed for retained files/changed counters and missing removal errors; `hist-008-green.log` reports 29 passed, 0 failed. These runs were not repeated.
- Gate: reused the receipt above for tested commit `44d6a28dd852f19e084e5d78f8e9460d9a5c4181`. `Assert-GateEvidence` verified the bound command, exit 0, log SHA-256, exit marker and equality of non-tracker files before and after rebase. The log reports 557 passed, 0 failed; one graphical pixel check and six live Lc0 checks were skipped. No code changed, so no gate rerun was needed.
- Proxy records: reviewed `Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated` and `Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated`, and read both original audit-fixes receipts linked in Comments. The first record's Q5 preserves HIST-003 snapshot-only semantics and excludes crash-safe recovery; Q9 selects automated acceptance without a Windows manual check. The second record's Q14 approves the existing directory-obstruction/reload test seam. The numbered contract is unchanged.
- Integration: rebase onto `sweatshop/audit-fixes/2026-11-06-1433` was already up to date. Integrated locally with merge commit `b37731791f765f748e2c0a48de60faa1c06575b2`; this closure records it in the ledger and sets `done`. No push or PR was made in this stage.

Acceptance: passed | The five numbered criteria pass with the automated evidence and static snapshot-only inspection recorded above; no additional product acceptance is required by this ticket.
Disclosure: decision | none | [Spec decisions and test seams](../spec.md), backed by the two proxy receipts in Comments: ordinary stats-failure rollback, preserved HIST-003 snapshot-only behavior, no crash-safe multi-file recovery, directory-obstruction simulation rather than real disk-full/permission faults, and automated acceptance. Snapshot-only failure remains inspected rather than injected; this introduces no integration or release hold under the agreed verification contract.
