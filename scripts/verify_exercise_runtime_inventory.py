#!/usr/bin/env python3
"""Verify runtime exercise media is exactly the approved export inventory."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "design/exercise-library/manifest/exercise-assets.json"
RUNTIME = ROOT / "ios/AbsTrainer/Resources/ExerciseMedia"
EXPORTS = ROOT / "design/exercise-library/exports"
CATALOG = ROOT / "ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift"
RUNTIME_MANIFEST = RUNTIME / "exercise-assets.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    errors: list[str] = []
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assets = data["assets"]
    manifest_ids = [item["exercise_id"] for item in assets]
    catalog_ids = re.findall(
        r'Exercise\(id: "([^"]+)"',
        CATALOG.read_text(encoding="utf-8"),
    )
    expected_media = {
        name
        for exercise_id in manifest_ids
        for name in (
            f"exercise_{exercise_id}_v1.mp4",
            f"exercise_{exercise_id}_poster_v1.jpg",
        )
    }
    runtime_names = {path.name for path in RUNTIME.iterdir() if path.is_file()}
    export_names = {path.name for path in EXPORTS.iterdir() if path.is_file()}

    if len(manifest_ids) != 10 or len(set(manifest_ids)) != 10:
        errors.append("manifest does not contain 10 unique exercise ids")
    if set(manifest_ids) != set(catalog_ids):
        errors.append("manifest ids differ from ExerciseCatalog.starter")
    if runtime_names != expected_media | {"exercise-assets.json"}:
        errors.append(
            "runtime inventory mismatch: "
            f"{sorted(runtime_names ^ (expected_media | {'exercise-assets.json'}))}"
        )
    if export_names != expected_media:
        errors.append(f"design export inventory mismatch: {sorted(export_names ^ expected_media)}")
    if MANIFEST.read_bytes() != RUNTIME_MANIFEST.read_bytes():
        errors.append("runtime manifest is not byte-identical to canonical manifest")

    for item in assets:
        exercise_id = item["exercise_id"]
        for kind, filename in (
            ("video", f"exercise_{exercise_id}_v1.mp4"),
            ("poster", f"exercise_{exercise_id}_poster_v1.jpg"),
        ):
            runtime = RUNTIME / filename
            design = EXPORTS / filename
            if not runtime.is_file() or runtime.stat().st_size == 0:
                errors.append(f"{exercise_id}: missing/empty runtime {kind}")
                continue
            if runtime.read_bytes() != design.read_bytes():
                errors.append(f"{exercise_id}: runtime {kind} differs from approved export")
            if digest(runtime) != item[kind]["sha256"]:
                errors.append(f"{exercise_id}: runtime {kind} checksum differs from manifest")

    print("RUNTIME INVENTORY GATE:", "FAIL" if errors else "PASS")
    print(f"- catalog ids: {len(catalog_ids)} unique={len(set(catalog_ids))}")
    print(f"- manifest ids: {len(manifest_ids)} unique={len(set(manifest_ids))}")
    print(f"- runtime inventory: {len(runtime_names)} files (20 media + 1 manifest)")
    print(f"- design exports: {len(export_names)} files")
    print(
        "- runtime media byte-identical to approved exports and checksums: yes"
        if not errors
        else "- runtime equality/checksums: see errors"
    )
    for error in errors:
        print(f"ERROR: {error}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
