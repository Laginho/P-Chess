# CI-003: Release on v* tags
Stage: to-implement
Blocked by: BOT-001, CI-002
Review: human
Difficulty: normal

- Primary files:
  - New: .github/workflows/release.yml
  - docs/THIRD_PARTY.md

#### What to build

A `v*` tag produces a downloadable zip that runs: the Windows build plus Lc0 and the Maia nets, attached to a GitHub release (§12, M9). Review is `human` because shipping GPL-3 binaries has licence duties.

#### Acceptance criteria

1. Pushing a `v*` tag runs the Windows export, then `scripts/fetch-engine.ps1` on a Windows runner, and zips the build with `engine/lc0/` and `engine/weights/`.
2. The zip is attached to a GitHub release named after the tag.
3. Lc0 and the Maia nets ship unmodified, with their `COPYING` files.
4. `docs/THIRD_PARTY.md` links the exact upstream source tags of Lc0 and Maia.
5. Unzipped on a clean Windows machine, the app finds the engine and plays a game against Maia.

#### Verification

    Push a test tag (for example v0.0.1-rc1) on the ticket branch; link the release.
    Manual: unzip on a clean machine and play one game.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: release workflow. The evidence is the release link and the manual game.

## Comments
- 2026-10-25 CI-002 review: with no engine beside the exe, the exported app says "Run scripts/fetch-engine.ps1 to download it", but an export does not ship that script. The release zip carries the engine, so the message should not show; if it ever does (a broken zip), the text points at a file the user does not have. A note, not a criterion.
