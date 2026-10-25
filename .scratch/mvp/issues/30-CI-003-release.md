# CI-003: Release on v* tags
Stage: to-review
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
- 2026-10-25 Stage 2 starts from session commit `1db4142`; BOT-001 and CI-002 are done. The ticket exempts GDScript tests. Scope: the release workflow and packaging notes only; no runtime function changes. Inspected the existing export job/preset, `fetch-engine.ps1`, `UCI.search_dirs`/`engine_path`, and Maia's weights lookup. Package root must contain the exe/PCK and sibling `engine/lc0/` and `engine/weights/`; download, import, export, licence and archive failures must stop publication. Verification uses a test tag, downloaded ZIP checks, the bound gate and the separate clean-Windows game acceptance.
- 2026-10-25 CI-002 review: with no engine beside the exe, the exported app says "Run scripts/fetch-engine.ps1 to download it", but an export does not ship that script. The release zip carries the engine, so the message should not show; if it ever does (a broken zip), the text points at a file the user does not have. A note, not a criterion.

#### Stage 2 verification (2026-10-25)

- Production commit: `8027b7c5d008c7bb13ac3d51460e946216755855`. Only the two Primary files changed; the initial stage commit is ticket metadata only. No GDScript test was added, as explicitly exempted above. No runtime functions/callers changed.
- Pushed the ticket's test tag `v0.0.1-rc1`. Release workflow: https://github.com/Laginho/P-Chess/actions/runs/40238838163 (all steps passed on `windows-latest`, including export, fetch, licences, ZIP verification and publication). The separate push CI also passed: https://github.com/Laginho/P-Chess/actions/runs/40238838140.
- Published release: https://github.com/Laginho/P-Chess/releases/tag/v0.0.1-rc1. Title equals the tag; attached `P-Chess-windows-x86_64.zip` is 99,662,189 bytes, SHA-256 `a8ac37351dccc13df4798a139edf49e16c8b801e34bf2b471fb720b1c2d506d2`. Downloaded it into a new temporary folder and matched GitHub's asset digest.
- The extracted ZIP contains `P-Chess.exe`, `P-Chess.pck`, `THIRD_PARTY.md`, and sibling `engine/lc0/` and `engine/weights/`. Reran the production fetch script with that extracted folder as `-Root`: exit 0, every pinned asset/extracted engine file verified, no downloads. Lc0 `COPYING` SHA-256 is `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809`; Maia `COPYING` is the unmodified upstream `v1.0/LICENSE`, SHA-256 `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.
- The bundled notices match `docs/THIRD_PARTY.md` as text and retain both exact source tags. The first external comparison used a byte hash and rejected the runner's CRLF checkout versus the local LF working file; line-by-line comparison confirmed no content difference. Engine/network checks remain byte-hash comparisons.
- All seven multiline PowerShell workflow blocks parse. Executed the actual `Verify package and zip` block in an empty temporary directory: it throws `Release package is missing P-Chess.exe`, preventing publication. The successful Actions run covers the complete-package path.
- Bound gate executed once on the production commit: **254 passed, 0 failed**, exit 0. Full log and receipt are outside the repo at `C:/Users/bruno/AppData/Local/Temp/P-Chess-CI-003/gate.log` and `gate.json`. No `FAIL`, `ERROR` or `SCRIPT ERROR` output lines; expected malformed-fixture warnings remain. `git diff --check` passed.
- Started the downloaded executable on this Windows machine with a new isolated `APPDATA` under the evidence folder. It created its new Godot profile and launched its own child `engine/lc0/lc0.exe` from the extracted release, confirming executable-relative engine discovery. Computer Use identified the `[P] Chess` window but refused access with `Computer Use was not approved to use p-chess`; no game was played. This machine is not a clean Windows installation, so this is supporting startup evidence only.
- External evidence directory: `C:/Users/bruno/AppData/Local/Temp/P-Chess-CI-003/` (`release-actions.log`, `verify-downloaded-engine.log`, `missing-package-check.log`, downloaded ZIP and extracted release, isolated `clean-profile/`, gate log/receipt). Gate code has not changed after verification.
- Handoff: the test application and its bundled engine child were stopped; evidence is preserved. No merge or stage-3 review was performed. Human review retains the pending criterion-5 integration check below.

Acceptance: pending | Criteria 1-4 verified by the release/run and downloaded-package checks above. Criterion 5 still requires unzipping on a clean Windows machine and playing a game against Maia.
Disclosure: pending | integration | CI-003 criterion 5 above: startup and engine discovery passed on the current machine, but UI access was refused and clean-machine gameplay is unverified. Retain this check for human review before integration.

Gate evidence: C:/Users/bruno/AppData/Local/Temp/P-Chess-CI-003/gate.json
