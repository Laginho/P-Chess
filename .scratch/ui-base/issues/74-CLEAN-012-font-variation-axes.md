# CLEAN-012: Apply the shared theme's declared font weights
Stage: to-implement
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/theme/p_chess.tres (FontVariation weight axes only)
  - tests/test_ui_theme.gd

#### What to build

Make the existing shared font variations render their declared weights. This repairs [UI-021](73-UI-021-theme-font-icons-screenshots.md) criterion 2, which already requires the canvas's 400-800 weights, without changing screen layouts or the chosen typography.

#### Acceptance criteria

1. The theme's BoldText (700), ExtraBoldText (800), MediumText (500), PrimaryButton (700), SectionLabel (700) and SemiboldText (600) variations apply those weights in Godot 4.7's TextServer; their rendered variation coordinates include the expected weight.
2. The bundled Noto Sans default font, type-variation assignments, sizes, colors and non-font theme values remain unchanged.
3. The gate passes and fresh Main, NameDialog and Searching captures at 1280x800 demonstrate the corrected heading/button weights against the reference PNGs.

#### Verification

    Focused: TextServer.font_get_variation_coordinates() on each variation's font RID.
    Graphical: scripts/screens.gd for Main, NameDialog and Searching, with isolated data per invocation.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_ui_theme.gd`: check the actual TextServer variation coordinates for each existing weighted theme variation. Before the repair, the configured string `wght` key produces an empty rendered-axis dictionary; the test must observe the applied weight, rather than merely the resource's stored dictionary.

## Comments

- 2026-10-31 Opened by [UI-022 stage-3 review](../../ui-game/issues/74-UI-022-home-name-dialog-searching.md#resolution-2026-10-31), preserving the already recorded foundation finding. The earlier UI-021 approval missed the effective rendering of weight axes; existing tests only assert the font resource/name.
- Confirmed on Godot 4.7: ExtraBoldText stores `{"wght":800}`, but `TextServer.font_get_variation_coordinates(font.get_rids()[0])` returns `{}`. A duplicate using numeric OpenType tag `2003265652` returns `{2003265652:800}`. The same string-key configuration occurs at `ui/theme/p_chess.tres:7`, `:114`, `:200`, `:294` and `:453`.
- Reproduction script and log: `C:/Users/bruno/AppData/Local/Temp/pchess-ui022-review-49a91834-fd8a-477e-a4e5-e18183901cda/probe.gd` and `probe-long-name.log`. That script also checks UI-022's independent long-name finding; only the font output belongs to this ticket.

Acceptance: pending | Rendered font weights and new graphical comparisons after the repair.
Disclosure: pending | integration | UI-022 and the remaining screen redesigns require the correct shared font weights before visual acceptance/integration.
