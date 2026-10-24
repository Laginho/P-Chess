# BOT-001: Engine fetch script
Stage: to-implement
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
6. The pinned hashes match the copies already in Bruno's `engine/` folder.
7. `docs/THIRD_PARTY.md` names Lc0 and Maia, their GPL-3 licence and the exact upstream tags.

#### Verification

    powershell -NoProfile -File scripts/fetch-engine.ps1 -Root <empty temp dir>   # downloads, exit 0
    powershell -NoProfile -File scripts/fetch-engine.ps1 -Root <same dir>          # skips every file, exit 0
    Tamper one byte of a downloaded net, run again: exit non-zero.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: the script is checked by the three runs above, recorded in the ticket.

## Comments
