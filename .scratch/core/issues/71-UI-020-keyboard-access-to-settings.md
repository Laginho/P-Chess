# UI-020: Keyboard access to the Settings screen
Stage: to-implement
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/settings.tscn (`Open`, `focus_mode = 0`)
  - ui/settings.gd
  - ui/main.gd (`_unhandled_key_input`)
  - docs/spec.md (§9.2 hotkeys)

#### What to build

The Settings screen cannot be opened from the keyboard. Its Open button has `focus_mode = 0`, like every chrome button since UI-004/UI-005, so Tab never reaches it and §9.2 has no hotkey for it. Once open, its rows (SpinBox, OptionButton, CheckBox) take focus normally. So a keyboard-only user can't change any setting, including the board size row added in PR #27 for the mouse-only resize grip (UI-015).

Found by the PR #27 review (round 2). It predates that PR, so it's tracked here rather than fixed there.

The buttons are unfocusable on purpose: a focused button eats `Space` (rematch, §9.2) and other game hotkeys. The fix has to keep those working. Pick between a Settings hotkey in §9.2 and making Open focusable without it swallowing hotkeys. That's a product call.

#### Acceptance criteria

1. A keyboard-only user can open Settings, move between its rows, change a value and close it.
2. `Space` rematch, `Esc` resign and `F`/`F11` keep working after Settings was opened and closed with the mouse or the keyboard.
3. A test drives this through viewport input dispatch (`Viewport.push_input`), not direct signal emits.

## Comments

- 2026-10-30 Opened from the PR #27 review loop (`pr-review-loop`), round 2, finding P2 on `ui/settings.gd`.
