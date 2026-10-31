# UI-027: Profile screen to the design
Stage: blocked
Blocked by: UI-021, UI-030
Review: agent
Difficulty: normal

- Primary files:
  - ui/profile.gd, ui/profile.tscn
  - ui/accuracy_chart.gd
  - the stats reader the profile uses today, only if a new total is needed
  - tests/test_profile.gd
  - docs/spec.md (§15.8, the Profile paragraph)

#### What to build

Restyle the profile to `docs/design/v0.1.0/png/Profile.png`, with the layout Bruno chose on 2026-10-31 (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Name card: the initial avatar, the name, "Playing since <Mon YYYY>" from the first saved game (omitted with no games), and the Name field with Save. Behaviour unchanged (§15.8).
2. Four tiles: Games (total), Avg. accuracy (the mean of your accuracy over analysed games, "–" with none), W / D / L (green / grey / red) and Flag W / L.
3. Results table, headed "Results by level and time control": one row per level that has games; a "W D L" column per time control ("–" when none); then Flag wins and Flag losses per level, summed across time controls.
4. Accuracy over time: the canvas's line-and-dots chart in its card, with the spec's data: every analysed game in date order, a 0–100 axis, the first and last dates labelled, the empty-series message kept.
5. `docs/spec.md` §15.8's Profile paragraph describes the tiles and the per-level flags.
6. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the board.

#### Verification

    Manual: open Profile on a fixture history; rename yourself.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_profile.gd`: the four tiles' values from a fixture history; flags summed per level across time controls; "Playing since" from the first game (red: no tiles).

## Comments

- 2026-10-31 Foreman: the escalated prerequisite is resolved by the owner. The shared font-axis fix was merged to main as PR #37 (CLEAN-012, f0789db; it supersedes UI-030), and the session took it in sync merge 9ad4daf (gate 436 passed, 0 failed). Restoring `to-review` per the re-review's own resume instructions: rebase `ui-027` onto the session, run the gate on the resulting production, recapture populated Profile at 1280x800 and 800x600 and verify the resolved weights.

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. Bruno took the canvas layout and kept the spec's chart (all games, 0–100).
- Stage 2: focused profile tests pass (4/4); the games tile, summary/table and filename-date tests were observed red before their implementations. The former below-scroll Back assertion was updated for the canvas header.
- Gate: 413 reported passed, 0 failed, including 6 Lc0 skips (407 executed); exit 0. Tested commit: b5a9d1fc8a558740ac2a3ab32aee476080ada9fa.
- Screenshot checks: `C:\Users\bruno\AppData\Local\Temp\pchess-ui027-c881251d-7437-4691-8ad3-01a7acfb027c\profile-1280.png` (earlier iteration) and `C:\Users\bruno\AppData\Local\Temp\pchess-ui027-final-87105672-a105-47a1-bf74-c0b09c3b69bc\profile-800.png` (final). The 800px table headings are compact; the fixture has one row and no analysed games. The app-wide Settings control remains visible above the screen. Stage 3 must capture the final 1280px screen, compare a populated fixture to the reference and attach before/after images.
- Acceptance: pending | Manual Profile rename and graphical comparison with populated history, including the 800×600 layout.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\pchess-ui027-reopen-gate.json

#### Resolution (2026-10-31)
Verdict: Reopen — criterion 6: populated Profile does not yet match the design's table, card spacing and typography.

Reviewed `775988aa8fc68f86428baed7c83fb8bce58ee10f...21ff4bd0a0afbbd4f61081fdb7aeddc7a226b1e9` on independent Standards and Spec axes. All six changed files were reviewed manually (100% coverage); OCR excluded all six as unsupported extensions, with none skipped from the actual review. The test-only/production-only commits respect the stage-2 split and all production changes stay in Primary files.

##### Standards

No documented-standard breaches or actionable baseline smells (0 findings).

##### Spec

- Criteria 1–5: pass. Traced Home opening/Back, Settings validation and persistence, History save/stats/delete and legacy human identity, totals and per-level flag sums, first-date fallback, accuracy averaging and ordering, and incomplete/stale/missing/empty analysis. Existing focused tests cover the data paths. A fresh graphical probe through `Viewport.push_input` also passed typed rename with pointer Save, reload from settings, blank-name refusal and Enter submission.
- Criterion 6: ❌ **P2 — table/card styling remains materially different at 1280×800**, at `ui/profile.gd:133` and `ui/profile.tscn:170` (also the other three tiles and ResultsCard). With all nine levels populated, every table cell is 11 px instead of the reference's 12 px bold headers / 14 px body; Level is centered, row dividers and green/red flag values are absent. The table card is 286 px high versus 387 px in the reference, moving the chart to y=382 instead of y=487. Tiles inherit the generic 8×3 px CardPanel padding instead of the reference's 16 px; their two rows occupy 135 px instead of about 186 px. The W/D/L and flag RichTextLabels also use regular 21 px text instead of 22 px at weight 800. Restore the reference's spacing, row sizing, alignment, colours and local typography in the Primary files; preserve usability at 800×600. This is one grouped visual acceptance finding, not separate style nits.
- Criterion 6 also exposes a **shared P2 font-axis defect** at `ui/theme/p_chess.tres:7` (and its other weight dictionaries), routed to [UI-030](../../ui-base/issues/82-UI-030-variable-font-weights.md), outside this ticket's Primary files. `ExtraBoldText` resolves to a FontVariation declaring `{"wght":800}`, but TextServer reports empty variation coordinates; the same font with the integer axis tag reports `{2003265652:800}`. The shared theme therefore renders the headings at the default weight. UI-030 owns the root correction; do not duplicate font resources in Profile to work around it. The original UI-021 review missed this existing defect.
- At 800×600, the complete populated chart is reachable by vertical scrolling, including its first/last dates. No independent clipping/overlap defect was confirmed. The reference's chart sample, last-30 label and 60–100 scale are deliberately replaced by the agreed all-games / 0–100 contract. The app-wide Settings button is outside this screen's scope and is unchanged.

##### Evidence and remaining acceptance

All fresh graphical captures use the same isolated fixture: nine result levels and 30 complete cached analyses. Sample values differ from the reference's illustrative totals. Before is the session base; after is the reviewed final production. Images and probe scripts/logs are retained outside the repo:

| Reference | Before, 1280×800 | After, 1280×800 |
|---|---|---|
| [Profile design](../../../docs/design/v0.1.0/png/Profile.png) | [Before](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/before-1280.png) | [After](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/after-1280.png) |

- Minimum window: [800×600, top](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/after-800.png), [800×600, chart end](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/after-800-bottom.png).
- Probe evidence: `C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/` contains `capture.gd`, `input-probe.gd`, `input-800.log` (PASS), `font-probe.gd` and `font-coords.log`.
- Validated the existing gate receipt, log hash, exit 0 and equality of tested production through reviewed HEAD: 413 reported passed, including six Lc0-dependent skips, hence 407 executed and zero failed. No code changed and the gate was not rerun.
- Not exercised: physical input, audio, live Lc0 and Bruno's release QA. The automated input probe does not claim human acceptance.

Acceptance: pending | Criterion 6 visual correction and UI-030 font fix, then fresh populated comparisons at both sizes; Bruno's v0.1.0 QA remains pending per `.scratch/ui-redo/spec.md`.
Disclosure: pending | integration | Criterion 6 above and UI-030 must be resolved before UI-027 integration. The branch and existing implementation are preserved; no session merge, ledger closure or push was performed.


#### Stage 2 follow-up (2026-10-31)

- Reworked table row typography, left alignment, dividers, flag colours, tile padding and result-card spacing. Compact two-line headings keep the populated table readable at 800x600; resizing and refresh restore the appropriate heading. The summary tiles use the shared extra-bold font variation; its shared axis fix remains UI-030.
- Focused profile test: presentation assertions and compact-heading assertions were observed red before their respective fixes and green afterwards. Corrected a test-harness encoding error that had replaced the middle dot with `?`; the corrected assertion was observed red before fixing production.
- Gate on `c51a2b04a36f3122fd94cea181a07177fe288cd6`: 413 reported passed, 0 failed, including 6 Lc0 skips (407 executed); exit 0. Log: `C:/Users/bruno/AppData/Local/Temp/pchess-ui027-reopen-gate.log`.
- Populated fixture with nine levels and 30 analysed games: [1280x800](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-reopen-committed/profile1280.png), [800x600](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-reopen-committed/profile800.png), [800x600 chart after scrolling](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-reopen-bottom/profile800-bottom.png). Reference and before image remain in the prior review above. The 1280 table card is 387 px high and the chart starts at y=487 as in the reference. The headings wrap at 800 px. The chart data and scale follow the agreed spec rather than the illustrative canvas.
Acceptance: pending | Independent stage-3 comparison after UI-030, manual Profile rename and Bruno's v0.1.0 QA. No physical input or live Lc0 was exercised in this follow-up.
Disclosure: pending | integration | UI-030 must fix the shared font axes before the final visual comparison and UI-027 integration.

#### Resolution (2026-10-31, re-review)
Verdict: Needs your call: local Profile repairs pass; integration waits for the shared font correction UI-030.

Reviewed pinned `775988aa8fc68f86428baed7c83fb8bce58ee10f...3d5e0ce6eab18da8d99b9c73bf3c620c8ee6597b`, concentrating on the prior ❌ and `b22a28e...3d5e0ce`. Independent Standards and Spec reviews covered all seven full-diff files and the four follow-up files (100%, zero skipped); OCR excluded all seven as unsupported extensions, so each was reviewed manually. No production was authored in this review.

##### Standards

0 documented-standard violations; 0 actionable baseline smells. Follow-up commits preserve test-only / production-only separation, including the test-harness encoding correction. Production stays in Primary files. Inspected Home opening/Back, Profile present/refresh, table reconstruction/resize, name validation/persistence, stats aggregation and chart empty/single/complete-series paths; no new regression identified.

##### Spec

- Criteria 1–5: pass, retaining the previous review's data and typed-input evidence. The follow-up changes no data, identity or rename behavior.
- Prior local criterion-6 P2: repaired. Headers/body are 12/14 px, Level aligns left, rows have dividers, flags use green/red, tiles have 16 px padding, and the W/D/L and flag values request 22 px shared ExtraBoldText. Fresh populated 1280×800 rendering measures ResultsCard at (380,84), 876×387, and ChartCard at y=487; 800×600 renders compact two-line headings and reaches the full chart and both dates by scrolling.
- Criterion 6: still ❌ only for the already recorded shared font-axis P2, owned by [UI-030](../../ui-base/issues/82-UI-030-variable-font-weights.md), `ui/theme/p_chess.tres:7` and the other font dictionaries. A fresh probe confirms Title, DisplayName, GamesValue and WdlValue all obtain the shared variation declaring `{"wght":800}`, but its TextServer RID resolves `{}`; the integer-axis comparison resolves `{2003265652:800}`. No Profile workaround is needed. UI-030 is `to-implement`; fresh remote/branch discovery found no active implementation or merged fix. This is the known prerequisite, not a second local implementation finding or a newly discovered defect.
- The chart's all-games/0–100 behavior and the app-wide Settings control retain the prior review's explicit scope disposition.

##### Evidence and remaining acceptance

Same isolated populated fixture: nine result levels and 30 complete cached analyses; illustrative totals differ from the design. The new capture script reuses the prior fixture script, adding only the bottom-scroll capture. All three final captures exited 0.

| Reference | Before, session base 1280×800 | After, reviewed HEAD 1280×800 |
|---|---|---|
| [Profile design](../../../docs/design/v0.1.0/png/Profile.png) | [Before](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/before-1280.png) | [After](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-rereview-a2ce873c-3e35-490c-9b8b-49f1636d8ab6/profile1280.png) |

- Fresh minimum window: [800×600 top](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-rereview-a2ce873c-3e35-490c-9b8b-49f1636d8ab6/profile800.png), [800×600 chart end](C:/Users/bruno/AppData/Local/Temp/pchess-ui027-rereview-a2ce873c-3e35-490c-9b8b-49f1636d8ab6/profile800-bottom.png).
- Capture and font-probe logs: `C:/Users/bruno/AppData/Local/Temp/pchess-ui027-rereview-a2ce873c-3e35-490c-9b8b-49f1636d8ab6/`.
- Reused and validated the existing gate receipt with `Assert-GateEvidence` against reviewed HEAD: tested production `c51a2b04a36f3122fd94cea181a07177fe288cd6`, matching log hash, exit 0, 413 reported passed including six Lc0 skips (407 executed, zero failed). The gate was not rerun because production did not change.
- No new physical input, audio or live Lc0 check; Bruno's v0.1.0 release QA remains pending. Previous typed rename/persistence/blank-name/Enter probe evidence remains valid for unchanged behavior.

Acceptance: pending | UI-030, then final populated graphical comparison at both sizes; physical input and Bruno's v0.1.0 QA remain pending.
Disclosure: pending | integration | UI-030 is required before UI-027 integration. Preserve all UI-027 commits; after bringing the reviewed shared fix onto the loop base and ticket branch, repeat the graphical comparison and obtain valid gate evidence for the resulting production.

##### Escalated prerequisite and resumption

- Proxy escalated (opus-5.5 xhigh): UI-027 can't pass criterion 6 or be merged until UI-030 lands, and UI-030 can't run from this lane. It sits in `.scratch/ui-base/`, the ui-screens driver only runs `ui-screens` tickets (`driver.ps1:282`), the ui-base session is already merged (PR #33), and the ticket isn't on main. Someone has to push to main and start a lane, and that's the owner's or parent's call. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-175503-UI-027-37aba9.json)
- Escalated question for Bruno/the parent: publish UI-030 on main and run a separate ui-base lane (recommended), or explicitly accept changing the existing integration hold into a release condition? No waiver has been accepted. This review preserves the integration hold and changes only this ticket on `ui-027`.
- UI-030's tracker file is currently present on this branch only. A tracker-only commit to the ui-screens session would not make its driver execute a ui-base ticket. Register it on main through the owner/parent, run and review UI-030 in its lane, merge it, then sync main into the ui-screens session.
- Resume after that sync: rebase `ui-027` onto `sweatshop/ui-screens/2026-10-31-1731`; if UI-030's ticket conflicts with this branch's original addition, retain the session's reviewed copy. Clear `blocked` in both the session ticket (if parked by the driver) and the branch ticket, returning to `to-review`; there is no remaining local stage-2 repair.
- The resumed review must run the gate for the new production tree and recapture populated 1280×800 and 800×600 screens, verifying actual resolved font weights before integration. Do not reuse the current pre-UI-030 gate receipt for changed production.
- No session merge, ledger closure, push or edits to another ticket were performed. Related screens also use the shared acceptance; the parent can add UI-030 dependency edges before restarting their lanes.
