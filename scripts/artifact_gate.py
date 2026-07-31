#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "#1 analyst spec": ["docs/product-spec.md"],
    "#2 designer direction": ["docs/design-direction.md", "docs/design-redesign-brief.md"],
    "#3 iOS skeleton": ["ios/AbsTrainer/README.md", "ios/AbsTrainer/Sources/AbsTrainer/WorkoutGenerator.swift"],
    "#5 content asset plan": ["docs/asset-plan.md"],
    "#6 orchestration": ["docs/team-orchestration.md", "docs/ownership-map.md"],
    "#7 Xcode install": ["docs/xcode-install.md"],
    "#8 monetization": ["docs/monetization-roadmap.md"],
}

AUDIO_MANIFEST = ROOT / "ios/AbsTrainer/Resources/Audio/audio-assets.json"
AUDIO_HASHES = {
    "pulseGrid": "75ce7234b1b1a826dbdb8384eaae8c79a7bf760cea5e27790e26e5134823bb19",
    "forwardArc": "1023ffe6be67874714cd13e8c51577d4734e0b192215510bdbbacde762ff20cf",
    "groundedOrbit": "60d8937a9c32b66d419546f1f339397c00c2e9f0ea39269c5710e9b697e42467",
}
AUDIO_TOTAL_LIMIT = int(4.5 * 1024 * 1024)


def validate_audio():
    failures = []
    manifest = json.loads(AUDIO_MANIFEST.read_text())
    tracks = manifest.get("tracks", [])
    if [track.get("id") for track in tracks] != list(AUDIO_HASHES):
        failures.append("canonical audio registry must contain exactly pulseGrid, forwardArc, groundedOrbit")
        return failures, 0

    total_bytes = 0
    audio_dir = AUDIO_MANIFEST.parent
    expected_resources = set()
    for track in tracks:
        resource = track["resource"]
        expected_resources.add(resource)
        path = audio_dir / resource
        if not path.is_file():
            failures.append(f"missing audio resource {resource}")
            continue
        actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        expected_hash = AUDIO_HASHES[track["id"]]
        if actual_hash != expected_hash or track.get("sha256") != expected_hash:
            failures.append(f"exact hash mismatch for {resource}")
        actual_bytes = path.stat().st_size
        total_bytes += actual_bytes
        if track.get("bytes") != actual_bytes:
            failures.append(f"manifest size mismatch for {resource}")

    bundled_resources = {path.name for path in audio_dir.glob("*.m4a")}
    if bundled_resources != expected_resources:
        failures.append("bundled M4A inventory differs from canonical manifest")
    if total_bytes > AUDIO_TOTAL_LIMIT:
        failures.append(f"audio package {total_bytes} exceeds {AUDIO_TOTAL_LIMIT} bytes")
    return failures, total_bytes


def main():
    missing=[]
    for group, paths in REQUIRED.items():
        for rel in paths:
            p=ROOT/rel
            if not p.exists() or p.stat().st_size==0:
                missing.append((group,rel))
    audio_failures, audio_bytes = validate_audio()
    if missing or audio_failures:
        print('ARTIFACT GATE: FAIL')
        for group,rel in missing: print(f'- {group}: missing {rel}')
        for failure in audio_failures: print(f'- audio: {failure}')
        return 1
    print('ARTIFACT GATE: PASS')
    for group,paths in REQUIRED.items(): print(f'- {group}: {", ".join(paths)}')
    print(f'- audio: 3 exact-hash offline tracks, {audio_bytes} bytes')
    return 0
if __name__ == '__main__': sys.exit(main())
