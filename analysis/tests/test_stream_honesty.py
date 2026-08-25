from benchmark_analysis.stream_honesty import (
    normalize_stream_mode,
    stream_honesty_banner_md,
    summarize_stream_modes,
)


def test_normalize():
    assert normalize_stream_mode("Native") == "native"
    assert normalize_stream_mode("text_on_stream") == "text_on_stream"
    assert normalize_stream_mode("text-on-stream") == "text_on_stream"
    assert normalize_stream_mode("adapted") == "adapted"


def test_all_adapted_banner():
    recs = [
        {"StringOrStream": "stream", "StreamMode": "adapted"},
        {"StringOrStream": "bytes", "StreamMode": ""},
        {"StringOrStream": "stream", "StreamMode": "adapted"},
    ]
    s = summarize_stream_modes(recs)
    assert s["stream_rows"] == 2
    assert s["all_adapted"] is True
    ban = stream_honesty_banner_md(s)
    assert "adapted" in ban.lower()
    assert "incremental" in ban.lower()


def test_no_stream_banner():
    s = summarize_stream_modes([{"StringOrStream": "bytes"}])
    ban = stream_honesty_banner_md(s)
    assert "not measured" in ban.lower()


def test_mixed_legend():
    recs = [
        {"mode": "stream", "StreamMode": "native"},
        {"mode": "stream", "StreamMode": "adapted"},
    ]
    s = summarize_stream_modes(recs)
    assert s["has_native"]
    ban = stream_honesty_banner_md(s)
    assert "native" in ban
