# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "faster-whisper>=1.0",
# ]
# ///
# transcribe.py - speech-to-text helper for the local-tools MCP server (and handy standalone).
# Prints the transcript to stdout; anything else goes to stderr so the server can capture it cleanly.
#
#   uv run transcribe.py <audiofile>
#
# uv builds the env from the dependency block above (internet needed on FIRST run for the deps + the
# whisper model download; offline after). Install uv: winget install astral-sh.uv
#
# Knobs (env vars):
#   LOCALTOOLS_WHISPER_MODEL  tiny | base | small | medium  (default small; larger = better + slower)
#   LOCALTOOLS_WHISPER_LANG   force a language code (default: autodetect)

import os
import sys


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: transcribe.py <audiofile>", file=sys.stderr)
        sys.exit(2)
    audio = sys.argv[1]
    if not os.path.isfile(audio):
        print(f"file not found: {audio}", file=sys.stderr)
        sys.exit(1)

    from faster_whisper import WhisperModel

    size = os.environ.get("LOCALTOOLS_WHISPER_MODEL", "small")
    lang = os.environ.get("LOCALTOOLS_WHISPER_LANG") or None
    try:
        model = WhisperModel(size, device="cuda", compute_type="float16")
        print(f"whisper '{size}' on GPU", file=sys.stderr)
    except Exception:
        model = WhisperModel(size, device="cpu", compute_type="int8")
        print(f"whisper '{size}' on CPU", file=sys.stderr)

    segments, info = model.transcribe(audio, language=lang, vad_filter=True)
    print(f"language={info.language} duration={info.duration:.1f}s", file=sys.stderr)

    # Timestamped lines: useful context for a spec discussion, still plain searchable text.
    for s in segments:
        print(f"[{int(s.start // 60):02d}:{int(s.start % 60):02d}] {s.text.strip()}")


if __name__ == "__main__":
    main()
