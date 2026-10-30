# UI-015: Board resize grip
Stage: done
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd (`_fit_board`)
  - ui/main.tscn
  - New: ui/resize_grip.gd
  - core/settings.gd (`board_size`)
  - ui/settings.gd (only if the setting needs a row)
  - tests/test_settings.gd
  - tests/test_board_view.gd
  - docs/spec.md (§8.7, §15.10)

#### What to build

A grip on the board's bottom-right corner lets you drag the board bigger or smaller (§8.7). The size is remembered.

#### Acceptance criteria

1. A grip shows on the board's bottom-right corner with the `nwse-resize` cursor.
2. Dragging it resizes the board; it stays square, the side panel takes the remaining width, and the board never drops below a minimum (a constant) nor grows past what the window fits.
3. The chosen size is saved in the `board_size` setting (default "Fit to window") and restored on the next launch, clamped to the current window.
4. Double-clicking the grip returns to fit-to-window; in fit-to-window the board follows window resizes as today.

#### Verification

    Manual: drag the board small, restart, check the size; double-click resets.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_settings.gd`: `board_size` defaults to fit and round-trips a saved size; an invalid value reads as the default (red: no key).
- `tests/test_board_view.gd` or a main scene test: a set size is clamped between the minimum and the fit size; fit mode follows a resize (red: no grip).

## Comments

- 2026-10-30 Written from spec §8.7 and §15.10.
- Stage 2: setting and board-size tests failed before implementation; the grip test failed when its double-click reset was temporarily disabled. Gate: 286 passed, 0 failed (Godot 4.7, headless).
- Acceptance: pending | Manual drag, restart, double-click reset, cursor and rendered layout remain to be checked in a graphical session.
- Disclosure: pending | release | Manual acceptance above remains outstanding.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui015-gate.json

#### Resolution (2026-10-30)
Verdict: Approve

- Standards: 0 documented violations and 0 relevant smells. Reviewed all seven changed files and all six stage-2 commits; production stays within Primary files and test-only commits remain separate. The later grip test has the mutation-based red proof allowed by `ticket-flow/stage2.md`.
- Spec criterion 1: passed in code and the focused headless probe. The grip's bottom-right matches the drawn board, and `CURSOR_FDIAGSIZE` selects the diagonal resize cursor. Rendered cursor acceptance remains pending.
- Spec criterion 2: passed. The real container probe confirmed a routed drag from 480 to 400 px, a square drawn board, remaining-width side panel and window-bound clamping; minimum-size clamping is covered by the committed test.
- Spec criterion 3: passed. The isolated saved 480 px size restored through Main's initial layout; the routed drag persisted 400 px, and an oversized preference was clamped to the current fit. Settings validation and fallback are covered by the committed tests.
- Spec criterion 4: passed. A double-click routed through the Viewport restored `board_size = 0`; changing the window size then recomputed the drawn board's fit.
- Coverage: Main initialization, `_apply`, `_fit_board`, `_resize_board`, BoardView drawing geometry and resize notifications, Settings validation/save/reload, HBox allocation and grip press/motion/release. Traced Setup, Settings, promotion, focus mode and post-game overlays; the focused probe also confirmed Settings blocks grip input. Physical mouse behavior, cursor rendering and graphical restart were not verified.
- Red/green proof: stage 2 reports the settings and clamping tests failing before implementation, and the grip test failing with double-click reset temporarily disabled. These historical red runs were not rerun during review.
- Gate: reused the unchanged-code receipt above, verified its SHA-256, exit marker and code equality against the merged session. Existing run: Godot 4.7, 286 passed, 0 failed, no SKIP markers, exit 0. No production or tests changed during review/rebase.
- Focused probe: 10 checks passed, 0 failures, exit 0; real scene/container and `Viewport.push_input`, isolated temporary settings, simulated engine. Log: `C:\Users\bruno\AppData\Local\Temp\ui015-review-probe.log`; source: `C:\Users\bruno\AppData\Local\Temp\ui015-review-probe.gd`.
- Integration: merged without squash into `sweatshop/v010/2026-10-30-1831` at `1b5a89ff41080c204a83c937ff101f55a0d0b3c3`; no push or PR in this stage.

Acceptance: pending | Bruno's graphical drag, restart, double-click reset, rendered cursor and layout check remains outstanding; headless evidence is linked above.
Disclosure: pending | release | Graphical acceptance remains a release condition; session integration is permitted with this pending check recorded.
