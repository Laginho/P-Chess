# UI-027: Profile screen to the design
Stage: implementing
Blocked by: UI-021
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
Gate evidence: C:\Users\bruno\AppData\Local\Temp\pchess-ui027-gate.json

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
