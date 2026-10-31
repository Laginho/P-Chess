# UI-030: Apply the shared theme's variable font weights
Stage: to-implement
Status: ready-for-agent
Blocked by: UI-021
Review: agent
Difficulty: normal

- Primary files:
  - ui/theme/p_chess.tres (the existing FontVariation axis dictionaries)
  - tests/test_ui_theme.gd

#### What to build

Make the existing shared font variations render their declared Noto Sans weights, so screens using the theme's medium, semibold, bold and extra-bold styles match the design. Raised during [UI-027's stage-3 review](../../ui-screens/issues/79-UI-027-profile-screen.md); the original UI-021 review missed this defect.

#### Acceptance criteria

1. TextServer's resolved font variation coordinates contain the declared weight for each existing FontVariation in `ui/theme/p_chess.tres`; the fonts do not silently render at the default 400 weight.
2. A graphical 1280×800 Profile capture renders the title, player name and numeric Label tiles at their declared 800 weight. Preserve the existing font, sizes, colours and non-font theme styling. Profile-specific RichTextLabel styling remains UI-027's responsibility.
3. The gate stays green.

#### Verification

    Inspect resolved font RID coordinates and capture Profile at 1280×800 with isolated data.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_ui_theme.gd`: check the resolved FontVariation RIDs through `TextServerManager.get_primary_interface().font_get_variation_coordinates()`, using the integer weight-axis tag. Assert the actual declared weights of the existing theme variations (red: the current string-key dictionaries resolve to empty coordinates). Exercise the loaded production theme, not a copied dictionary.

## Comments

- 2026-10-31 Confirmed on Godot 4.7 during UI-027 review: `theme.get_font("font", "ExtraBoldText").variation_opentype` is `{"wght":800}`, but its RID returns `{}` from `font_get_variation_coordinates`. A duplicate using `{TextServerManager.get_primary_interface().name_to_tag("wght"):800}` resolves to `{2003265652:800}`. Correct the common axis declarations once rather than adding per-screen font workarounds.
- Evidence: `C:/Users/bruno/AppData/Local/Temp/pchess-ui027-review-07aff169-9b64-487b-bd92-56c0ce4ad4d8/font-probe.gd` and `font-coords.log`. The original theme and Profile remain unchanged by this review.
- Integration impact: UI-027's criterion 6 cannot pass while the shared title/name/tile weights are ignored. Resolve this alongside UI-027's independent table/card spacing repairs.
