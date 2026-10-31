# UI-029: Visible labels on fields that only have placeholders
Stage: to-implement
Status: ready-for-agent
Blocked by: UI-021, UI-028
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_import.tscn ("PGN file", "Repertoire name …")
  - ui/opening_picker.tscn ("Selection name")

#### What to build

Some text fields are identified only by their placeholder text, which disappears once the user types (WCAG 1.3.1 / 3.3.2). Give each such field a visible label (as Profile's "Your name" row already does), so the placeholder is only a hint.

Raised in the PR #33 review (UI-021). The placeholder token itself was lightened to `#8a857c` (4.5:1) in that PR.

#### Acceptance criteria

1. Every LineEdit/TextEdit in the app has a visible Label naming it, not only a placeholder.
2. Screenshots of Import PGN and the opening picker show the labels.

## Comments

- 2026-10-31 Triaged by Claude for Bruno ("do what you think best"): runs in the `ui-screens` lane after UI-028, which restyles the opening picker (its canvas board already has a visible Name label).

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: UI-029 implementado e encaminhado para revisão (`Stage: to-review`). Os campos de importação e do seletor agora mantêm rótulos visíveis após a digitação. /  / O gate terminou com saída 0: **429 testes executados e 6 pulados** por ausência do Lc0. As [capturas gráficas](C:/Users/bruno/AppData/Local/Temp/ui029-captures/) foram geradas em 1280×800 e 800×600. /  / A revisão independente e a aceitação visual e de entrada física permanecem pendentes. As capturas do seletor mostram o catálogo ainda carregando; a correção de fonte CLEAN-012 também permanece como condição de release. /  /
