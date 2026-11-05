# AGENTS.md

## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage roles, each label equal to its name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Bindings do fluxo (skill `ticket-flow`)

- Gate: `godot --headless -s tests/run.gd`
- Godot: on Windows, `godot` is `C:\Users\bruno\AppData\Local\Programs\Godot\godot.cmd` (Godot 4.7 console exe beside it). On the Linux box, `godot` is `~/.local/bin/godot`, a link to Godot 4.7.2 in `/run/media/lage/New Volume/Tools/godot/`. It is installed on both: if a sandbox denies reading it or writing `.git`, escalate the command; never download Godot again.
- Disk space on the Linux box: the SSD (`/`, home, this repo) is nearly full. Put anything large that does not have to live in the repo (tools, downloads, engine builds, captures, caches, scratch data) on the hard disk at `/run/media/lage/New Volume/` instead, e.g. under `Tools/` or `Scratch/`. Never touch its `Migration/` folder.
- Base branch: `main`
- Windowed runs by agents (captures, live checks, anything not `--headless`): open the window off Bruno's screen with `--position 3000,3000`, e.g. `godot --path . --position 3000,3000`, so it does not cover what he is using. Commands handed to Bruno to play the game himself keep the default position.
