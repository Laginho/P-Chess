# CLEAN-012: Apply the shared theme's variable-font weights in Godot
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/theme/p_chess.tres (FontVariation weight axes only)
  - tests/test_ui_theme.gd

#### What to build

Make the shared Noto Sans variations render the weights already required by UI-021 criterion 2 and the v0.1.0 canvas. The theme currently stores `variation_opentype` with string `"wght"` keys, which Godot 4.7 ignores. This was confirmed while reviewing [UI-028](80-UI-028-repertoire-screens.md); it also affects other screens using these variations. Correct the shared resource without changing screen layouts or adding fonts/dependencies.

#### Acceptance criteria

1. Existing theme variations apply their intended 400-800 font weights to the bundled Noto Sans font, using supported axis keys rather than silently rendering every weight as 400. The existing family, sizes and variation names remain compatible with callers.
2. A graphical comparison shows the intended bold headings and primary-button text; a heavier variation has different rendered metrics from the regular font for the same test string and size. Verify actual font behavior, not just a dictionary's declared weight.
3. The gate stays green and the shared theme's colors, styleboxes and non-font behavior remain unchanged.

#### Verification

    Manual: compare the weighted labels/buttons with the v0.1.0 reference PNGs using the screenshot tool and isolated data.
    Manual: after correction, capture Repertoire, OpeningPicker (catalog loaded, partial parent) and RepertoireEditor (edited) at 1280x800 and 800x600, plus the 99-character name in viewer/editor at 800x600. Check weights, clipping/overlap, board and Save visibility. A layout break is a finding on that screen's ticket; do not fix screens here.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_ui_theme.gd`: load the actual theme and compare each non-regular weight's font metrics with the same bundled font configured through a supported numeric weight-axis key. Include a check that the intended bold and regular strings render differently; the current string-key variations must fail before the resource correction.

## Comments

- 2026-10-31 Opened by UI-028 stage-3 review as the destination for a confirmed pre-existing defect in closed [UI-021](../../ui-base/issues/73-UI-021-theme-font-icons-screenshots.md), criterion 2. This is the implementation of that existing weight requirement, not an additional font/design choice.
- Reproduction on Godot 4.7: the theme's ExtraBoldText font has `variation_opentype = {"wght": 800}`, but `get_string_size("Repertoires", HORIZONTAL_ALIGNMENT_LEFT, -1, 28)` is `(152, 39)`, identical to its regular base. Duplicating only that font and setting `{2003265652: 800.0}` gives `(166, 39)` and visible bold text. Probe, log and PNG: `C:/Users/bruno/AppData/Local/Temp/ui028-review-20261031/font-compare.{gd,log,png}`. The probe exited 0 and did not change repository sources.
- Keep this repair shared; UI-028 should not introduce local font copies to compensate. Recheck all screen captures after the heavier fonts are applied, since text widths will change.
- 2026-10-31 Moved from `.scratch/ui-base/` to the ui-screens lane (id kept); triaged ready-for-agent per the receipt-backed proxy decision recorded in [UI-028](80-UI-028-repertoire-screens.md). Contract and test seam unchanged. The proxy, standing in for the owner, accepted session integration because this shared defect predates UI-028 and affects every screen; v0.1.0 still waits for this repair, the post-correction captures and human acceptance.

Acceptance: pending | The shared variable-font weights have not been corrected or accepted visually.
Disclosure: deferred | release | Accepted for UI-028's session integration (proxy decision recorded in UI-028); v0.1.0 waits for this correction and its captures. Other lanes' screens inherit it on sync and are rechecked in release QA.

- 2026-10-31 Foreman: superseded. The owner merged this fix to main as PR #37 (fix f0789db, merge 0635b3d), with its regression in `tests/test_ui_theme.gd`; the session took it in sync merge 9ad4daf (gate 436 passed, 0 failed). This lane's parallel attempt (stage 2, gpt-6.1-terra xhigh, to-review at 47d4afd) is preserved unmerged on branch `recovery/superseded/20261031/CLEAN-012` and was not reviewed.

Acceptance: pending | The weights render after sync 9ad4daf (UI-027 and UI-029 final reviews; foreman captures in C:\Users\bruno\AppData\Local\Temp\pchess-ui-screens-shots\after). Bruno\'s v0.1.0 QA remains.
Disclosure: decision | none | Superseded by the owner's PR #37 (fix f0789db, merge 0635b3d), synced into this session at 9ad4daf with sync gate 436 passed / 0 failed. This lane's parallel attempt was never reviewed and is preserved unmerged on `recovery/superseded/20261031/CLEAN-012`.
