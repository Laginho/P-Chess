# LEARN-001: The rating sentence
Stage: done
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - New: core/course.gd (the progress file and the rating, spec §L2, §L4; LEARN-002 extends this module)
  - New: ui/rating_dialog.gd, ui/rating_dialog.tscn
  - ui/home.gd, ui/home.tscn (a Course button, `course_requested` signal)
  - ui/main.gd (`_ready`: wiring the Course button and the dialog)
  - ui/profile.gd, ui/profile.tscn (the rating sentence field)
  - New: tests/test_course.gd
  - tests/test_profile.gd
  - tests/test_home.gd
  - New: tests/fixtures/course/ (progress fixtures, if needed)

#### What to build

The player states their rating once, in one sentence: "I'm rated [1600] in rapid on [chess.com ▾ / lichess]" (design `RatingModal.dc.html`, `Profile.dc.html`). Home gets a Course button; with no rating saved, it opens the dialog, which has no skip. Profile shows the same sentence, editable. The course module stores it in `user://course.json` and derives the chess.com-scale rating and the course's Maia level (spec §L4, ADR 0003). Until LEARN-002 adds the course map, saving the dialog returns to Home.

#### Acceptance criteria

1. With no rating in `user://course.json`, the Course button opens the rating dialog; it can't be dismissed without a valid rating (Esc and clicking outside do nothing).
2. A valid rating is a whole number from 100 to 3500; anything else keeps Start the course disabled. The site is chess.com or lichess, chess.com by default.
3. Choosing lichess shows "Shown as N on the chess.com scale", with N = the number minus 300.
4. Saving writes the number and the site to `user://course.json`; with a rating saved, the Course button no longer opens the dialog.
5. The course module gives the chess.com-scale rating (Lichess minus 300) and the Maia level: chess.com + 300, rounded to the nearest hundred with halves up, clamped to 1100–1900, as `maia-<level>`. Examples: 1600 chess.com → `maia-1900`; 1100 lichess → `maia-1100`; 1249 chess.com → `maia-1500`; 1250 chess.com → `maia-1600`; 2000 chess.com → `maia-1900`.
6. Profile shows the sentence with the saved number and site; editing and saving there updates `user://course.json`, with the same validation as criterion 2.
7. A missing or unreadable `user://course.json` reads as empty; a read error never causes the file to be overwritten with less than it held.
8. The sandbox's Maia level picker and its saved choice are unchanged.

#### Verification

    Manual: on a fresh profile, click Course, try to dismiss the dialog, enter 1400 lichess, check Profile shows the same sentence.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: rating round-trip through a temporary `course.json`; the conversion and Maia-level examples in criterion 5; an unreadable file reads as empty and isn't overwritten (red: no module).
- `tests/test_home.gd`: with no rating, Course opens the dialog and Esc doesn't close it (red: no button).
- `tests/test_profile.gd`: Profile shows and saves the rating sentence (red: no field).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L2, §L4.

- Stage 2: testes red/green por fatia; preservação de campos comprovada também com mutação que descartava o progresso. Gate `godot --headless -s tests/run.gd`: 580 passed, 0 failed (commit 1221ea0). Verificação manual em janela pendente: ambiente sem display gráfico.
- Checagem independente dos critérios (agente de contexto novo):
- ✅ 1: `ui/main.gd:172`, `ui/rating_dialog.tscn:5`; `tests/test_home.gd:321` envia Esc ao diálogo e clique ao viewport. O clique nativo de janela ainda requer verificação manual.
- ✅ 2: `ui/rating_dialog.gd:36`, `core/course.gd:30`; `tests/test_home.gd:321` cobre limites, entradas inválidas e site padrão.
- ✅ 3: `ui/rating_dialog.gd:36`; `tests/test_home.gd:321` verifica 1400 lichess → 1100.
- ✅ 4: `ui/rating_dialog.gd:46`, `core/course.gd:56`, `ui/main.gd:172`; `tests/test_home.gd:321` verifica persistência e reabertura.
- ✅ 5: `core/course.gd:47`; `tests/test_course.gd:4` cobre conversão e todos os exemplos.
- ✅ 6: `ui/profile.gd:31`, `ui/profile.gd:181`; `tests/test_profile.gd:270` e `tests/test_home.gd:321` cobrem edição e navegação real até Profile.
- ✅ 7: `core/course.gd:14`, `core/course.gd:56`; `tests/test_course.gd:24` e `tests/test_course.gd:41` cobrem conteúdo inválido, falha de abertura e preservação de campos. Falha parcial de leitura em arquivo regular não foi reproduzida; código verifica erro e tamanho.
- ✅ 8: `ui/home.gd:78`; `tests/test_home.gd:321` verifica o nível do sandbox após salvar o rating, e `test_custom_choices_survive_restart_and_new_game_returns_home` verifica persistência.

Gate evidence: /run/media/lage/New Volume/Scratch/learn001/gate.json

#### Resolution (2026-11-08)
Verdict: Approve

Reviewed the full diff `b75e1fb...13a6fcc` and all eleven ticket commits. Independent read-only reviewers `/root/standards_review` and `/root/spec_review` examined Standards and Spec respectively; the closing reviewer checked their evidence and additional failure probes. No production repairs or contract changes were made in review. All changed source and tests are Primary files; test-only commits precede the corresponding production commits.

- Standards: 0 documented violations; 1 nonblocking maintenance observation. The dialog repeats the numeric bounds already in `Course.valid_rating`, while Profile uses that validator. This is a possible Duplicated Code smell, with no present behavior difference; tracked in [CLEAN-016](115-CLEAN-016-shared-rating-validation.md).
- Spec: 0 findings; all eight numbered criteria pass implementation review, with the manual product check disclosed below.
- ✅ 1: `ui/main.gd:170` opens the dialog only without a saved rating. `ui/rating_dialog.tscn` is exclusive, borderless and disables Escape dismissal and automatic confirmation hiding. `test_course_requires_a_valid_rating_before_starting` sends Escape and an outside viewport click and checks visibility. Native user input remains the manual acceptance condition.
- ✅ 2: The dialog and course module accept integer ratings from 100 through 3500; the default site is chess.com. Existing tests cover invalid values and both boundaries. An additional Godot 4.7.2 probe confirmed oversized integer strings convert to out-of-range values and remain rejected, rather than wrapping to a valid rating.
- ✅ 3: Selecting lichess with 1400 displays "Shown as 1100 on the chess.com scale", verified by the integration test and the rendered dialog capture.
- ✅ 4: Saving persists number and site, hides the dialog and leaves Home visible. A second Course click does not reopen it; the integration test reads a new course instance to verify persistence.
- ✅ 5: `core/course.gd:47` rounds chess.com rating plus 300 to hundreds, halves up, and clamps to 1100–1900. `test_rating_round_trip_and_conversion` covers every specified example through file round-trips.
- ✅ 6: Real Home → Profile navigation and the isolated Profile test show the saved sentence and save edits with the same limits. Windowed Xvfb captures show the saved 1400 lichess sentence and conversion hint in Profile.
- ✅ 7: Missing files read empty; invalid JSON, failed opening and short/error reads prevent saving. The module rereads before writing and preserves unknown progress fields, publishing via a temporary file and rename. Tests cover invalid JSON, a directory at the file path, and retained unit/clock progress. An additional regular-file probe with permissions 000 returned empty rating, refused saving and preserved the original bytes. A partial device read was not induced; its explicit error/length guard was inspected.
- ✅ 8: The sandbox's level selection, save path and quick-play behavior are unchanged. The course integration test retains Maia 1300 after saving the rating, and the existing restart/custom-game regression verifies preference persistence.

Affected callers and interactions examined: Main initialization, Home Course entry and Profile navigation, the first-run name dialog and modal shading, dialog/Profile validation and save failures, JSON loading and preservation of fields owned by future course tickets, rating conversion and rounding, sandbox settings and level selection, Home layout with and without missing-engine warnings, and Profile layout. Not exercised live: the Windows build, physical keyboard/mouse input or Lc0. Screens used the existing HeldBridge boundary and isolated storage; no player course file was changed.

Red/green evidence: `03b7d29` → `5663856` (missing module → persisted rating), `d1a925a` → `4a5af92` (missing Course integration → required dialog), `e66c6ee` → `4ba56c0` (missing Profile rating → editing), and `aeed145` → `5b07111` (sentence layout assertions → readable sentence). Additional test-only commit `d911e41` covers preservation/navigation; its red mutation drops unit/clock fields and fails the added assertions. Local red/green logs remain under `/run/media/lage/New Volume/Scratch/learn001/`.

The final production-only commit `1221ea0` makes the incomplete-read guard explicit; the preservation mutation does not prove that guard. Independently checked [Godot 4.7.2's implementation](https://github.com/godotengine/godot/blob/ed1daf0bf/core/io/file_access.cpp#L504): the replaced `get_as_text()` already delegates to `get_as_utf8_string()`, which returns an empty string on a short read, rejected by the existing JSON parser. Unix and Windows regular-file backends return the actual byte count. For this contract the replacement is behavior-preserving hardening, not a newly demonstrated bug fix, so the lack of a new failing partial-read test does not justify reopening. The reviewer and independent Spec reviewer both examined this equivalence; no test-first violation remains.

Gate: reused the recorded `godot --headless -s tests/run.gd` run at `1221ea0bd27958bd0235bdf75a44fcae5968c510`: 580 passed, 0 failed, exit 0. The official `Assert-GateEvidence` helper verified its receipt, log SHA-256, exit marker and identical production tree. The unchanged-code rebase was already up to date. The gate was not rerun for paperwork. Its existing skips were one graphical last-move pixel check and six live Lc0 checks, because the headless run lacked a display and `engine/lc0/lc0.exe`. `git diff --check` passed.

Additional review evidence: [failure probes](</run/media/lage/New Volume/Scratch/learn001-review/probe.log>), [window capture log](</run/media/lage/New Volume/Scratch/learn001-review/capture.log>), [rating dialog](</run/media/lage/New Volume/Scratch/learn001-review/rating.png>) and [Profile](</run/media/lage/New Volume/Scratch/learn001-review/profile.png>). Xvfb used the actual X11 renderer, embedded subwindows and `--position 3000,3000`; captures were visually inspected. Automated rendering does not establish the pending human input check.

Integrated without squash into `sweatshop/learning/2026-11-07-2234` as `860e358`. No push or individual PR in the session flow. No proxy decisions exist on this ticket or were introduced in review.

Acceptance: pending | The ticket's manual Verification remains: Bruno opens Course on a fresh profile, tries Escape and a physical click outside, enters 1400 lichess and checks the sentence in Profile. Headless input tests and inspected Xvfb captures support implementation approval but do not replace this human check.
Disclosure: pending | release | [Manual acceptance procedure](#verification): complete the fresh-profile keyboard/mouse check before release and record its result here; session integration is allowed with this check outstanding.
Disclosure: deferred | none | [CLEAN-016](115-CLEAN-016-shared-rating-validation.md) tracks duplicated rating validation as maintenance only, with no current criterion failure or release condition.
