# UI-029: Visible labels on fields that only have placeholders
Status: needs-triage
Review: agent
Difficulty: normal

- Primary files:
  - ui/repertoire_import.tscn ("PGN file", "Repertoire name …")
  - ui/opening_picker.tscn ("Selection name")

#### What to build

Some text fields are identified only by their placeholder text, which disappears once the user types and, with the design's placeholder token `#6b675f` on the ground `#1f1e1c`, reads at 2.96:1 contrast (below WCAG 1.4.3's 4.5:1). Give each such field a visible label (as Profile's "Your name" row already does), so the placeholder is only a hint.

Raised in the PR #33 review (UI-021). Whether the placeholder token itself should be lightened is Bruno's design call, recorded there.

#### Acceptance criteria

1. Every LineEdit/TextEdit in the app has a visible Label naming it, not only a placeholder.
2. Screenshots of Import PGN and the opening picker show the labels.
