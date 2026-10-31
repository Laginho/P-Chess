# UI-028: Repertoires, opening picker and editor to the design
Stage: blocked
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_screen.gd, ui/repertoire_screen.tscn
  - ui/opening_picker.gd, ui/opening_picker.tscn
  - ui/repertoire_editor.gd, ui/repertoire_editor.tscn
  - tests/test_repertoire.gd, tests/test_catalog.gd

#### What to build

Restyle the repertoire screens to `docs/design/v0.1.0/png/Repertoire.png`, `OpeningPicker.png` and `RepertoireEditor.png` (`.scratch/ui-redo/spec.md`).

#### Acceptance criteria

1. Repertoires: back button and title; Import PGN and From openings (green) at the top right; the repertoires as cards (colour dot, name, "14 lines · from openings" or "· imported PGN", the selected one outlined green), each with a pencil button that opens the editor on it; the lines column (repertoire name, "As Black · 14 lines", each line's name and moves); the board from the repertoire's side, with ←/→ buttons and the line's moves, the current one boxed.
2. The From openings picker is a modal matching `OpeningPicker.png`: the Name field, a White/Black segmented control, the tree with checkboxes (partial state on parents), "N openings selected", Cancel and Create repertoire.
3. The editor matches `RepertoireEditor.png`: the board, and a card with the repertoire's colour dot and name, "Unsaved changes" in gold once edited, the hint line, the indented branch tree with the current move highlighted, a trash button on the hovered branch (right-click delete kept), Cancel and Save.
4. The shared acceptance in `.scratch/ui-redo/spec.md` holds for the three boards.

#### Verification

    Manual: create a repertoire from openings, open it with the pencil, add and delete a branch, save.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: each repertoire card has an edit button that opens the editor on it; the editor shows "Unsaved changes" after a move and not after Save (red: neither exists).

## Comments

- 2026-10-31 Written from `.scratch/ui-redo/spec.md`. The pencil button and "Unsaved changes" are canvas additions adopted in the spec.

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: O UI-028 está **parcialmente implementado** na branch `ui-028`, com o ticket em `Stage: implementing`. As alterações e os testes foram registrados em commits. /  / Os testes focados passaram para os botões de edição, o indicador de alterações, a persistência da origem, a navegação e a exclusão no editor. Ainda faltam ajustes visuais substanciais nas três telas; o seletor também precisa ser capturado após o carregamento do catálogo. /  / O gate completo e a aceitação manual não foram executados. O ticket ainda não está pronto para revisão.

- 2026-10-31 Attempt 2 failed: exit 0; blocked after two attempts. Log tail: O **UI-028 ainda não está concluído**. A branch `ui-028` permanece em `to-implement`, com o trabalho commitado e as pendências registradas no [ticket](<C:/Users/bruno/Desktop/Pastinha/Programas/Projects/P-Chess/.artifacts-build/lanes/ui-screens/.scratch/ui-screens/issues/80-UI-028-repertoire-screens.md>). /  / Adicionei o cabeçalho da coluna de linhas, reorganizei o editor ao lado do tabuleiro e movi as ações do seletor para o rodapé. Os testes focados passaram: **35 aprovados, nenhuma falha**. /  / Ainda faltam a apresentação das linhas e dos cartões, a árvore e o cartão do editor, e o acabamento visual do seletor. Não executei o gate completo nem a aceitação manual; as capturas ainda mostram diferenças relevantes em relação às referências. /  /
