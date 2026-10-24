# BOT-001: Engine fetch script
Stage: implementing
Blocked by: none
Review: human
Difficulty: normal

- Primary files:
  - New: scripts/fetch-engine.ps1
  - docs/THIRD_PARTY.md (Lc0 and Maia entries)

#### What to build

`scripts/fetch-engine.ps1` downloads the pinned Lc0 build and the nine Maia nets into `engine/` and checks their SHA-256 hashes (§3.1). CI's release job uses the same script. Review is `human` because the script downloads executables.

#### Acceptance criteria

1. Runs in Windows PowerShell 5.1: no `&&`, `||`, ternary, `??` or `?.`.
2. Downloads the Lc0 v0.32.1 CPU dnnl Windows zip from its official GitHub release and extracts it to `engine/lc0/`, and downloads `maia-1100.pb.gz` … `maia-1900.pb.gz` from the official Maia release to `engine/weights/`.
3. Every file's SHA-256 is checked against a hash pinned in the script; on a mismatch the file is deleted and the script exits non-zero.
4. Files already present with the right hash are not downloaded again.
5. A `-Root <dir>` parameter sets the target folder (default: the repo root).
6. Pin SHA-256 hashes computed from the actual official release downloads and record the release tags, asset names, URLs, and hashes in the verification evidence. Compare against any upstream-published digest where available. Compare these artifacts with Bruno's existing `engine/` copies when those copies are available. If unavailable, record the comparison as pending: stage 2 may hand off to human review after the other acceptance checks pass, but integration requires Bruno either to confirm the comparison or explicitly accept the recorded upstream artifacts as the baseline.
7. `docs/THIRD_PARTY.md` names Lc0 and Maia, their GPL-3 licence and the exact upstream tags.

#### Verification

    powershell -NoProfile -File scripts/fetch-engine.ps1 -Root <empty temp dir>   # downloads, exit 0
    powershell -NoProfile -File scripts/fetch-engine.ps1 -Root <same dir>          # skips every file, exit 0
    Tamper one byte of a downloaded net, run again: exit non-zero.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: the script is checked by the three runs above, recorded in the ticket.

## Comments

- 2026-10-24 Proxy decided (gpt-6-astra high, fallback): Proceed with stage 2 using hashes computed from official upstream downloads; preserve comparison with Bruno's copies as an explicit human integration gate. Missing local reference files do not prevent implementing and testing the downloader, but upstream hashes cannot establish equivalence with unavailable copies. Criterion 6 incorporates this decision; Primary files and `Review: human` are unchanged.
- Bruno-copy comparison: pending — reference copies unavailable in this worktree and `D:/Desktop/Projects/P-Chess/engine/`. The earlier night-run report (`docs/relatorios/2026-10-24-sweatshop-night-core.tex`) also records missing engine files.
- Pre-implementation verification: the ticket's first PowerShell command fails because `scripts/fetch-engine.ps1` does not exist (exit -196608). Log: `C:/Users/Lage/AppData/Local/Temp/P-Chess-BOT-001-evidence-20261024/red-missing-script.txt`. The ticket explicitly exempts GDScript tests; verification uses its public command-line seam. No existing function is changed. Future callers are manual setup and CI-003's release job; inspected `docs/spec.md` §§3.1/12 and CI-003. Relevant boundaries: empty target, paths with spaces, valid cached assets, corrupt cached/downloaded assets, missing extracted files and download failure.

Disclosure: decision | integration | Criterion 6 and the proxy decision above: Bruno must compare his reference copies or explicitly accept the recorded official upstream artifacts as the baseline before integration.
