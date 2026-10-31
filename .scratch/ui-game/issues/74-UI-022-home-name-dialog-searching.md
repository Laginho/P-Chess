# UI-022: Home, name dialog and searching screen to the design
Stage: done
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/home.gd, ui/home.tscn
  - ui/name_dialog.gd, ui/name_dialog.tscn
  - ui/searching.gd, ui/searching.tscn
  - tests/test_home.gd
  - tests/test_session.gd, tests/test_settings.gd (test-only: node paths that move)

#### What to build

Restyle Home, the first-launch name dialog and the searching screen to `docs/design/v0.1.0/png/Main.png`, `NameDialog.png` and `Searching.png` (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Home matches `Main.png`: the board at the start position on the left; the "P-Chess" title; the "Quick play" label with the Maia level selector; the 2×2 grid of large buttons (1+0, 3+2 and 5+0 in green with their icons, Custom in the raised style); History, Profile, Settings and Quit at the bottom with their icons. Behaviour is unchanged (UI-016, UI-018, UI-019).
2. The name dialog matches `NameDialog.png` over a dimmed Home but keeps the spec's behaviour: prefilled with "You", only OK, blank names refused (§15.8).
3. The searching screen matches `Searching.png`: the board, and a side card with the spinner, "Starting your game", the live status line and the time-control and level chips. The status follows §15.8 ("Pausing analysis…", "Loading Maia 1500…", "Preparing game…"), not the canvas's sample text.
4. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the three boards.

#### Verification

    Manual: screenshot tool for Main, NameDialog and Searching at 1280×800 and 800×600; launch with no `player_name`, then quick-play once.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_home.gd`: Home has the four large buttons and the four bottom buttons, each with its icon, and the level selector reads "Maia <level>" (red where today's Home differs).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`.


- 2026-10-31 Stage 2: Home, first-launch dialog and Searching restyled. Focused tests were committed red before production changes: icons (8 failures), missing-engine layout (1), Profile Settings access (1), theme propagation (6), and restoring layout after the warning hides (1).
- Final gate on `83e6b3a`: `godot --headless -s tests/run.gd`, exit 0, 418 reported passed including 6 Lc0 SKIPs (412 executed).
- Final captures: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-verified-d17186cb-4643-4aac-98eb-709fc243232a/` contains Main, NameDialog and Searching at 1280x800 and 800x600; each used a separate data directory. The 800x600 missing-engine state was also checked at `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-missing-fixed-053ee4dc-f676-43d8-a359-ca9fb5bab399/missing.png`.
- Before captures: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-before-eaa0e393-ab2c-4de1-abe9-900c41460eb8/`. The before NameDialog files are not valid evidence of the dialog because that batch reused the preceding capture's player-name data.

### Foundation review UI-021

The shared `ui/theme/p_chess.tres` FontVariation resources use string `wght` keys (for example lines 112-116). In Godot 4.7, `TextServer.font_get_variation_coordinates()` returns `{}` for that resource; a duplicated variation using numeric OpenType tag `2003265652` returns `{2003265652: 800}`. The selected weights are therefore not applied and the headings and buttons render lighter than the canvas. Probe: `C:/Users/bruno/AppData/Local/Temp/ui022-fontaxes.gd`. This shared theme is outside UI-022's Primary files and must be corrected before integration.

### Visual review UI-022

The native `AcceptDialog` retains its own button height and window layout (the canvas OK button is taller); the level selector lacks the canvas robot icon, and the Searching card uses the shared Godot button/card styles and a rotating fixed arc rather than the canvas's animated arc and exact header/footer decorations. These are observable differences from the references, retained with the existing native dialog and shared theme controls; review against the canvas is still required. One earlier Main capture omitted the board for a frame; a repeat and the final captures rendered it.

Acceptance: pending | Human visual comparison and first-launch/quick-play with an installed Lc0 remain; the screenshots use isolated fixture data and the real engine executable is absent.
Disclosure: pending | integration | [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) - confirmed shared font-variation defect; fix before visual acceptance and integration.
Disclosure: decision | none | [Resolution](#resolution-2026-10-31) - the documented native-control and layout differences were compared with the canvas under shared acceptance item 1; no behavior exception was accepted.
Disclosure: decision | none | [Long-name correction](#long-name-correction-2026-10-31) - the Searching label now fits the card at 800x600 and displays an ellipsis; the full name remains stored.
Disclosure: pending | release | [UI-022 acceptance](#comments) - perform first-launch and a real quick-play with Lc0 installed.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui022-long-name-gate.json

#### Resolution (2026-10-31)
Verdict: Reopen — criterion 4: a valid long player name overflows Searching at 800x600.

##### Standards

No documented-standard violations or actionable smells. Reviewed all eight files in `c3cd2bc...6eb3eca`, including the GDScript, TSCN and Markdown files that OCR excludes as `unsupported_ext`. All changed production and test files are Primary files. The five red/green commit pairs keep tests before production and the handoff is tracker-only. Restored the original criterion text's UTF-8 characters; the contract is unchanged.

##### Spec

- ✅ Criterion 1: Home contains the starting board, title, level selector, 2x2 quick-play grid and four icon-bearing navigation buttons. Traced quick-play settings persistence, Custom, History, Profile and Settings access. The native OptionButton occupies the available half-row, the grid begins 12 px above the reference, and native buttons reserve icon space instead of the canvas's independent icon/text positioning; these remaining visual differences use the existing shared controls and are recorded here under shared acceptance item 1.
- ✅ Criterion 2: the dimmed Home, question, prefilled `You`, only OK, blank-name refusal and persistence remain. The disclosed native AcceptDialog dimensions, content spacing and shorter OK button differ from the canvas; the existing native modal is retained as recorded above.
- ✅ Criterion 3: board, startup card, spinner, title, live status and chips are present. `ui/main.gd` still emits Pausing analysis, Loading Maia and Preparing game in order, waits for readiness before starting the clock and returns to the existing error routes. The previously disclosed spinner/chip/header/footer differences are recorded visual departures, rather than changes to startup behavior.
- ❌ Criterion 4, **P2**, `ui/searching.gd:56-57` / `ui/searching.tscn:61`: set the accepted player name to `Alexandria Catherine Montgomery de Albuquerque`, then start a game at 800x600. The new Player label's intrinsic minimum width overrides its assigned 200 px: its global rect is `(564,466;337x64)`, ending at x=901 while the card ends at x=780 and the viewport at x=800. The right end of the name is lost outside the window. Bound the displayed label with ellipsis/clipping while preserving the full stored name, and add a red-first regression at the existing `tests/test_home.gd` scene seam.
- The shared font-weight defect was reproduced independently: ExtraBoldText stores `{"wght":800}` but TextServer reports no applied axis (`{}`); the same resource duplicated with numeric OpenType tag `2003265652` reports weight 800. This is a confirmed UI-021 criterion-2 miss outside UI-022 Primary files, now scheduled in open [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md). It remains an integration condition.

Standards: 0 findings. Spec: 1 P2 in UI-022; 1 previously disclosed foundation defect routed to CLEAN-012. No production fix was authored in this review; stage 2 resumes the retained branch for the ❌ item.

Coverage included all eight changed files, three reference PNGs and HTML sources, six final captures, missing-engine guidance, Profile/Settings visibility, board-theme propagation, first-launch name validation and persistence, quick-play/Custom/rematch startup, background-analysis pausing, clock readiness and startup failure recovery. Existing modal/settings keyboard tests were inspected; physical input, audio, real Lc0 and Bruno's release QA were not executed. No other identified caller or failure route was left unexamined.

Verification reused the existing gate rather than rerunning unchanged code: the receipt command, exit 0, log SHA-256 and code equality from tested `83e6b3a` through reviewed `6eb3eca` all passed `Assert-GateEvidence`. Its 418 reported passes include six Lc0 SKIPs (412 executed), zero failed. The graphical overflow/font probe exited 0 with isolated data; its log is `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-review-49a91834-fd8a-477e-a4e5-e18183901cda/probe-long-name.log` and the visible failure is `Searching-long-name-800.png` in that folder.

##### Screenshot comparison evidence

The following directories hold the paired screenshots; each row names both window sizes. References are the repository PNGs, before is the session base, and after is the reviewed UI-022 code. The original before NameDialog batch was invalid; fresh captures from detached base `c3cd2bc`, using a separate isolated data directory for each size, supersede it.

| Board | Reference | Before filenames (1280x800 / 800x600) | After filenames (1280x800 / 800x600) |
|---|---|---|---|
| Main | `docs/design/v0.1.0/png/Main.png` | `Main-1280.png` / `Main-800.png` in Before | `Main-1280.png` / `Main-800.png` in After |
| NameDialog | `docs/design/v0.1.0/png/NameDialog.png` | `NameDialog-before-1280.png` / `NameDialog-before-800.png` in Review | `NameDialog-1280.png` / `NameDialog-800.png` in After |
| Searching | `docs/design/v0.1.0/png/Searching.png` | `Searching-1280.png` / `Searching-800.png` in Before | `Searching-1280.png` / `Searching-800.png` in After |

- Before: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-before-eaa0e393-ab2c-4de1-abe9-900c41460eb8/`.
- After: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-verified-d17186cb-4643-4aac-98eb-709fc243232a/`.
- Review: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-review-49a91834-fd8a-477e-a4e5-e18183901cda/`.

No merge or ledger closure: UI-022 returns to `to-implement` on its existing branch. The font follow-up and release acceptance remain explicitly open.


#### Long-name correction (2026-10-31)

The regression test was committed red: the player label overflowed the card and lacked ellipsis. The production scene now clips and ellipsizes the displayed name without changing the stored value. The graphical 800x600 probe measured the label at x=564..764 inside the card at x=500..780; the capture is `C:/Users/bruno/AppData/Local/Temp/ui022-long-name-e3e66035-b361-46c6-a776-89f65437b9d9/Searching-long-name-800.png`.

Gate on `4da5475`: exit 0, 419 reported passed including 6 Lc0 SKIPs (413 executed), 0 failed. Existing foundation and human acceptance disclosures remain open.

- Proxy decided (opus-5.5 xhigh): Approve UI-022 and close it the normal way: merge into the session branch, add the ledger line, set `Stage: done`, and keep the CLEAN-012 disclosure at `pending | integration` — integration means the session PR landing on `main`, and merging into the session branch is not that. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-181515-UI-022-7181c6.json)

#### Resolution (2026-10-31, long-name re-review)
Verdict: Approve

##### Standards

Zero findings. Independent reviewer `/root/standards` examined all five files in `6eb3eca...575183d`, including the three tracker Markdown files, `tests/test_home.gd` and `ui/searching.tscn` that OCR excludes as `unsupported_ext`. Direct review coverage is 5/5 (100%), zero skipped. The new test and scene correction stay within Primary files; the UI-021 history note and CLEAN-012 follow-up preserve the destination of the foundation finding. Test-only `12aca3c` precedes production-only `4da5475`; `575183d` is tracker-only. No actionable baseline smells or new production changes were authored in this pass.

##### Spec

- ✅ Prior criterion-4 P2 resolved: the Player label clips and uses ellipsis inside its assigned width. The existing 800x600 graphical capture shows the long name inside the card; the log measures Player x=564..764 and Card x=500..780. The full name remains stored unchanged. Evidence: `C:/Users/bruno/AppData/Local/Temp/ui022-long-name-e3e66035-b361-46c6-a776-89f65437b9d9/Searching-long-name-800.png` and `godot.log` in that directory.
- ✅ The regression test instantiates the real Main scene, presents Searching at 800x600, and checks card containment, ellipsis and preservation of the complete saved name. The retained test-only commit precedes the two-property production fix; the valid gate records this test passing.
- ✅ Criteria 1–3 retain the previous review's approval. The only new production diff is the Player label's two overflow properties; startup statuses, readiness, error routes and name validation are unchanged. Independent reviewer `/root/spec` examined the delta, Searching layout, startup caller, name validation and test harness: zero new findings or scope creep.
- The separate shared-font defect is still present and scheduled in [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md). It remains a condition before the session PR lands on `main` and before final visual acceptance.

Standards: 0 findings. Spec: 0 remaining UI-022 findings; the previous P2 is resolved. The earlier review's before/reference/after screenshot paths remain valid; the corrected long-name capture above supplements them.

##### Verification and session delivery

`Assert-GateEvidence` passed at pinned `575183d` and again after the no-op rebase onto `sweatshop/ui-game/2026-10-31-1734`. The receipt validates command, exit 0, log SHA-256 and code equality against tested `4da5475`. The log reports 419 passed, including six explicitly skipped Lc0 checks (413 executed), zero failed. The existing gate was reused because production code did not change. Existing graphical evidence was inspected; no fresh runtime or screenshot run was needed for the unchanged correction.

The recorded `Proxy decided (opus-5.5 xhigh)` permits consolidation into the session while preserving CLEAN-012's integration condition on the session PR. Its cited [HIST-001 precedent](../../core/issues/21-HIST-001-history-stats.md) was verified in the repository. No numbered criterion or product requirement changed. CLEAN-012 lives under `ui-base`, so it needs its own stage-2/stage-3 dispatch or a run covering that tracker directory; the `ui-game` lane alone does not complete it.

Merged without squashing into `sweatshop/ui-game/2026-10-31-1734` as `7fc814caa649fc1b3a4d93a476b7db17605f3c4b`. The driver owns pushing and the session PR. This handoff changes only the ticket and feature ledger. No merge into `main` or push was performed.

Acceptance: pending | Human visual comparison after CLEAN-012, and first-launch/quick-play with an installed Lc0, remain.
Disclosure: decision | none | [Workflow decision](#resolution-2026-10-31-long-name-re-review) - the proxy-approved session merge preserves the integration hold on the session PR; it does not waive the font repair or change the numbered criteria.
Disclosure: pending | integration | [CLEAN-012](../../ui-base/issues/74-CLEAN-012-font-variation-axes.md) must be completed and reviewed before this session PR lands on `main`, and before UI-022's visual acceptance. UI-022's criterion-4 long-name finding is resolved by this approval and session merge.
Disclosure: pending | release | Perform first-launch and a real quick-play with Lc0 installed. Physical input, audio and Bruno's final release QA were not performed in this re-review.
