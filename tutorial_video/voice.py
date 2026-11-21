#!/usr/bin/env python3
"""Generates one voiceover clip per narration line into assets/voice/.

Uses HyperFrames' on-device voice (Kokoro). Set HYPERFRAMES_PYTHON to a Python
3.10+ that has `kokoro-onnx` and `soundfile` installed. Clips that already
exist with the same text and voice are kept; delete a .wav to regenerate it.

Run: python3 voice.py, then python3 build.py.
"""
import json
import os
import subprocess

N = json.load(open("narration.json"))
os.makedirs("assets/voice", exist_ok=True)
lines = {"intro": N["intro"], "outro": N["outro"], **N["steps"]}
stamp_path = "assets/voice/.texts.json"
stamps = json.load(open(stamp_path)) if os.path.exists(stamp_path) else {}

for key, text in lines.items():
    out = f"assets/voice/{key}.wav"
    if os.path.exists(out) and stamps.get(key) == [N["voice"], text]:
        continue
    print("voice", key)
    subprocess.run(["npx", "hyperframes", "tts", text, "-v", N["voice"],
                    "-s", str(N["speed"]), "-o", out], check=True,
                   stdout=subprocess.DEVNULL)
    stamps[key] = [N["voice"], text]
    json.dump(stamps, open(stamp_path, "w"), indent=1)
print("done")
