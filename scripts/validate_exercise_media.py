#!/usr/bin/env python3
"""Validate ExerciseCatalog asset IDs, runtime copies, sizes, and SHA-256."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design/exercise-library/manifest/exercise-assets.json"
RUNTIME = ROOT / "ios/AbsTrainer/Resources/ExerciseMedia"
CATALOG = ROOT / "ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift"
HARD_TOTAL_BYTES = 13_400_000
HARD_VIDEO_BYTES = 1_200_000
HARD_POSTER_BYTES = 140_000


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    errors: list[str] = []
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    catalog_text = CATALOG.read_text(encoding="utf-8")
    catalog_ids = re.findall(r'Exercise\(id: "([^"]+)"', catalog_text)
    assets = manifest.get("assets", [])
    manifest_ids = [asset["exercise_id"] for asset in assets]

    if len(catalog_ids) != 10 or len(set(catalog_ids)) != 10:
        errors.append(f"catalog must contain 10 unique ids; found {catalog_ids}")
    if len(manifest_ids) != 10 or len(set(manifest_ids)) != 10:
        errors.append(f"manifest must contain 10 unique ids; found {manifest_ids}")
    if set(catalog_ids) != set(manifest_ids):
        errors.append("manifest ids do not match ExerciseCatalog.starter")

    total_bytes = 0
    for asset in assets:
        exercise_id = asset["exercise_id"]
        media_name = f"exercise_{exercise_id}_v1"
        poster_name = f"exercise_{exercise_id}_poster_v1"
        if asset["catalog_media_name"] != media_name:
            errors.append(f"{exercise_id}: catalog_media_name mismatch")
        if f'mediaName: "{media_name}", isPlaceholderMedia: false' not in catalog_text:
            errors.append(f"{exercise_id}: production catalog mapping is not final")

        for kind, name, extension, hard_limit in (
            ("video", media_name, "mp4", HARD_VIDEO_BYTES),
            ("poster", poster_name, "jpg", HARD_POSTER_BYTES),
        ):
            path = RUNTIME / f"{name}.{extension}"
            if not path.is_file():
                errors.append(f"{exercise_id}: missing runtime {path.name}")
                continue
            measured_size = path.stat().st_size
            total_bytes += measured_size
            if measured_size != asset[kind]["size_bytes"]:
                errors.append(f"{exercise_id}: {kind} size mismatch")
            if measured_size > hard_limit:
                errors.append(f"{exercise_id}: {kind} exceeds hard size limit")
            if sha256(path) != asset[kind]["sha256"]:
                errors.append(f"{exercise_id}: {kind} SHA-256 mismatch")

        source = asset.get("source", {})
        if source.get("provenance") != "original_in_house":
            errors.append(f"{exercise_id}: provenance must be original_in_house")
        if source.get("license") != "owned_original_work":
            errors.append(f"{exercise_id}: license must be owned_original_work")
        if source.get("third_party_inputs") != []:
            errors.append(f"{exercise_id}: third_party_inputs must be empty")

    if total_bytes > HARD_TOTAL_BYTES:
        errors.append(f"total runtime media {total_bytes} exceeds {HARD_TOTAL_BYTES}")

    if errors:
        print("EXERCISE MEDIA GATE: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("EXERCISE MEDIA GATE: PASS")
    print(f"- catalog/manifest ids: {len(manifest_ids)}/10")
    print(f"- runtime files: {len(assets) * 2} media + manifest")
    print(f"- total media bytes: {total_bytes}")
    print("- SHA-256, size, naming and original-in-house provenance: valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
