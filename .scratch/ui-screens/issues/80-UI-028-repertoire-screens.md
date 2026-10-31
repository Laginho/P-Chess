# UI-028: Repertoires, opening picker and editor to the design
Stage: done
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_screen.gd, ui/repertoire_screen.tscn
  - ui/opening_picker.gd, ui/opening_picker.tscn
  - ui/repertoire_editor.gd, ui/repertoire_editor.tscn
  - tests/test_repertoire.gd, tests/test_catalog.gd
  - bot/repertoire.gd (persist and reload source, preserving it through edits)

#### What to build

Restyle the repertoire screens to `docs/design/v0.1.0/png/Repertoire.png`, `OpeningPicker.png` and `RepertoireEditor.png` (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Repertoires: back button and title; Import PGN and From openings (green) at the top right; the repertoires as cards (colour dot, name, "14 lines · from openings" or "· imported PGN", the selected one outlined green), each with a pencil button that opens the editor on it; the lines column (repertoire name, "As Black · 14 lines", each line's name and moves); the board from the repertoire's side, with ←/→ buttons and the line's moves, the current one boxed.
   Repertoires saved before this ticket have no recorded source; their card shows only "N lines", without an origin suffix.
2. The From openings picker is a modal matching `OpeningPicker.png`: the Name field, a White/Black segmented control, the tree with checkboxes (partial state on parents), "N openings selected", Cancel and Create repertoire.
3. The editor matches `RepertoireEditor.png`: the board, and a card with the repertoire's colour dot and name, "Unsaved changes" in gold once edited, the hint line, the indented branch tree with the current move highlighted, a trash button on the hovered branch (right-click delete kept), Cancel and Save.
4. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the three boards.

#### Verification

    Manual: create a repertoire from openings, open it with the pencil, add and delete a branch, save.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: each repertoire card has an edit button that opens the editor on it; the editor shows "Unsaved changes" after a move and not after Save (red: neither exists).
- `tests/test_repertoire.gd`: opening and PGN sources survive reload and editing; a legacy file without source remains loadable and has no source.

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. The pencil button and "Unsaved changes" are canvas additions adopted in the spec.

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: O UI-028 está **parcialmente implementado** na branch `ui-028`, com o ticket em `Stage: implementing`. As alterações e os testes foram registrados em commits. /  / Os testes focados passaram para os botões de edição, o indicador de alterações, a persistência da origem, a navegação e a exclusão no editor. Ainda faltam ajustes visuais substanciais nas três telas; o seletor também precisa ser capturado após o carregamento do catálogo. /  / O gate completo e a aceitação manual não foram executados. O ticket ainda não está pronto para revisão.

- 2026-10-31 Attempt 2 failed: exit 0; blocked after two attempts. Log tail: O **UI-028 ainda não está concluído**. A branch `ui-028` permanece em `to-implement`, com o trabalho commitado e as pendências registradas no [ticket](<C:/Users/bruno/Desktop/Pastinha/Programas/Projects/P-Chess/.artifacts-build/lanes/ui-screens/.scratch/ui-screens/issues/80-UI-028-repertoire-screens.md>). /  / Adicionei o cabeçalho da coluna de linhas, reorganizei o editor ao lado do tabuleiro e movi as ações do seletor para o rodapé. Os testes focados passaram: **35 aprovados, nenhuma falha**. /  / Ainda faltam a apresentação das linhas e dos cartões, a árvore e o cartão do editor, e o acabamento visual do seletor. Não executei o gate completo nem a aceitação manual; as capturas ainda mostram diferenças relevantes em relação às referências. /  /

- Proxy decided (opus-5.5 xhigh): Relaunch the lane so stage 2 picks up branch `ui-028` again for two more attempts. Leave splitting for later. - Both attempts ended on their own, made real progress with green tests, and left a clear checklist. Nothing in them needs the owner, so splitting now would only make a human pull 15 commits that mix all three screens and `bot/repertoire.gd` apart again. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-182157-UI-028-115909.json)
- 2026-10-31 Foreman: attempts 1-2 each ended voluntarily at a checkpoint (exit 0, ~6 min, no question, no denial in the logs). Resume from branch `ui-028` (3bce61b). The work-remaining list on that branch is the checklist: repertoire cards and lines, editor card and move tree, picker styling and checkbox states. Do not end the session at a checkpoint: reach `to-review` only after captures at 1280x800 and 800x600 match the three references, the ticket's manual acceptance, and a gate receipt.

- 2026-10-31 Stage stopped (incomplete handoff): Invalid committed handoff: UI-028: code changed after gate (tests/test_repertoire.gd, ui/repertoire_editor.gd, ui/repertoire_editor.tscn, ui/repertoire_screen.gd, ui/repertoire_screen.tscn); reuse evidence only for identical code. See C:\Users\bruno\Desktop\Pastinha\Programas\Projects\P-Chess\.artifacts-build\lanes\ui-screens\.scratch\run-log\UI-028-implement-20261031-190919.txt.runtime.json and run-log/recovery.txt; inspect the saved work before retrying.
- 2026-10-31 Foreman: the handoff at b0bd516 was parked as "code changed after gate" because the driver reads the first `Gate evidence:` line, the attempt-3 receipt (bfb09c8). The current receipt `ui028-reopen-gate.json` is valid: Code 42fa431 equals production at b0bd516 (only this ticket differs), log SHA-256 matches, ExitCode 0, 433 passed / 0 failed. The stale line is relabelled `Superseded gate evidence:`; Stage restored to `to-review`.
- Proxy decided (opus-5.5 xhigh): Add the seam: an optional `"source"` key in the existing version-1 file, persisted for new saves and carried through edits. A legacy file without the key shows only "N lines", with no origin suffix. — This keeps every existing file loadable. OPEN-005 and OPEN-007 set the precedent of adding `bot/repertoire.gd` to Primary files when the UI needs it. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-180734-UI-028-dca09e.json)
- 2026-10-31 Work in progress: focused tests cover the edit buttons, unsaved marker, source persistence, viewer navigation, editor deletion and minimum sizes. Captures at `C:/Users/bruno/AppData/Local/Temp/pchess-ui028-capture2/` and `C:/Users/bruno/AppData/Local/Temp/pchess-ui028-small/` still differ substantially from the references, notably the lines column and editor; the picker capture was taken while its catalog was loading. Complete and visually verify all three screens before handoff. Gate and manual acceptance have not been run.

- 2026-10-31 Driver retry: attempt 1 ended short of to-review (exit 0). Resume from this branch's commits; edits the stage left uncommitted are saved in run-log/recovery.txt.

- 2026-10-31 Continued implementation: added the selected repertoire heading and side/count above its lines, moved the editor controls beside the board, and moved picker actions to a footer. The new heading test failed before its implementation and passed after it; editor and picker test paths were updated for the layout changes and failed against the prior node layout. Focused `test_repertoire.gd` and `test_catalog.gd`: 35 passed, 0 failed (log: C:/Users/bruno/AppData/Local/Temp/ui028-focused-final.log).
- Work remains before handoff: the repertoire cards and lines still need the reference styling and line presentation; the editor needs the reference card and move-tree presentation; the picker needs its reference styling and clear checkbox states. Captures at C:/Users/bruno/AppData/Local/Temp/pchess-ui028-resume/ show the current layouts (the picker capture waits for the catalog via a temporary capture script). Verify all three at 1280x800 and 800x600, then perform the ticket's manual acceptance and the gate. No gate receipt has been created in this continuation.

- 2026-10-31 Continuation completed: cards and selectable line rows, editor card with compact selectable branches and hover/keyboard delete, and styled opening picker including partial checkboxes. GUI interaction on Windows with isolated data at commit `048605a`: created a repertoire from the loaded catalog, opened it with the pencil, added and deleted a branch, saved a different branch and confirmed it after reopening. Input was injected through the computer-use tool; it was not a physical-input or human visual acceptance. The only later code change before the gate was header sizing in `bfb09c8`.
- Captures of `bfb09c8`, at both 1280x800 and 800x600, are in `C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/`. The picker capture uses a temporary copy of the screenshot script that waits for catalog loading and selects a child to show the partial parent checkbox; its repertoire is shown behind the modal. The fixture uses different names and positions from the canvas. At 800x600 the controls and board remain visible. The picker retains its pre-existing search field, the editor retains a Start position control for returning to the root, and the edit button is a separately focusable button adjacent to the card; these are deliberate differences from the illustration to retain existing functionality and keyboard access.
- Focused repertoire/catalog run: 49 passed, 0 failed before the header-only change. Full gate at `bfb09c8`: 431 reported passed, 0 failed, including 6 Lc0 SKIPs (425 executed); log `C:/Users/bruno/AppData/Local/Temp/ui028-gate-handoff.log`. Lc0 was not installed or downloaded.

Superseded Acceptance: pending | Human visual and physical-input acceptance remains; the GUI flow above used injected input.
Superseded Disclosure: pending | release | Human acceptance of the three screens and physical input remains before v0.1.0, as described in `.scratch/ui-redo/spec.md`.
Superseded gate evidence: C:/Users/bruno/AppData/Local/Temp/ui028-gate-handoff.json

#### Resolution (2026-10-31)
Verdict: Reopen — criteria 1 and 4 fail for Black-start lines and long repertoire names; criterion 3 also fails for the editor's long heading.

##### Standards

No documented-standard violations or actionable smell findings. Reviewed all ten changed files and the complete commit history in `72ad4c47328a89ac236fefd141ccdc727fb6e05d...66c3970c29519fbecc3fffe0de75b15c86c9a773`. Test-only and production-only commits remain separate, and Primary files are respected. The optional version-1 source field retains validation, atomic replacement, existing three-argument callers and legacy loading.

##### Spec

- **P2, criterion 4 (shared acceptance 2), also criterion 3:** `ui/repertoire_screen.tscn:114` and `ui/repertoire_editor.tscn:50` put unbounded repertoire names in the new headings. The valid 99-character name `My favourite repertoire for studying the Caro-Kann Defense and its classical and advance variations`, with `1. e4 e5 *`, makes the viewer 1196x568 and editor 1218x536 in an 800x600 viewport. The viewer's board and the editor's Save fall outside the visible window. Constrain the headings so text cannot enlarge the minimum width, retaining access to the full name. Add a regression through the existing repertoire scenes at 800x600. Graphical proof: [viewer](C:/Users/bruno/AppData/Local/Temp/ui028-spec-probe/viewer-long.png), [editor](C:/Users/bruno/AppData/Local/Temp/ui028-spec-probe/editor-long.png).
- **P2, criterion 1:** `ui/repertoire_screen.gd:232` numbers SAN by array-index parity, ignoring the starting side. The accepted PGN `[SetUp "1"] [FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"] 1... e5 2. e4 *` displays `1.e5 e4`, where the line and navigation must show `1...e5 2.e4`. Derive the numbering from the initial position's side, as the editor already does, and cover the viewer's line text and current-move highlight with a Black-start fixture.
- **Shared pre-existing P2, criterion 4 (shared acceptance 1):** the three captures use regular text where the canvas requires bold weights. The theme's `FontVariation.variation_opentype` dictionaries use string `"wght"` keys, which the installed Godot 4.7 does not apply. A graphical probe gives `Repertoires` at size 28 a width of 152 px for both the default font and the existing 800-weight variation; changing only the axis key to integer `2003265652` gives 166 px and visible bold text. This predates UI-028 and is outside its Primary files; tracked in [CLEAN-012](82-CLEAN-012-theme-font-weights.md), also linked from the closed UI-021 ticket. Do not duplicate the shared-theme repair in these screens.

Criterion dispositions: 1 fails on the Black-start viewer text; the card/edit/source/selection/navigation behavior otherwise matches the contract. 2's fields, segmented choice, partial checkboxes and creation/cancel actions are present; final visual signoff is withheld by the shared font defect. 3 fails for long names; the gold dirty marker, selectable branches, hovered/focused delete, right-click deletion, Cancel and Save are otherwise present. 4 fails on clipping and font weights. The implementation remains on this branch for stage 2; no production fix, merge, push or ledger closure was made in this review.

Coverage: examined every changed script, scene, test and ticket; connected callers include Setup's repertoire/catalog controls, RepertoireImport, Book/catalog loading, BoardView and the repertoire serializer. Traced load/save errors, legacy and invalid source values, source retention after editing, card/pencil selection, SAN/FEN roots, board orientation, viewer stepping, branch selection/deletion and deferred refresh, keyboard access to delete, dirty-state/save/cancel, picker filtering/partial parents and minimum-window layout. The invalid-filename picker error was also rendered at 800x600: the popup grows to 702 px and its right edge remains at x=782, so that case is not a finding. Independent Standards reviewer: `/root/standards`; Spec reviewer: `/root/spec`; root additionally verified the font rendering and screenshots. Physical input, screen-reader acceptance, audio and live Lc0 play were not examined.

Both existing proxy decisions were examined: `Proxy decided (opus-5.5 xhigh): Relaunch the lane so stage 2 picks up branch ui-028 again for two more attempts` explains retaining the implementation after the earlier checkpoints; `Proxy decided (opus-5.5 xhigh): Add the seam: an optional source key in the existing version-1 file` is reflected in the Primary files, criterion 1 and persistence tests. Their original receipt-backed records above are preserved; this review adds no proxy decision.

Verification: the external graphical probe `C:/Users/bruno/AppData/Local/Temp/ui028-spec-probe/probe.gd` exited 0 and its `godot.log` records both failures and dimensions. The font probe and PNG are under `C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/font-compare.{gd,log,png}`. The existing gate receipt was validated with `Assert-GateEvidence` against the reviewed HEAD: command, tested commit `bfb09c8`, exit 0, log SHA-256 and unchanged production all match. Its log reports 431 passed, 0 failed, including six Lc0 SKIPs (425 executed). The full gate was reused, not repeated; the green suite does not cover these two failure cases. Stage 2 must provide red/green regression proof and a new gate receipt after repairs.

Screenshot comparison: before is the archived session base `72ad4c4`; after is tested production `bfb09c8` (identical to reviewed HEAD). The before capture script selects the displayed line and waits for the picker catalog; picker fixtures select different openings, which is sample data rather than a design difference. All captures use isolated data roots. Columns below put each reference next to the before/after paths; the 800x600 rows check usability against the same design reference.

| Screen / size | Reference | Before | After |
| --- | --- | --- | --- |
| Repertoire 1280x800 | [PNG](../../../docs/design/v0.1.0/png/Repertoire.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/before-Repertoire-1280x800.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/Repertoire-1280x800.png) |
| Repertoire 800x600 | [PNG](../../../docs/design/v0.1.0/png/Repertoire.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/before-Repertoire-800x600.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/Repertoire-800x600.png) |
| OpeningPicker 1280x800 | [PNG](../../../docs/design/v0.1.0/png/OpeningPicker.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/before-OpeningPicker-1280x800.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/OpeningPicker-1280x800.png) |
| OpeningPicker 800x600 | [PNG](../../../docs/design/v0.1.0/png/OpeningPicker.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/before-OpeningPicker-800x600.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/OpeningPicker-800x600.png) |
| RepertoireEditor 1280x800 | [PNG](../../../docs/design/v0.1.0/png/RepertoireEditor.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/before-RepertoireEditor-1280x800.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/RepertoireEditor-1280x800.png) |
| RepertoireEditor 800x600 | [PNG](../../../docs/design/v0.1.0/png/RepertoireEditor.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/before-RepertoireEditor-800x600.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/pchess-ui028-handoff/RepertoireEditor-800x600.png) |

Superseded Acceptance: pending | The two UI-028 regressions above and the shared font defect prevent implementation approval; the previously disclosed human visual and physical-input acceptance also remains.
Superseded Disclosure: pending | integration | Correct the two UI-028 findings before integrating this ticket; preserve the branch's existing work and tests.
Superseded Disclosure: pending | integration | CLEAN-012 tracks the shared font-weight defect required by this ticket's visual acceptance; no deferral has been accepted.



- 2026-10-31 Reopen implementation: the viewer now numbers a Black-start line from its starting side, including the selected move and accessible description. Both scene headings use ellipsis and expose the full name in their tooltip. The existing full text remains on the label.
- Red/green: `258286e` failed on all four Black-start text/highlight assertions before `60e4d77` passed the focused Black-start and White-start checks. The larger temporary focused runner was interrupted after the red failure because an unrelated asynchronous test did not finish; the two-test runner exited 0. `21269b1` failed on both minimum-window sizes and both tooltips before `42fa431` passed. The complete gate subsequently passed both new tests.
- Graphical probe at `42fa431`: at 800x600 the viewer is 768x568 and editor 736x536; the board and Save remain visible with the 99-character name. Captures and output: `C:/Users/bruno/AppData/Local/Temp/ui028-reopen-probe/`. This is automated rendering, not physical-input or human acceptance.
- Gate at `42fa431`: 433 reported passed, 0 failed, including six Lc0 SKIPs (427 executed). Log: `C:/Users/bruno/AppData/Local/Temp/ui028-reopen-gate.log`.

Superseded Acceptance: pending | Human visual and physical-input acceptance remains; CLEAN-012 remains a shared visual defect.
Superseded Disclosure: pending | integration | CLEAN-012 tracks the shared font-weight defect required by the visual acceptance; no deferral has been accepted.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui028-reopen-gate.json

- Proxy decided (opus-5.5 xhigh): Accept a release-level deferral of the shared font weights to CLEAN-012, so UI-028 can merge into the session once the Spec re-review is clean. The defect already exists on `main` from UI-021, sits outside UI-028's Primary files and affects every v0.1.0 screen; shared acceptance 1 allows a remaining difference listed with a reason; and v0.1.0 is tagged only after Bruno's QA, so the fix stays a release condition. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-191927-UI-028-561703.json)
- 2026-10-31 Remaining difference (shared acceptance 1): headings and primary-button text render at the regular weight instead of the canvas's 600-800. Reason: `ui/theme/p_chess.tres`, outside this ticket's Primary files, declares its weights with string `"wght"` keys that Godot 4.7 ignores; the repair is CLEAN-012. The proxy accepts a release-level deferral for session integration; v0.1.0 waits for the shared correction and its post-correction captures.

#### Resolution (2026-10-31)
Verdict: Approve

##### Standards

Independent reviewer `/root/standards`: 0 documented violations and 0 actionable smells. Reviewed all 12 files in `72ad4c4...51f18fa`, the full commit statistics and the delta since the previous review at `66c3970`. The Black-start cycle `258286e` -> `60e4d77` and long-heading cycle `21269b1` -> `42fa431` preserve separate test-only and production-only commits. New tests exercise the actual scenes with literal expectations. Source persistence remains compatible with existing callers and legacy files. No production was authored during this review.

##### Spec

Independent reviewer `/root/spec`: both local P2 findings are resolved, with no new finding in the eight-file delta since `66c3970`. Criterion 1 now numbers the Black-start fixture `1...e5 2.e4`, including the accessible line description and current-move highlight before and after Previous. Criteria 3 and 4's minimum-window finding are resolved: both headings use ellipsis and retain the full name in text and tooltip; at 800x600 the viewer is 768x568 and editor 736x536, with the board and Save visible. Criteria 1-3 otherwise retain the previous review's passing dispositions. Criterion 4 is accepted for session integration with the shared font-weight difference explicitly listed and deferred to CLEAN-012 by the receipt-backed proxy decision above; it remains a release condition. No numbered criterion was rewritten.

Prior decisions examined: `Proxy decided (opus-5.5 xhigh): Relaunch the lane` preserves the earlier implementation; `Proxy decided (opus-5.5 xhigh): Add the seam` authorizes the optional version-1 source field and legacy behavior. The new `Proxy decided (opus-5.5 xhigh): Accept a release-level deferral` accepts the font difference for the owner because it predates this ticket, affects all screens and belongs in the shared theme. All original receipt-backed records are preserved. CLEAN-012 is moved to this lane as [ready follow-up work](82-CLEAN-012-theme-font-weights.md), with unchanged production scope and test seam. Its correction, all required post-correction captures and Bruno's visual/physical-input acceptance must precede v0.1.0.

Verification: the Spec reviewer independently ran both new regression methods at `51f18fa`: 2 passed, 0 failed, exit 0. Fresh graphical probe and inspected PNGs are in `C:/Users/bruno/AppData/Local/Temp/ui028-rereview-spec-23b5cca7c4704009900ff1fcff725c66/` (`focused.log`, `probe.log`, `viewer-long.png`, `editor-long.png`). Root also inspected both PNGs. The existing six-screen/size reference-before-after table above remains the comparison for the redesign; the repaired long-heading cases are attached below. The injected-input creation/edit/delete/save evidence above remains distinct from human acceptance.

| Screen / 800x600 long-name case | Reference | Before repair | After repair |
| --- | --- | --- | --- |
| Repertoire | [PNG](../../../docs/design/v0.1.0/png/Repertoire.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-spec-probe/viewer-long.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-rereview-spec-23b5cca7c4704009900ff1fcff725c66/viewer-long.png) |
| RepertoireEditor | [PNG](../../../docs/design/v0.1.0/png/RepertoireEditor.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-spec-probe/editor-long.png) | [PNG](C:/Users/bruno/AppData/Local/Temp/ui028-rereview-spec-23b5cca7c4704009900ff1fcff725c66/editor-long.png) |

Gate evidence was reused and validated with `Assert-GateEvidence` against reviewed and rebased code: command, tested commit `42fa431`, exit 0 and log SHA-256 match; 433 reported passed, 0 failed, including 6 Lc0 SKIPs (427 executed). Rebase onto session `6a22901` resolved only ticket metadata and retained both foreman comments. Production is identical to the tested commit. Integrated without squash as `f3fc7d97afbc0985c8a6469dedc55bd79f522fd3`; this closure changes tracker metadata only. The driver owns pushing and the session PR.

Coverage: all 12 Git-diff files accounted for, 12 manually reviewed, 0 skipped. OCR delegate excluded every file as `unsupported_ext`; its default rules were read and the analysis was performed by Codex. The re-review covered the complete subsequent delta, both repaired paths and new regressions; the first review's caller/failure-path coverage remains above. The final tracker-only closure, ledger, disclosures and relocated follow-up were independently checked by `/root/standards`, with no findings. Physical input, screen-reader acceptance, audio and live Lc0 play were not checked. Bold fonts may increase text widths, so CLEAN-012 requires fresh captures of all three screens at both sizes and both long-name cases before release.

Acceptance: pending | Human visual and physical-input acceptance of the three screens remains, after CLEAN-012's post-correction captures.
Disclosure: deferred | release | Shared font weights (criterion 4 via shared acceptance 1) deferred to CLEAN-012, accepted by the proxy for the owner (receipt in the comment above): pre-existing since UI-021, outside Primary files, inherited by every v0.1.0 screen. Session integration allowed; v0.1.0 waits for CLEAN-012 and its post-correction captures of Repertoire, OpeningPicker and RepertoireEditor at 1280x800 and 800x600, plus the 99-character name at 800x600 in viewer and editor.
Disclosure: pending | release | Human acceptance of the three screens and physical input remains before v0.1.0, as described in `.scratch/ui-redo/spec.md`.

Disclosure: decision | none | The font-weight release condition above is resolved: CLEAN-012 landed on main as PR #37 and was synced at 9ad4daf. Foreman post-correction captures of Repertoire, OpeningPicker and RepertoireEditor at 1280x800 and 800x600 (standard fixture) are in C:\Users\bruno\AppData\Local\Temp\pchess-ui-screens-shots\after, with the lane base in \before. Not retaken: the 99-character-name captures at 800x600. Observed, not judged: at 800x600 the app-wide Settings button shows above the editor modal\'s top edge.
