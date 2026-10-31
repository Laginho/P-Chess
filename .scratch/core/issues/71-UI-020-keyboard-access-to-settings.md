# UI-020: Keyboard access to the Settings screen
Stage: to-implement
Status: needs-triage
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (`_unhandled_key_input`: open on Ctrl+,)
  - ui/settings.gd (close on Ctrl+, beside Esc; focus the first row on open; Tab wraps Close ↔ first row)
  - ui/game_over.gd (`_input`: return while the Settings panel is visible)
  - docs/spec.md (§9.2: row `| Ctrl+, | Settings (open/close) |`)
  - tests/test_session.gd

#### What to build

The Settings screen cannot be opened from the keyboard. Its Open button has `focus_mode = 0`, like every chrome button since UI-004/UI-005, so Tab never reaches it and §9.2 has no hotkey for it. Once open, its rows (SpinBox, OptionButton, CheckBox) take focus normally. So a keyboard-only user can't change any setting, including the board size row added in PR #27 for the mouse-only resize grip (UI-015).

Found by the PR #27 review (round 2). It predates that PR, so it's tracked here rather than fixed there.

The buttons are unfocusable on purpose: a focused button eats `Space` (rematch, §9.2) and other game hotkeys. The fix has to keep those working. Pick between a Settings hotkey in §9.2 and making Open focusable without it swallowing hotkeys. That's a product call.

Decided (proxy, 2026-10-31): a `Ctrl+,` hotkey in §9.2 toggles Settings; Open stays unfocusable (`focus_mode = 0`).

Notes for stage 2 (from the proxy's reading of the code; it ran no Godot, so the tests confirm):
- The `match event.keycode` in `main.gd` checks no modifiers today (Ctrl+F flips the board). The new branch needs `event.ctrl_pressed` and `not event.is_echo()`. Opening guard: `settings_screen.visible and not review.visible`.
- Closing with `Ctrl+,` lives in `settings.gd`: it swallows every unhandled key while open, before `main.gd` sees it.
- `ui/game_over.gd` `_input` takes Space and Esc whenever the post-game panel is visible, before GUI and unhandled handlers; guard it while the Settings panel is visible, like `main.gd`'s `_resign`/`_offer_draw`.
- Godot moves focus across the whole window, so Tab from Close would land on setup controls behind the shade; link Close and the first row with `focus_next`/`focus_previous` so Tab wraps.
- Copy the input pattern from `test_settings_blocks_focused_resign_button_from_space` (`tests/test_session.gd`), with `key.ctrl_pressed = true`, sending press and release. After closing, assert `get_viewport().gui_get_focus_owner() == null`, then that Space rematches.
- Out of scope: a tooltip showing the shortcut; restoring focus to the setup screen on close.

#### Acceptance criteria

1. `Ctrl+,` opens Settings wherever its Open button can be clicked (setup, during and after a game). The same key closes it, and Esc and Close still close it too. It does nothing in focus mode or on the review screen.
2. Opening Settings, by key or by click, focuses the first row's control. Tab and Shift+Tab move between the rows and Close and wrap inside the panel. A value can be changed from the keyboard, for example Space toggles a CheckBox.
3. Closing Settings, any way, leaves no control focused. `Space` rematch, `Esc` resign and `F`/`F11` keep working after Settings was opened and closed with the mouse or the keyboard.
4. While Settings is open over the post-game panel, Space and Esc act inside Settings: no rematch, and the post-game panel stays.
5. Tests drive this through `Viewport.push_input`, not direct signal emits.

## Comments

- 2026-10-30 Opened from the PR #27 review loop (`pr-review-loop`), round 2, finding P2 on `ui/settings.gd`.
- 2026-10-31 Proxy decided (opus-5.5 xhigh): A, a `Ctrl+,` hotkey that opens and closes Settings, added to §9.2. Open stays at `focus_mode = 0` — B can't work: nothing reaches Open by Tab when no control has focus, and a focused Button eats `Space` (UI-004/UI-005 avoided exactly that). `Ctrl+,` is the usual desktop Settings shortcut. It can't be typed as text, so it also closes Settings from inside a SpinBox, where a plain `S` would be typed into the field. It also leaves letters free for the "Rebindable hotkeys" backlog item (§14). (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-033111-UI-020-53c4d8.json)

- Test harness correction: Space on the first OptionButton opens its popup, so the post-game test tabs to a CheckBox before pressing Space; nullable focus is compared directly. Session preferences now use a cleaned temporary user file because that test saves a setting.
- Verification: focused session tests 24 passed; the full headless gate reported 339 passed, 0 failed, including 6 Lc0 skips (333 executed).

Acceptance: pending | Manual keyboard and visual acceptance of Settings across setup, play and post-game remains.
Disclosure: pending | release | Manual keyboard and visual acceptance remains for UI-020.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui020-gate.json

#### Stage 3 review (2026-10-31)

Verdict: Reopen — criterion 1 fails while editing a SpinBox or using an OptionButton popup.

- Reviewed `5d71dca818ad6ef498669ca0dfa66e94b7603f08...302d280c425820b22ba597c23543a94547b36084`, all six changed files and all six commits. Standards: no documented violations; Primary files and test/production commit separation respected. The red logs show the shortcut/focus failures before production, followed by 24 passing focused session tests.
- **P2, criterion 1 — `ui/settings.gd:55` / `ui/settings.gd:64`: Esc is handled too late for a focused SpinBox.** Reproduction through `Viewport.push_input`: `Ctrl+,`, four Tabs, Esc. The first Esc ends editing in the animation SpinBox's LineEdit but leaves Settings visible and the LineEdit focused; only the second Esc closes Settings. This fails “Esc and Close still close it too”. Handle Esc before GUI consumption, alongside the early close shortcut, and add a regression test using this key sequence. Evidence: `C:\Users\bruno\AppData\Local\Temp\ui020-review-esc-probe.gd` and `C:\Users\bruno\AppData\Local\Temp\ui020-review-esc-probe.log` (exit 1).
- **P2, criterion 1 — `ui/settings.gd:54`: Ctrl+, cannot close Settings while an OptionButton popup is open.** Reproduction: `Ctrl+,`, Space on the first row, `Ctrl+,`. The popup and Settings both remain visible. The embedded PopupMenu is a separate Window; a tap in its input path receives the shortcut while the root Settings handler receives nothing. Both root-viewport and popup-viewport injection reproduce it with fresh Main instances. Route the popup's shortcut into a common close path that hides popup and panel and releases focus; add a regression test with the popup open. Evidence: `C:\Users\bruno\AppData\Local\Temp\ui020-review-popup-routing.gd` and `C:\Users\bruno\AppData\Local\Temp\ui020-review-popup-routing.log`.
- Criteria: 1 ❌ (the two findings above); 2 ✅ (all 16 rows plus Close traversed in both directions, initial focus, wrapping and CheckBox input); 3 ✅ for successful close paths (focus release and subsequent game hotkeys); 4 ✅ (post-game Space/Esc isolation); 5 ✅ (new tests drive `Viewport.push_input`). Remaining stage-2 work is the two ❌ cases; retain the existing implementation.
- Examined callers and interactions: Main's setup/play/post-game shortcut paths, focus/review exclusions and echo guard; Settings visibility/focus and row controls, SpinBox LineEdit GUI consumption and OptionButton subwindow routing; GameOver's early input arbitration; preference updates and isolated test storage; existing rematch/resign/flip/focus hotkeys. Physical keyboard, rendered layout and live-Lc0 acceptance were not performed.
- Gate evidence revalidated against review HEAD without rerunning the gate: command, commit/tree equality, SHA256 log hash and exit 0 are valid. The log reports 339 passed, 0 failed with 6 Lc0 SKIPs (333 executed). The additional focused probes expose states absent from that suite; its green result does not close these findings. No production or test files changed during review, and no merge or ledger entry was made.
- The existing `Proxy decided (opus-5.5 xhigh)` decision is retained: Ctrl+, toggles Settings, Open stays unfocusable, opening focuses the first row, closing releases focus, and focus/review screens exclude the shortcut. Its receipt is `C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261031-033111-UI-020-53c4d8.json`; the review changes no criterion or product decision.

Disclosure: decision | none | Existing proxy receipt above defines the approved keyboard contract; no new contract change in review.
Disclosure: pending | integration | UI-020 criterion 1: Esc must close Settings from a focused SpinBox; reproduce with the review Esc probe above.
Disclosure: pending | integration | UI-020 criterion 1: Ctrl+, must close Settings from an open OptionButton popup; reproduce with the review popup-routing probe above.
