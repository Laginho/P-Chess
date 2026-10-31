# UI-028: Repertoires, opening picker and editor to the design
Stage: implementing
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
