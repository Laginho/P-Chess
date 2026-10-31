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
