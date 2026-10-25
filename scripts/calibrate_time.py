"""Offline Maia time calibration; see BOT-007 and docs/spec.md section 4.3.

Install script-only dependencies with:
    python -m pip install -r scripts/requirements-calibrate.txt
"""

from dataclasses import dataclass

import chess
import chess.pgn


CONTROLS = {"60+0": (60, 0, "1+0"), "180+2": (180, 2, "3+2"),
            "300+0": (300, 0, "5+0")}


@dataclass(frozen=True)
class Sample:
    fen: str
    control: str
    level: str
    clock_fraction: float
    seconds: float


def extract_samples(pgn):
    """Yield timed moves; ratings belong to the mover, ties round upward.

    A missing clock breaks that player's consecutive interval. First moves
    are untimed in Lichess and the game, so are used only as a baseline.
    """
    while (game := chess.pgn.read_game(pgn)) is not None:
        timing = CONTROLS.get(game.headers.get("TimeControl"))
        if not timing or game.errors or game.headers.get("Variant", "Standard") != "Standard":
            continue
        start, increment, control = timing
        levels = {}
        for side, header in [(chess.WHITE, "WhiteElo"), (chess.BLACK, "BlackElo")]:
            try:
                rating = int(game.headers.get(header, "?"))
            except ValueError:
                continue
            if 1100 <= rating <= 1900:
                levels[side] = f"maia-{((rating + 50) // 100) * 100}"
        board = game.board()
        previous = {chess.WHITE: None, chess.BLACK: None}
        for node in game.mainline():
            side = board.turn
            before, after = previous[side], node.clock()
            if side in levels and before is not None and after is not None:
                seconds = before - after + increment
                if seconds >= 0:
                    yield Sample(board.fen(), control, levels[side], before / start, seconds)
            previous[side] = after
            board.push(node.move)
