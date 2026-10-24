# UI-003: Themes and sounds
Stage: done
Blocked by: UI-001
Review: human
Difficulty: normal

- Primary files:
  - New: ui/theme_loader.gd
  - New: ui/sound_player.gd
  - ui/board_view.gd
  - ui/main.gd
  - New: themes/boards/brown/theme.json
  - New: themes/sounds/sfx/, nes/, piano/, futuristic/ (.ogg files)
  - docs/THIRD_PARTY.md
  - New: tests/test_themes.gd, tests/fixtures/themes/

#### What to build

Board, piece and sound themes as folders (§8.6), built in under `res://themes/` or the user's own under `user://themes/`, plus sounds for the game events (§8.5). Review is `human` because Bruno picks the default sound set by ear.

#### Acceptance criteria

1. The loader lists the themes of each kind (boards, pieces, sounds) from `res://themes/<kind>/` and `user://themes/<kind>/`.
2. A board theme is a `theme.json` with two colours or a texture; a malformed one falls back to brown with a warning.
3. A piece set must have all twelve files `wK.svg` … `bP.svg`; an incomplete set is not listed.
4. A sound set has one `.ogg` per event: move, capture, castle, check, promote, premove, low time, game start, game end. A missing file means that event is silent; it never crashes.
5. In a two-human game, move, capture, castle, check, promote, game start and game end play their sounds. (Premove and low time are wired by UI-007 and CLOCK-001.)
6. The bundled sound sets are exactly `sfx`, `nes`, `piano` and `futuristic` from Lichess; Lichess's `standard` set is not in the repo.
7. `docs/THIRD_PARTY.md` credits the Lichess sound sets (AGPL) with a source link.
8. The default sound set is the one Bruno names at review; until then, `sfx`.

#### Verification

    Manual: Bruno listens to the four sets and names the default.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_themes.gd`: the loader on fixture folders: a valid board, a malformed board, a complete and an incomplete piece set, a sound set with one file missing. Red because `ui/theme_loader.gd` does not exist.

## Comments

### Stage 2 (2026-10-24)

- Implemented on `ui-003`, based on session `sweatshop/mvp/2026-10-24-1310`.
  Dependency UI-001 is done. Changes stay inside Primary files.
- `ThemeLoader` discovers built-in and user folders, with user names taking
  precedence. Board themes use `light`/`dark` HTML colours or a relative `texture`
  path. Invalid boards warn and fall back to brown. Only complete twelve-file
  piece sets are listed. Missing sound events are omitted and remain silent.
- The board applies board and piece themes via `set_board_theme` and
  `set_piece_theme`. `SoundPlayer.select_theme` replaces the loaded set, and
  `play(event)` safely ignores absent events. Independent audio players allow
  capture, promotion and check clips to overlap.
- The four sound sets come from Lichess revision
  `81e2d1bca7a0c97ba3a980f2c51fcff67bfef7ed`. All 36 bundled audio files were
  compared with the upstream Git blob hashes and matched. Upstream
  `Checkmate.ogg` is a symlink to `Check.ogg`; the local `game_end.ogg` contains
  the target audio bytes. Other event aliases and AGPL attribution are documented
  in [THIRD_PARTY.md](../../../docs/THIRD_PARTY.md). No `standard` set was added.
- Callers examined before tests: `BoardView._ready` initializes rendering;
  `play`, legal drops and promotion-picker callbacks enter `_commit`;
  `Main._on_move_played` consumes `move_played` for the SAN list, result and
  material balance. That signal and its SAN argument are unchanged. Existing
  board-mapping and material tests remain green. Core game code is unchanged.
- Boundaries checked: missing roots, duplicate user theme names, incomplete
  piece sets, invalid JSON/colours, unknown themes, missing textures, missing
  sound events, illegal moves, finished games, en passant, both castlings,
  promotion, underpromotion and capture-promotion with check.
- Test-first history (each test commit is separate from production):
  - `381d908` red: missing loader, 78 passed / 1 failed. `e8b943d` green:
    79 passed / 0 failed.
  - `1ba717e` red: missing `load_board`, focused 1 passed / 1 failed.
    `aa17ce3` green: focused 2 passed / 0 failed.
  - `77cdbe1` red: missing `load_sounds`, focused 2 passed / 1 failed.
    `68e4c4c` green: focused 3 passed / 0 failed, final gate 81 passed / 0 failed.
  - The first temporary focused harness did not collect script errors; it was
    corrected to use the existing runner's `ErrorLog` before recording the
    second red cycle. The committed test harness was unchanged.
- Scene smoke on the production code: instantiated `ui/main.tscn`; verified
  start audio, ordinary moves, captures, en passant, both castlings, queen and
  knight promotion, capture-promotion with check, Fool's mate result label and
  end audio. Illegal moves and moves after mate emit no sounds. Switched through
  all four sets, decoded every event and checked its audio player starts;
  selecting an unknown set remains silent. Loaded all twelve default and fixture
  piece textures. No script errors. Local evidence:
  `C:\Users\Lage\AppData\Local\Temp\UI-003-smoke.log` (temporary harness alongside it).
- Gate on committed code `68e4c4c85d2ff5f7188fbd6382d86bc5e9e57df5`:
  `godot --headless -s tests/run.gd`, exit 0, **81 passed, 0 failed**.
  Log SHA-256: `8AB06680CC0703088C43D57A6E825F98DA7149FCA425DCBD3832E48326A02BED`.
  `git diff --check` passed; no generated imports or unrelated files were added.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\UI-003-stage2-20261024-gate.json

Acceptance: pending | Bruno still needs to listen to the four sets and name the
default (criteria 8 and manual Verification). `sfx` remains the temporary default.
Headless scene checks establish decoding and playback requests, not listening
quality or visual inspection of an exported build.

Disclosure: pending | release | Bruno's listening/default choice remains open
in this ticket's manual Verification; no default was selected on his behalf.

Disclosure: pending | release | [CI-002](29-CI-002-windows-export.md) must include
raw theme JSON, SVG, OGG and board image files when packaging the Windows build;
the format and export requirement are documented in `docs/THIRD_PARTY.md`.

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 reviewed `git diff 12ea73e...83c1791`, including all seven commits,
with independent Standards and Spec reviewers. No production or test fix was
needed. Implementation approval does not complete the listening acceptance.

Standards: 0 findings. Changed files stay within Primary files. The three cycles
keep tests separate from production: `381d908` / `e8b943d`, `1ba717e` / `aa17ce3`,
and `77cdbe1` / `68e4c4c`; `83c1791` is ticket metadata only. No actionable baseline
smell, unrelated refactor or unnecessary abstraction was found.

Spec: 0 implementation findings. The loader, board integration and audio playback
meet the written criteria, with the explicitly temporary default preserved.

Criteria:

1. Passed: all three kinds are discovered from built-in and user roots. Missing
   roots are safe; user names override bundled names. Fixtures cover both roots.
2. Passed: colour pairs and a decoded board texture load. Invalid JSON, invalid
   colours, missing textures and unknown themes warn and return brown.
3. Passed: discovery requires all twelve named SVG files. The incomplete fixture
   is excluded; all twelve default piece textures decode in the scene smoke.
4. Passed: all nine event names load as OGG streams. The fixture with no capture
   clip loads eight events; `SoundPlayer.play` ignores absent or unknown events.
5. Passed: scene checks cover move, capture, castle, check, promotion, game start
   and game end. En passant, both castlings, underpromotion, capture-promotion
   with check and Fool's mate work; illegal and finished-game moves stay silent.
   Premove and low-time callers remain UI-007 and CLOCK-001 work as specified.
6. Passed: the bundled sound folders are exactly `sfx`, `nes`, `piano` and
   `futuristic`. Review independently compared all 36 local Git blob hashes with
   the cached upstream tree for revision `81e2d1bca7a0c97ba3a980f2c51fcff67bfef7ed`;
   all match the source aliases documented in THIRD_PARTY.md. No `standard` set.
7. Passed: THIRD_PARTY.md names Lichess / Enigmahack, AGPL-3.0-or-later and the
   pinned source link. The upstream [COPYING.md](https://github.com/lichess-org/lila/blob/master/COPYING.md)
   also identifies these four sets and their author/licence; the pinned page
   could not be fetched anew during review.
8. Passed for the current provisional behavior: `SoundPlayer.theme_name` is
   `sfx`. Bruno's listening review and final default choice remain pending.

Examined: `ThemeLoader.list_themes/load_board/load_pieces/load_sounds/load_texture`;
`BoardView._ready`, programmatic play, drag/drop and promotion callbacks through
`_commit`; `PromotionPicker.open`; `Main._ready/_on_move_played`; game-over and
SAN/check generation; sound switching and player cleanup. Failure paths include
missing roots/themes/events, incomplete pieces, malformed boards and missing
textures. Cross-feature checks include the unchanged `move_played(san)` contract,
SAN history, result labels, material balance, flipping and promotion rendering.
Not manually examined: audible quality, rendered appearance or a Windows export.

Verification: the existing gate receipt was validated with `Assert-GateEvidence`,
including its tested commit, bound command, log SHA-256 and `ExitCode: 0` footer.
It records **81 passed, 0 failed** on `68e4c4c`; only ticket metadata changed
afterward, so that receipt remains valid and is reused. Review independently
reran the existing scene smoke against the production code: exit 0,
`SMOKE FAILURES: []`, all 36 clips decoded and theme switching worked. Godot
reported sandbox log/certificate startup errors before the smoke logger, with
no application script errors. A redundant full-suite attempt by the Spec
reviewer hit sandbox write denial in the unchanged runner's `user://` fixtures
and was stopped; it supplies no replacement gate result. `git diff --check`
passed.

Red-green proof: the recorded first red log fails loading the absent production
loader, **78 passed, 1 failed**, before `e8b943d` makes it green. The board cycle
records **1 passed, 1 failed** without `load_board`, then **2 passed, 0 failed**.
The sound red log records **2 passed, 1 failed** on missing `load_sounds`, followed
by the green **81 passed, 0 failed** bound gate. The temporary harness correction
is disclosed in Stage 2 above; committed tests call production code.

Integration: rebase onto `sweatshop/mvp/2026-10-24-1310` was already up to date.
Merged `ui-003` into that session with `--no-ff` as `5bdb108`; production is
unchanged from the tested commit. This resolution, `Stage: done` and its ledger
entry are committed together on the session. `Review: human` remains visible
for the eventual session PR. No push or PR is part of this session-stage handoff.

Proxy decided lines: none. No contract change or unresolved implementation
defect was found.

Acceptance: pending | Bruno must listen to all four sets and name the final
default in the session's human review. Automated checks establish decoding and
playback requests; they do not establish audible quality or exported appearance.

Disclosure: pending | release | Bruno's listening/default decision remains a
release condition under criterion 8 and this ticket's manual Verification;
`sfx` remains the contract's provisional default.

Disclosure: pending | release | [CI-002](29-CI-002-windows-export.md) remains open
for Windows packaging and manual launch; its export must include raw JSON, SVG,
OGG and board images as documented in THIRD_PARTY.md. The exported themes have
not been validated by this review.
