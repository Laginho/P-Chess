from pathlib import Path

import pytest

from calibrate_time import extract_samples


FIXTURE = Path(__file__).resolve().parents[1] / "tests/fixtures/lichess_sample.pgn"


def test_fixture_extracts_consecutive_clocks_for_each_players_rating():
    with FIXTURE.open(encoding="utf-8") as pgn:
        samples = list(extract_samples(pgn))

    # First moves are untimed. 180 - 179 + 2 = 3 s for White's Nf3;
    # Black's separate clock gives 180 - 178 + 2 = 4 s for Nc6.
    assert [(s.control, s.level, s.seconds) for s in samples] == [
        ("3+2", "maia-1500", 3),
        ("3+2", "maia-1900", 4),
        ("3+2", "maia-1500", 5),
        ("3+2", "maia-1900", 3),
        ("1+0", "maia-1100", 3),
        ("5+0", "maia-1900", 4),
        ("1+0", "maia-1500", 2),
        ("3+2", "maia-1500", 1),
    ]
    assert samples[2].clock_fraction == pytest.approx(179 / 180)
    # Position before White's second move, with both opening moves present.
    assert samples[0].fen == (
        "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
    )
