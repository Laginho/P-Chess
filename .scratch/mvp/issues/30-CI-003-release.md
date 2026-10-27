# CI-003: Release on v* tags
Stage: blocked
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

- 2026-10-25 Review ended at blocked (exit 0); branch ci-003 holds the review; left for a human

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

#### Resolution (2026-10-25)
Verdict: Needs your call: Criterion 5 requires a completed game against Maia from the downloaded release on clean Windows; that integration evidence is unavailable.

- Reviewed `1db4142a1c24b8e9eb25b8b57fab62ca9fa3d8f6...2fd783170ca12df6ea675bc75a6b23f52d2c86c9`, including the full diff and every commit's file separation. Production changes are limited to the two Primary files; the other changes are ticket metadata. The ticket explicitly exempts GDScript tests in favor of the test-tag release and manual game. No production or test changes were authored during review.

##### Standards

- **0 findings.** The independent Standards reviewer found no documented-standard violations or actionable baseline smells. The workflow follows the existing export conventions, reuses `scripts/fetch-engine.ps1`, and preserves executable-relative engine/network paths. No extraction or refactoring is warranted.

##### Spec

- **0 confirmed implementation defects or scope-creep findings.** The independent Spec reviewer checked the full diff and connected packaging/runtime paths.
- Criterion 1 passes: a `v*` push triggers Windows export, then the production fetch script with the export directory as `-Root`, then ZIP creation. The ZIP contains the executable/PCK and sibling `engine/lc0/` and `engine/weights/`.
- Criterion 2 passes: [the published release](https://github.com/Laginho/P-Chess/releases/tag/v0.0.1-rc1) is titled `v0.0.1-rc1` and attaches `P-Chess-windows-x86_64.zip`.
- Criterion 3 passes: all 19 extracted engine/network files match the fetch script's SHA-256 pins; the retained Lc0 archive and Maia `COPYING` also match their pins. Lc0's pinned files include its unmodified `COPYING` and dependency notices.
- Criterion 4 passes: the checkout, bundled notices and release notes retain the exact Lc0 `v0.32.1` and Maia `v1.0` source-tag links. The ZIP's notices match the checkout as UTF-8 text after normalizing line endings.
- Criterion 5 remains **pending product acceptance**, not a demonstrated implementation defect. The recorded exported-app launch with isolated `APPDATA` and its bundled Lc0 child supports engine discovery; it does not demonstrate a completed game on clean Windows.

##### Verification and review coverage

- Independently fetched current GitHub metadata: [release workflow run 40238838163](https://github.com/Laginho/P-Chess/actions/runs/40238838163) completed successfully for production commit `8027b7c5d008c7bb13ac3d51460e946216755855`, triggered by the test-tag push. Release asset size is 99,662,189 bytes; its API digest and the local downloaded ZIP both equal SHA-256 `a8ac37351dccc13df4798a139edf49e16c8b801e34bf2b471fb720b1c2d506d2`.
- Read the ZIP directly and independently verified its 19 pinned engine/network entries, retained upstream archive, Maia licence and bundled notices. Parsed all seven multiline PowerShell workflow blocks successfully. Reviewed the stage-2 successful Actions log and missing-package failure evidence; `git diff --check` passed.
- Validated the existing receipt with `Assert-GateEvidence`: exit 0, log hash unchanged, tested commit available, and no production changes since that commit. Reused its **254 passed, 0 failed** result without rerunning the unchanged gate. Log/receipt remain at `C:/Users/bruno/AppData/Local/Temp/P-Chess-CI-003/gate.log` and `gate.json`.
- Callers and interactions examined: existing CI Windows export and export preset, raw theme preservation/ThemeLoader, fetch-script payload verification, licence packaging, `UCI.search_dirs`/`engine_path`, Maia network-path resolution and UI startup. Failure paths examined: download/hash/extraction/import/export failure propagation, missing required package files and publication ordering. No runtime functions changed. Clean-Windows gameplay was not performed; previous UI access was refused and was not bypassed. No new test tag or public release was created during review.
- No existing `Proxy decided` contract change appears in this ticket. The proxy was consulted only about disposition of the pending integration evidence; no criterion amendment or waiver was proposed.

- 2026-10-25 Proxy escalated (gpt-6-astra high, fallback): Preserve criterion 5 and block CI-003 pending clean-Windows gameplay evidence; isolated APPDATA, successful engine startup, package verification and the passing gate do not demonstrate the required game on a clean machine. No available environment can supply that evidence, and the proxy cannot waive the integration condition.
- Human question: Can you extract the ZIP from [release v0.0.1-rc1](https://github.com/Laginho/P-Chess/releases/tag/v0.0.1-rc1) on clean Windows, complete one game against Maia, and report the Windows version and result; or provide an authorized clean Windows environment for that check? Existing evidence of this test is sufficient if it has already been performed.
- Disposition: `Stage: blocked` on `ci-003`; no session merge or completion ledger entry. Once criterion-5 evidence arrives, restore `to-review` for focused acceptance review. Production remains unchanged.

Acceptance: pending | Implementation review has 0 Standards findings and 0 confirmed Spec defects. Criteria 1-4 pass; criterion 5 still needs clean-Windows gameplay evidence as detailed in this Resolution.
Disclosure: pending | integration | CI-003 criterion 5 and this Resolution: confirm a completed game against Maia from the downloaded release on clean Windows before integration. The branch and all verification evidence are preserved.
- 2026-10-26 Criterion 5, clean-Windows evidence (Bruno, Windows Sandbox on host Windows 11 Pro 10.0.26200, networking off, `pchess-test.wsb` mapping `%TEMP%\pchess-rc1\app` read-only to `C:\app`): the unmodified [v0.0.1-rc1](https://github.com/Laginho/P-Chess/releases/tag/v0.0.1-rc1) zip **fails** criterion 5. Starting a game against Maia shows "lc0.exe - System Error: MSVCP140.dll was not found"; Maia never moves. `lc0.exe` imports `MSVCP140.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll` and `VCOMP140.DLL` (`dnnl.dll` and `mimalloc-override.dll` need a subset); the Lc0 cpu-dnnl archive ships none of them, and a clean Windows lacks the Visual C++ runtime. With those four DLLs (14.51.36247.0, copied from the host's System32) placed beside `lc0.exe`, the same zip ran in the sandbox: pieces, clocks and moves displayed and Maia played a game. The `api-ms-win-crt-*` imports are the UCRT, built into Windows 10+.
- Needed to pass criterion 5: the release workflow copies those four DLLs app-local into `engine/lc0/` (from the Visual Studio VC redist folders on the `windows-latest` runner: `Microsoft.VC14x.CRT` and `Microsoft.VC14x.OpenMP`), the package check requires them, `docs/THIRD_PARTY.md` notes the Visual C++ runtime, and a new test tag (`v0.0.1-rc2`) is re-checked in the sandbox. Stage is left as recorded above; this is an implementation change, not the pending review evidence.
- 2026-10-26 VC++ runtime fix: `release.yml` now copies `msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll` and `vcomp140.dll` from the newest `VC/Redist/MSVC/<version>/x64` folder of the runner's Visual Studio (found with `vswhere`) into `engine/lc0/`, and the package check requires them. `docs/THIRD_PARTY.md` has a "Runtime: Microsoft Visual C++" section. Next: tag `v0.0.1-rc2` on this commit, then re-run the clean-Windows game in `pchess-test.wsb` with the rc2 zip unmodified.
