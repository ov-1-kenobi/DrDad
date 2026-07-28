# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "faster-whisper>=1.0",
#   "sounddevice>=0.4",
#   "numpy>=1.26",
#   "pyttsx3>=2.90",
# ]
# ///
# voice.py - push-to-talk voice loop for Claude Code (local/offline after first run).
#
#   [mic] -> faster-whisper (STT, uses the GPU) -> claude -p --continue -> stdout -> SAPI TTS -> [speakers]
#
# Direct comms - no window handles, no TUI scraping: each utterance is a headless `claude -p` call and
# `--continue` keeps one conversation going. Run it FROM YOUR PROJECT FOLDER so CLAUDE.md/.mcp.json load:
#
#   cd C:\src\MyProject
#   uv run C:\path\to\AD-kit\voice.py        (or just: voice.cmd from the kit folder on PATH)
#
# uv reads the dependency block above and builds the env automatically (internet needed on FIRST run for
# deps + the whisper model download; offline after). Install uv:  winget install astral-sh.uv
#
# Knobs (env vars):
#   VOICE_WHISPER_MODEL  whisper size: tiny/base/small/medium  (default small; larger = better + slower)
#   VOICE_RATE           TTS words-per-minute                  (default 180)
# TTS uses the built-in Windows SAPI voices (zero setup). For nicer speech later, swap the speak()
# function for Piper (pip: piper-tts + a downloaded .onnx voice) - one function, nothing else changes.

import os
import shutil
import subprocess
import sys

import numpy as np
import sounddevice as sd

SAMPLE_RATE = 16000


def find_claude() -> str:
    exe = shutil.which("claude")
    if not exe:
        sys.exit("claude CLI not found on PATH (npm install -g @anthropic-ai/claude-code)")
    return exe


def record() -> np.ndarray:
    """Push-to-talk: Enter starts, Enter stops."""
    input("\n[Enter] to talk (Ctrl+C to quit) ")
    chunks: list[np.ndarray] = []

    def cb(indata, frames, t, status):  # noqa: ANN001 - sounddevice callback signature
        chunks.append(indata.copy())

    with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="float32", callback=cb):
        input("recording... [Enter] to stop ")
    if not chunks:
        return np.zeros(0, dtype=np.float32)
    return np.concatenate(chunks)[:, 0]


def make_stt():
    from faster_whisper import WhisperModel

    size = os.environ.get("VOICE_WHISPER_MODEL", "small")
    try:
        model = WhisperModel(size, device="cuda", compute_type="float16")
        print(f"whisper '{size}' on GPU")
    except Exception:
        model = WhisperModel(size, device="cpu", compute_type="int8")
        print(f"whisper '{size}' on CPU (no CUDA)")

    def stt(audio: np.ndarray) -> str:
        segments, _ = model.transcribe(audio, language="en", vad_filter=True)
        return " ".join(s.text.strip() for s in segments).strip()

    return stt


def make_tts():
    import pyttsx3

    engine = pyttsx3.init()
    engine.setProperty("rate", int(os.environ.get("VOICE_RATE", "180")))

    def speak(text: str) -> None:
        # SAPI chokes on very long monologues; speak the first ~1200 chars, print the rest.
        engine.say(text[:1200])
        engine.runAndWait()

    return speak


def ask_claude(exe: str, text: str, first_turn: bool) -> str:
    args = [exe, "-p"] + ([] if first_turn else ["--continue"]) + [text]
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0 and not first_turn:
        # --continue fails when no prior conversation exists in this folder - retry fresh.
        r = subprocess.run([exe, "-p", text], capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
    out = (r.stdout or "").strip()
    return out if out else f"(claude returned nothing; stderr: {(r.stderr or '').strip()[:300]})"


def main() -> None:
    claude = find_claude()
    print(f"project: {os.getcwd()}")
    stt = make_stt()
    speak = make_tts()
    first_turn = True

    while True:
        audio = record()
        if audio.size < SAMPLE_RATE // 2:  # under half a second - ignore
            print("(too short, try again)")
            continue
        text = stt(audio)
        if not text:
            print("(heard nothing)")
            continue
        print(f"\nYOU: {text}\n...thinking...")
        reply = ask_claude(claude, text, first_turn)
        first_turn = False
        print(f"\nCLAUDE:\n{reply}\n")
        speak(reply)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nbye")
