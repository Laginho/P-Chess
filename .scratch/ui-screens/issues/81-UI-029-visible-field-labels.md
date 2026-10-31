# UI-029: Visible labels on fields that only have placeholders
Stage: to-review
Status: ready-for-agent
Blocked by: UI-021, UI-028
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_import.tscn ("PGN file", "Repertoire name …")
  - ui/opening_picker.tscn ("Selection name")
  - ui/opening_picker.gd (label visibility in the two picker modes)
  - ui/repertoire_import.gd (only if its fixed popup size clips the labels)
  - tests/test_catalog.gd, tests/test_repertoire.gd

#### What to build

Some text fields are identified only by their placeholder text, which disappears once the user types (WCAG 1.3.1 / 3.3.2). Give each such field a visible label (as Profile's "Your name" row already does), so the placeholder is only a hint.

Raised in the PR #33 review (UI-021). The placeholder token itself was lightened to `#8a857c` (4.5:1) in that PR.

#### Acceptance criteria

1. Every LineEdit/TextEdit in the app has a visible Label naming it, not only a placeholder.
2. Screenshots of Import PGN and the opening picker show the labels.

#### Verification

Capture RepertoireImport and OpeningPicker in repertoire mode at 1280×800 and 800×600 with `scripts/screens.gd` in an isolated root. Capture the selection-mode picker with a temporary script outside the repo at both sizes. Check that labels are visible and nothing is clipped; cite the PNGs in a comment.

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_repertoire.gd`: instantiate the import scene, present it and type into both fields; assert visible PGN file and Repertoire name labels.
- `tests/test_catalog.gd`: instantiate the picker, type into name and search, and assert visible Name and Search labels and hidden Colour in selection mode; in repertoire mode assert Name, Colour and Search are visible.

## Comments

- 2026-10-31 Triaged by Claude for Bruno ("do what you think best"): runs in the `ui-screens` lane after UI-028, which restyles the opening picker (its canvas board already has a visible Name label).

- 2026-10-31 Attempt 1 failed: exit 0. Log tail: UI-029 implementado e encaminhado para revisão (`Stage: to-review`). Os campos de importação e do seletor agora mantêm rótulos visíveis após a digitação. /  / O gate terminou com saída 0: **429 testes executados e 6 pulados** por ausência do Lc0. As [capturas gráficas](C:/Users/bruno/AppData/Local/Temp/ui029-captures/) foram geradas em 1280×800 e 800×600. /  / A revisão independente e a aceitação visual e de entrada física permanecem pendentes. As capturas do seletor mostram o catálogo ainda carregando; a correção de fonte CLEAN-012 também permanece como condição de release. /  /
- Proxy decided (opus-5.5 xhigh): Yes. Stage 2 may test real instantiated scenes for visible labels, but the screenshots go in Verification as manual evidence, not in the tests. — The gate runs `--headless` and `scripts/screens.gd:29-32` refuses headless, so screenshots can't be gate tests. `tests/test_catalog.gd:9` already tests the picker's labels this way. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-193330-UI-029-37a826.json)
- Proxy scope: preserve field node paths; the Search label intentionally takes precedence over the previous picker design reference. Label checks use `.visible` on labels and containers, rather than `is_visible_in_tree()` in headless mode.
- 2026-10-31 Stage 2: test-only commit `3a5c7ac` produced six expected focused assertion failures before production commit `15ba376`; the same two tests then passed. Import and both picker modes were captured and inspected at 1280×800 and 800×600 under `C:/Users/bruno/AppData/Local/Temp/ui029-captures/` (`RepertoireImport-*`, `OpeningPicker-*`, `Selection-*`). The picker screenshots show the catalog loading state; labels and popup boundaries are visible. The selection-mode capture uses `selection.gd` in that directory, a temporary copy of the screenshot tool with the picker mode changed. Tree minimum height was reduced to keep both picker modes within 800×600.
- Gate on `15ba376`: exit 0, 435 reported passed, 0 failed, including six Lc0 SKIPs (429 executed). Warnings include the existing premove anchor warning and malformed-input fixture warnings; see the receipt's log.

Acceptance: pending | Human visual and physical-input acceptance; the picker captures show the loading state. Shared font correction and subsequent captures remain tracked by CLEAN-012.
Disclosure: pending | release | Human acceptance and CLEAN-012 font correction remain release conditions; see UI-028 and CLEAN-012.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui029-check/gate.json
