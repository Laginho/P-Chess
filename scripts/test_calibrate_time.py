from pathlib import Path
from dataclasses import replace
import io
import math

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


def test_buckets_match_game_edges_and_omit_sparse_groups():
    from calibrate_time import build_table

    with FIXTURE.open(encoding="utf-8") as pgn:
        example = next(extract_samples(pgn))
    # A worked log-normal sample: logs 0, ln(2), ln(4), so median=2
    # and population log-sigma=sqrt(2/3)*ln(2).
    samples = [replace(example, clock_fraction=0.5, seconds=s) for s in (1, 2, 4)]
    samples += [replace(example, level="maia-1100", seconds=99)]
    table = build_table(samples, lambda sample: 0.6, min_samples=3)
    assert table["clock_bins"] == [0, 0.15, 0.5, 1]
    assert table["top_p_bins"] == [0, 0.3, 0.6, 1]
    assert len(table["buckets"]) == 1
    assert table["buckets"][0] == {
        "control": "3+2", "level": "maia-1500", "clock_bin": 2,
        "top_p_bin": 2, "median": 2,
        "log_sigma": pytest.approx(math.sqrt(2 / 3) * math.log(2)),
    }
    # Increment can lift clocks above their starting time. Both end bins clamp.
    for fraction, top_p, expected in [(1.1, 1, (2, 2)), (0, 0, (0, 0)),
                                       (0.15, 0.3, (1, 1))]:
        table = build_table([replace(example, clock_fraction=fraction, seconds=0)],
                            lambda sample: top_p, min_samples=1)
        bucket = table["buckets"][0]
        assert (bucket["clock_bin"], bucket["top_p_bin"]) == expected
        assert bucket["median"] == 0.05
        assert bucket["log_sigma"] == 0
    assert build_table([], lambda sample: 0.6)["buckets"] == []


def test_fixture_extraction_from_a_capped_zstandard_stream():
    import zstandard
    from calibrate_time import pgn_stream

    compressed = zstandard.ZstdCompressor().compress(FIXTURE.read_bytes())
    source = io.BytesIO(compressed + b"must not be read")
    with pgn_stream(source, len(compressed)) as pgn:
        assert len(list(extract_samples(pgn))) == 8
    assert source.tell() == len(compressed)

    # A cap can cut a zstd frame and a PGN game. Earlier data stays usable.
    prefix = compressed[:-10]
    source = io.BytesIO(prefix + b"must not be read")
    with pgn_stream(source, len(prefix)) as pgn:
        assert list(extract_samples(pgn))
    assert source.tell() == len(prefix)
