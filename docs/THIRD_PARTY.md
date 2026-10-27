# Third-party assets

## Opening catalog: Lichess

`data/openings/a.tsv` through `e.tsv` are unchanged files from
[`lichess-org/chess-openings`, commit a6189a30dc273ccb21fc2536a9a2fefd5592a67a](https://github.com/lichess-org/chess-openings/tree/a6189a30dc273ccb21fc2536a9a2fefd5592a67a).
The collection is released under the
[CC0-1.0 Public Domain Dedication](https://github.com/lichess-org/chess-openings/blob/a6189a30dc273ccb21fc2536a9a2fefd5592a67a/COPYING.txt).
The five files contain 823, 781, 1,250, 644 and 367 rows respectively (3,865 total,
excluding headers). Preserve the raw TSV files in exports; the catalog reads them at runtime.

## Engine: Leela Chess Zero (Lc0)

`scripts/fetch-engine.ps1` downloads the unmodified Windows CPU dnnl archive
`lc0-v0.32.1-windows-cpu-dnnl.zip` from the official
[Lc0 v0.32.1 release](https://github.com/LeelaChessZero/lc0/releases/tag/v0.32.1).
Exact source tag: [v0.32.1](https://github.com/LeelaChessZero/lc0/tree/v0.32.1).
Lc0 is licensed under [GPL-3.0](https://github.com/LeelaChessZero/lc0/blob/v0.32.1/COPYING).
The archive's SHA-256 is
`b9cfcfbd3dabffbfd452f6e8e087c22273721bef48eba19640b6d92006c142f5`,
matching GitHub's published release-asset digest.

The script retains the archive and extracts all its files into `engine/lc0/`,
including `COPYING`, the bundled network `791556.pb.gz`, and the DNNL/mimalloc
licence and attribution files. Each extracted file also has a pinned SHA-256.
Release ZIPs preserve these notices under `engine/lc0/`, beside the application.

## Runtime: Microsoft Visual C++

`lc0.exe` needs the Visual C++ runtime, which the Lc0 archive does not ship and a
clean Windows lacks. Release ZIPs place `msvcp140.dll`, `vcruntime140.dll`,
`vcruntime140_1.dll` and `vcomp140.dll` beside it in `engine/lc0/`, copied unmodified
from the Visual Studio redistributable folder (`VC/Redist/MSVC`) on the build runner,
as Microsoft's [redistributable files](https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files) permit.

## Networks: Maia-1

`engine/weights/maia-1100.pb.gz` through `maia-1900.pb.gz` are unmodified networks
from the official [Maia v1.0 release](https://github.com/CSSLab/maia-chess/releases/tag/v1.0)
by the Maia team (CSSLab). Exact source tag:
[v1.0](https://github.com/CSSLab/maia-chess/tree/v1.0).
Licence: [GPL-3.0](https://github.com/CSSLab/maia-chess/blob/v1.0/LICENSE).
The nine SHA-256 values pinned in `scripts/fetch-engine.ps1` were computed from
the official release downloads on 2026-10-24; this release publishes no asset
digests. The release workflow copies the unmodified upstream `v1.0/LICENSE` to
`engine/weights/COPYING` (SHA-256
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`).
Both engine and network files retain the bytes verified by the fetch script.

On a `v*` tag, `.github/workflows/release.yml` exports Windows with Godot 4.7.2,
runs the fetch script on Windows with the export folder as `-Root`, and attaches
`P-Chess-windows-x86_64.zip` to a GitHub release named after the tag. Extract the
whole ZIP into one folder and run `P-Chess.exe`; keep `P-Chess.pck` and `engine/`
beside it. No separate engine download is needed. This document is included as
`THIRD_PARTY.md` in the ZIP and as the release notes, preserving the exact upstream
source tags and licence links above.

Run `powershell -NoProfile -File scripts/fetch-engine.ps1` from a checkout, or
pass `-Root <dir>` to install under another folder. The default root is the
checkout containing the script, independent of the current working directory.
Verified cached files are reused. A checksum mismatch deletes the affected file
and exits non-zero; rerun to restore it. A failed download is also removed.

## Sounds: Lichess / Enigmahack

`themes/sounds/` bundles exactly `sfx`, `nes`, `piano` and `futuristic`, credited by
[Lichess's COPYING.md](https://github.com/lichess-org/lila/blob/81e2d1bca7a0c97ba3a980f2c51fcff67bfef7ed/COPYING.md)
to [Enigmahack](https://github.com/Enigmahack) under
[AGPL-3.0-or-later](https://www.gnu.org/licenses/agpl-3.0.html).
Source: [lila/public/sound at revision 81e2d1b](https://github.com/lichess-org/lila/tree/81e2d1bca7a0c97ba3a980f2c51fcff67bfef7ed/public/sound).
The OGG bytes are unchanged; only filenames are adapted to the game's events.
The `standard` set is not bundled.

| Local event file | Original file in each set |
|---|---|
| move.ogg | Move.ogg |
| capture.ogg | Capture.ogg |
| castle.ogg | Move.ogg |
| check.ogg | Check.ogg |
| promote.ogg | Check.ogg |
| premove.ogg | Move.ogg |
| low_time.ogg | LowTime.ogg |
| game_start.ogg | GenericNotify.ogg |
| game_end.ogg | Check.ogg (the target of the upstream Checkmate.ogg symlink) |

Lichess has no separate castle, promote or premove OGG in these sets; the mapping
above reuses each set's own clips. The sound fixtures in
`tests/fixtures/themes/builtin/sounds/quiet/` are copies of `sfx/Move.ogg` under
the same licence. Their capture event is deliberately absent.

### Folder theme format (UI-003)

Themes live under `res://themes/<kind>/<name>/` or `user://themes/<kind>/<name>/`.
User folders override bundled names. Board `theme.json` uses either
`{"light":"#f0d9b5","dark":"#b58863"}` or `{"texture":"board.png"}`; texture
paths are relative to that theme's folder and cover the entire board. A malformed
board falls back to brown with a warning. Piece folders need all twelve SVGs
`wK.svg` through `bP.svg`. Sound filenames are the local event names above;
missing events are silent. The temporary default is `sfx`, pending Bruno's review.

`ThemeLoader.list_themes(kind)` returns name-to-folder mappings for `boards`,
`pieces` and `sounds`. `load_board(name)`, `load_pieces(name)` and
`load_sounds(name)` return the drawing data, FEN-letter textures and event streams.
The board exposes `set_board_theme(name)` and `set_piece_theme(name)`;
`SoundPlayer.select_theme(name)` switches audio sets, and `play(event)` also
accepts `premove` and `low_time` for their later callers.

These files are read at runtime, including user themes, without an editor import
cache. Windows exports (CI-002) must include the raw theme `.json`, `.svg`, `.ogg`
and any board image files. This extends the existing raw piece SVG export rule.

## Pieces: cburnett

`themes/pieces/cburnett/` (`wK.svg` … `bP.svg`): chess pieces by Colin M.L. Burnett ([User:Cburnett](https://commons.wikimedia.org/wiki/User:Cburnett)), from Wikimedia Commons, under the BSD-3-Clause licence below.

Source: <https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces>. One Commons file per piece, `l` for white and `d` for black:

| File | Commons |
|---|---|
| wK.svg | <https://commons.wikimedia.org/wiki/File:Chess_klt45.svg> |
| wQ.svg | <https://commons.wikimedia.org/wiki/File:Chess_qlt45.svg> |
| wR.svg | <https://commons.wikimedia.org/wiki/File:Chess_rlt45.svg> |
| wB.svg | <https://commons.wikimedia.org/wiki/File:Chess_blt45.svg> |
| wN.svg | <https://commons.wikimedia.org/wiki/File:Chess_nlt45.svg> |
| wP.svg | <https://commons.wikimedia.org/wiki/File:Chess_plt45.svg> |
| bK.svg | <https://commons.wikimedia.org/wiki/File:Chess_kdt45.svg> |
| bQ.svg | <https://commons.wikimedia.org/wiki/File:Chess_qdt45.svg> |
| bR.svg | <https://commons.wikimedia.org/wiki/File:Chess_rdt45.svg> |
| bB.svg | <https://commons.wikimedia.org/wiki/File:Chess_bdt45.svg> |
| bN.svg | <https://commons.wikimedia.org/wiki/File:Chess_ndt45.svg> |
| bP.svg | <https://commons.wikimedia.org/wiki/File:Chess_pdt45.svg> |

Status: reproduced without network in UI-001; replace with the Commons originals before the session PR is integrated.

```
Copyright (c) Colin M.L. Burnett
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
