#!/usr/bin/env python3
"""Generate review-ready normalized diffs for Tempo/Cut XCTest screenshots."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Final

from PIL import Image, ImageChops, ImageEnhance, ImageStat

ROOT: Final = Path(__file__).resolve().parents[1]
DEFAULT_BASELINES: Final = ROOT / "design/tempo-cut/previews"
MAPPING: Final = {
    "01-setup-reference.png": "tempo-cut-home.png",
    "02-plan-reference.png": "tempo-cut-plan.png",
    "03-active-reference.png": "tempo-cut-active.png",
    "04-rest-reference.png": "tempo-cut-rest.png",
    "05-finish-reference.png": "tempo-cut-finish.png",
}


def normalized_rgb(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Normalize device scale/chrome by resizing the complete viewport to the approved viewport."""
    return image.convert("RGB").resize(size, Image.Resampling.LANCZOS)


def compare(captured: Path, baseline: Path, output: Path) -> dict[str, object]:
    with Image.open(baseline) as baseline_image, Image.open(captured) as captured_image:
        baseline_rgb = baseline_image.convert("RGB")
        captured_size = captured_image.size
        normalized = normalized_rgb(captured_image, baseline_rgb.size)
        difference = ImageChops.difference(normalized, baseline_rgb)
        channel_means = ImageStat.Stat(difference).mean
        normalized_mae = sum(channel_means) / (len(channel_means) * 255.0)

        output.mkdir(parents=True, exist_ok=True)
        stem = baseline.stem
        actual_copy = output / f"{stem}-actual.png"
        baseline_copy = output / f"{stem}-approved.png"
        normalized_actual = output / f"{stem}-actual-normalized.png"
        diff_path = output / f"{stem}-diff.png"
        shutil.copy2(captured, actual_copy)
        shutil.copy2(baseline, baseline_copy)
        normalized.save(normalized_actual)
        ImageEnhance.Contrast(difference).enhance(3.0).save(diff_path)
        return {
            "state": stem.removeprefix("tempo-cut-"),
            "captured_source": str(captured),
            "captured": str(actual_copy),
            "baseline_source": str(baseline),
            "baseline": str(baseline_copy),
            "captured_size": list(captured_size),
            "baseline_size": list(baseline_rgb.size),
            "normalization": "full-viewport RGB Lanczos resize to approved baseline dimensions",
            "normalized_mae": round(normalized_mae, 6),
            "normalized_actual": str(normalized_actual),
            "diff": str(diff_path),
        }


def render_html(results: list[dict[str, object]], output: Path, threshold: float) -> None:
    rows = []
    for result in results:
        state = result["state"]
        score_value = result["normalized_mae"]
        assert isinstance(score_value, (int, float))
        score = float(score_value)
        verdict = "PASS" if score <= threshold else "REVIEW"
        rows.append(
            f"<tr><td>{state}</td><td>{score:.6f}</td><td>{verdict}</td>"
            f"<td><img src='{Path(str(result['baseline'])).name}'></td>"
            f"<td><img src='{Path(str(result['normalized_actual'])).name}'></td>"
            f"<td><img src='{Path(str(result['diff'])).name}'></td></tr>"
        )
    html = f"""<!doctype html><meta charset='utf-8'><title>Tempo/Cut visual evidence</title>
<style>body{{font:14px system-ui;margin:24px}}table{{border-collapse:collapse}}td,th{{border:1px solid #bbb;padding:8px;vertical-align:top}}img{{width:220px;height:auto}}</style>
<h1>Tempo/Cut normalized visual comparison</h1>
<p>Threshold: normalized RGB MAE ≤ {threshold:.3f}. Device scale/chrome is normalized by full-viewport Lanczos resize; PASS is a regression signal, not a replacement for human visual approval.</p>
<table><thead><tr><th>State</th><th>MAE</th><th>Gate</th><th>Approved</th><th>Actual normalized</th><th>Amplified diff</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
"""
    (output / "visual-report.html").write_text(html, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--captured", type=Path, required=True, help="Directory containing exported XCTest PNG attachments")
    parser.add_argument("--baselines", type=Path, default=DEFAULT_BASELINES)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--threshold", type=float, default=0.20)
    parser.add_argument(
        "--review-outcome",
        choices=("PENDING", "PASS", "FAIL"),
        default="PENDING",
        help="Independent human review status; automation must not promote PENDING to PASS",
    )
    args = parser.parse_args()

    if not 0 <= args.threshold <= 1:
        parser.error("--threshold must be between 0 and 1")

    missing = [name for name in MAPPING if not (args.captured / name).is_file()]
    missing += [name for name in MAPPING.values() if not (args.baselines / name).is_file()]
    if missing:
        print("VISUAL EVIDENCE: FAIL — missing files")
        for name in missing:
            print(f"- {name}")
        return 2

    results = [
        compare(args.captured / capture, args.baselines / baseline, args.output)
        for capture, baseline in MAPPING.items()
    ]
    render_html(results, args.output, args.threshold)
    scores = []
    for item in results:
        score = item["normalized_mae"]
        assert isinstance(score, (int, float))
        scores.append(float(score))
    report = {
        "threshold": args.threshold,
        "method": "normalized full-viewport RGB mean absolute error",
        "results": results,
        "gate_passed": all(score <= args.threshold for score in scores),
        "manual_review_required": True,
        "independent_review_outcome": args.review_outcome,
    }
    (args.output / "visual-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["gate_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
