# UI-018: Your name, and the HumanColor header
Stage: to-implement
Blocked by: HIST-005, UI-016
Review: agent
Difficulty: normal

- Primary files:
  - New: ui/name_dialog.gd
  - New: ui/name_dialog.tscn
  - core/settings.gd (`player_name`)
  - core/pgn.gd (`finished_game`)
  - core/history.gd (your side from `HumanColor`)
  - ui/history_screen.gd
  - ui/review.gd (the players shown)
  - ui/main.gd
  - tests/test_pgn.gd
  - tests/test_history.gd
  - tests/test_review.gd (test-only: exact-header assertions and returning-player interaction fixture)
  - tests/test_settings.gd
  - tests/test_book.gd (test-only: returning-player fixture for opening-picker interaction)
  - tests/test_clock_input_order.gd (test-only: returning-player fixture for real input)
  - tests/test_session.gd (test-only: returning-player fixture for real input)
  - docs/spec.md (§9.4, §15.8)

#### What to build

The player has a name (§15.8). It is asked once, written into new games, and shown everywhere "You" showed. New PGNs also record which colour you played, since a name like "Maia 1500" could match the opponent's.

#### Acceptance criteria

1. On first launch a modal over Home asks "What should I call you?", prefilled with "You", with only OK; an empty name is not accepted.
2. The name is stored in the `player_name` setting and survives a restart; the dialog never shows again once set.
3. New PGNs write the name in your player header and a `HumanColor` header (`w` or `b`).
4. Stats, thumbnails and Delete read your side from `HumanColor`; for PGNs without it, your side is the player named "You".
5. Old PGNs keep "You" in the file but show the current name in the history and the review.

#### Verification

    Manual: delete settings.cfg, launch, name yourself, play, check History shows the name.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_pgn.gd`: `finished_game` writes the name and `HumanColor` (red: "You", no header).
- `tests/test_history.gd`: a game where you are named "Maia 1500" as Black counts for you from `HumanColor`; a legacy game falls back to "You"; Delete uses the same side (red).
- `tests/test_settings.gd`: `player_name` default "You", empty rejected.

## Comments

- 2026-10-30 Written from spec §15.8 and the design brief (screen 2).
- 2026-10-31 Stage 2: the first full gate (`%TEMP%/UI-018-gate.log`, exit 1; 385 passed, 10 failed) exposed pre-onboarding fixtures in `test_book`, `test_clock_input_order`, `test_review` and `test_session`. Their existing interaction scenarios now seed an isolated confirmed "You" name before Main enters the tree; assertions on retained behaviour are unchanged. The explicit settings-dialog test still covers the first launch. The exact-header tests in `test_pgn`, `test_history` and `test_review` were updated only to add `HumanColor`.

## Resolution — stage 2 (2026-10-31)

- Added a first-launch exclusive name modal over Home, with a selected "You" default, only OK, and rejection of blank or whitespace-only input. Confirming saves the trimmed `player_name`; a valid stored name suppresses the modal after restart. Saving other preferences does not implicitly confirm the default name.
- New saved games and live-review PGN exports receive the chosen name and `HumanColor`. Identity is added at the result/export boundary so rematch choices retain their existing shape. The match score uses the current player name too.
- Delete, History thumbnails/results and history review share `History.human_colour`: a valid `HumanColor` takes precedence, with the legacy "You" fallback. Same-name players work in both colours. Legacy History/review show the current name while the PGN file and copied export remain byte-for-byte unchanged; named PGNs retain their saved name.
- Red/green proof: settings test commit `873b220` failed on the missing name setting/choice, then passed with `6d2d857` (12 settings tests). PGN test commit `2f53542` failed 3 tests on missing names/headers, then passed with `34498ee` (15 PGN tests). History test commit `b1c54c4` failed the same-name deletion scenario, then both identity/deletion tests passed with `ca2a252`. UI test commit `74e87bd` failed the missing dialog and name/orientation presentation, then both passed with `c5e6d65`.
- Regression proof: after fixture correction `502dc2b`, two rematch scenarios remained red because identity had entered the choices dictionary. `6cf6c50` restored that contract; all 13 focused interaction scenarios passed. External focused logs: `C:/Users/bruno/AppData/Local/Temp/ui018-settings-{red,green}.log`, `ui018-pgn-{red,green}.log`, `ui018-history-{red,green}.log`, `ui018-ui-{red,green}.log`, `ui018-rematch-red.log`, `ui018-interaction-green.log` in the same directory.
- Final gate: `godot --headless -s tests/run.gd`, tested commit `6cf6c508bd05aa74bbffdb7891bff61dd4f55d96`; **395 passed, 0 failed**, exit 0. Log: `C:/Users/bruno/AppData/Local/Temp/UI-018-gate-final.log`. Scene checks exercise the real dialog, History and review in headless mode; they do not establish rendered layout or physical input acceptance.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/UI-018-gate-final.json
Acceptance: pending | Rendered first-launch/restart check with isolated settings, keyboard/mouse confirmation and blank-name rejection, then a played game showing the chosen name in History and review; automated evidence is recorded in Resolution above.
Disclosure: pending | release | .scratch/v010/issues/64-UI-018-your-name-and-humancolor.md#resolution--stage-2-2026-10-31 — rendered first-launch and physical-input product acceptance remain pending; the headless gate passed.

#### Resolution (2026-10-31) — stage 3, round 1
Verdict: Reopen — criterion 1 fails because the name field overlaps the first-launch question.

- Standards: no confirmed findings. All 16 changed files were reviewed, including the tracker, documentation, tests and TSCN. The 11 stage-2 commits separate tests, production and handoff; returning-player fixture corrections preserve the retained assertions and are allowed by the test-harness rule. No Primary-files violation or actionable baseline smell was found.
- Spec, P2 — `ui/name_dialog.tscn:14` (with `dialog_text` at line 9): the direct-child LineEdit and AcceptDialog's message label occupy the same content rectangle. On first launch the field is drawn over "What should I call you?", so the requested question is obscured. A focused probe on the installed official Godot 4.7 reported `PROMPT_RECT=[P: (8.0, 8.0), S: (340.0, 40.0)]`, the identical `INPUT_RECT`, `INPUT_COVERS_PROMPT=true`, and child order `1,2` (label, field). Evidence: `C:/Users/bruno/AppData/Local/Temp/ui018-review-dialog-layout.gd` and `C:/Users/bruno/AppData/Local/Temp/ui018-review-dialog-layout.log` (exit 0). This is runtime geometry evidence, not rendered or physical-input acceptance. Godot's layout implementation also assigns the same rectangle to these controls: https://github.com/godotengine/godot/blob/master/scene/gui/dialogs.cpp (`AcceptDialog::_update_child_rects`).
- Criterion 1: ❌ the modal exists and rejects blank names, but its question overlaps the input. Smallest repair: give an explicit question Label and the LineEdit separate rows in a container, clear the built-in `dialog_text`, and update affected node paths. Commit a red geometry assertion in `tests/test_settings.gd` proving that the visible question and field do not intersect, then the production correction and green proof, following the existing test-only/production-only split. This stays within the existing Primary files and approved dialog test seam; the numbered contract is unchanged.
- Criteria 2–5: ✅ on inspected paths and existing automated evidence: confirmed/default name persistence; name plus `HumanColor` in new PGNs; same-name players in either colour; stats deletion, thumbnail/result orientation and review sharing the colour resolver; legacy display using the current name while original/copy PGN stays unchanged. Identity remains outside rematch choices.
- Coverage: fixed diff `891335b4b5c3abaec6eb78f45403dddb55df31d6...0e3eebef6b61fc77bf46674c829d76821f5a60f7`; 16/16 files reviewed, 0 skipped, 100% coverage. OCR delegate preview excluded all 16 as `unsupported_ext`; both review axes inspected them directly using the resolved default rules. Examined Settings → NameDialog/Main, finished_game → save/live review, History → thumbnail/result/review/export, Delete identity/rollback surroundings, and rematch interactions. No other confirmed finding remains from this pass.
- Verification: independently checked all recorded red/green focused logs and validated the gate receipt's command, exit, log SHA-256, tested commit and unchanged production through the reviewed HEAD. Existing gate: **395 passed, 0 failed**, exit 0, with no SKIP lines; it was reused without rerunning because review changed no code. The focused geometry probe is the additional review check. Rendered first-launch/restart layout, real keyboard/mouse input and played-game acceptance remain pending; real-engine gameplay was not exercised by this review.
- Disposition: reopen on `UI-018`; no merge, ledger entry, PR or push. Stage 2 must repair only the ❌ item and provide fresh gate evidence after the code change; stage 3 must review that repair independently.

Disclosure: pending | integration | .scratch/v010/issues/64-UI-018-your-name-and-humancolor.md#resolution-2026-10-31--stage-3-round-1 — criterion 1's overlapping first-launch prompt must be repaired and independently reviewed before session integration.
