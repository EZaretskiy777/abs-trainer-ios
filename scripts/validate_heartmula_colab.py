#!/usr/bin/env python3
"""Static validation for the checked-in HeartMuLa Colab pipeline."""

from __future__ import annotations

import ast
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_NOTEBOOK = ROOT / "notebooks" / "heartmula_colab_free.ipynb"
NOTEBOOK = Path(os.environ.get("HEARTMULA_NOTEBOOK_PATH", DEFAULT_NOTEBOOK))
SAMPLES = ROOT / "notebooks" / "heartmula_samples"
BUILDER = ROOT / "scripts" / "build_heartmula_notebook.py"
LOCK = ROOT / "notebooks" / "heartmula_requirements_py310.lock"

REQUIRED_TEXT = [
    "Open In Colab",
    "Mandatory hardware gate",
    "total_vram_gib < 8.0",
    "Python 3.10",
    "USE_GOOGLE_DRIVE = False",
    "HF token is required",
    "lazy_load=True",
    '"codec": torch.float32',
    "ffprobe",
    "abs_trainer_workout_master.wav",
    "abs_trainer_workout_ios.m4a",
    "commercial_clearance",
    "Recovery after a Colab disconnect",
    "Cleanup",
]
BANNED_PATTERNS = {
    "embedded credential": re.compile(
        r"(?i)(?:api[_-]?key|access[_-]?token|secret|password)\s*=\s*['\"][^'\"]+['\"]"
    ),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "shell=True": re.compile(r"shell\s*=\s*True"),
    "paid API": re.compile(r"(?i)(openai\.com/v1|api\.suno|elevenlabs\.io/v1)"),
    "artist imitation": re.compile(r"(?i)(in the style of|sound like|imitate)\s+[A-Z][\w.-]+"),
}
EXPECTED_HEARTLIB_COMMIT = "3783bdb8441f2c298b1e64c8651173aac200361c"
EXPECTED_MODEL_REVISIONS = {
    "HeartMuLa/HeartMuLaGen": "9906b2bcd4598772a32cad4aec0760170fe0d177",
    "HeartMuLa/HeartMuLa-oss-3B-happy-new-year": "41f6fc68490e11dc43fdabaa6b5767946408c903",
    "HeartMuLa/HeartCodec-oss-20260123": "f889dab0532cfa4bf459f2a3367eb6d346b8eeda",
}
EXPECTED_GENERATION = {
    "cfg_scale": 1.5,
    "duration_ms": 60000,
    "seed": 20260728,
    "temperature": 1.0,
    "topk": 50,
}


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def literal_assignments(source: str) -> dict[str, object]:
    assignments: dict[str, object] = {}
    for node in ast.parse(source).body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name):
            try:
                assignments[target.id] = ast.literal_eval(node.value)
            except (ValueError, TypeError):
                pass
    return assignments


def main() -> int:
    errors: list[str] = []
    try:
        notebook = json.loads(NOTEBOOK.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: cannot parse notebook JSON: {exc}")
        return 1

    if notebook.get("nbformat") != 4:
        fail("nbformat must be 4", errors)
    cells = notebook.get("cells")
    if not isinstance(cells, list) or not cells:
        fail("notebook must contain cells", errors)
        cells = []

    if cells:
        first = cells[0]
        first_source = "".join(first.get("source", []))
        if first.get("cell_type") != "code":
            fail("first cell must be the executable hardware gate", errors)
        for marker in (
            "torch.cuda.is_available",
            "get_device_name",
            "total_vram_gib",
            "HEARTMULA_HARDWARE_GATE",
            "SystemExit",
        ):
            if marker not in first_source:
                fail(f"first cell missing hardware marker: {marker}", errors)

    cell_sources = ["".join(cell.get("source", [])) for cell in cells]
    all_text = "\n".join(cell_sources)
    for text in REQUIRED_TEXT:
        if text not in all_text:
            fail(f"missing required notebook text: {text}", errors)

    config_sources = [source for source in cell_sources if "HEARTLIB_COMMIT =" in source]
    if len(config_sources) != 1:
        fail(f"expected one configuration cell, found {len(config_sources)}", errors)
    else:
        assignments = literal_assignments(config_sources[0])
        if assignments.get("HEARTLIB_COMMIT") != EXPECTED_HEARTLIB_COMMIT:
            fail("HEARTLIB_COMMIT is not the approved immutable revision", errors)
        if assignments.get("MODEL_REVISIONS") != EXPECTED_MODEL_REVISIONS:
            fail("MODEL_REVISIONS mapping differs from approved immutable revisions", errors)
        if assignments.get("GENERATION") != EXPECTED_GENERATION:
            fail("notebook generation parameters differ from the sample contract", errors)

    expected_order = [
        "Mandatory hardware gate",
        "PYTHON_VERSION = \"3.10.18\"",
        "codec_sites = [",
        "DOWNLOADS = [",
        "Revalidating every pinned snapshot",
        "generation_script =",
        "probe_command =",
        '"commercial_clearance":',
        "CONFIRM_RUNTIME_CLEANUP = False",
    ]
    order_indexes: list[int] = []
    for marker in expected_order:
        matches = [index for index, source in enumerate(cell_sources) if marker in source]
        if len(matches) != 1:
            fail(f"expected ordering marker once: {marker} (found {len(matches)})", errors)
        else:
            order_indexes.append(matches[0])
    if len(order_indexes) == len(expected_order) and order_indexes != sorted(order_indexes):
        fail("hardware/setup/patch/download/recovery/generation/postprocess/provenance/cleanup order is invalid", errors)
    for risk_marker in ("DOWNLOADS = [", "required_files = [", "generation_script ="):
        risk_sources = [source for source in cell_sources if risk_marker in source]
        if len(risk_sources) != 1 or risk_sources[0].count("require_heartmula_hardware_gate()") != 1:
            fail(f"risky cell must revalidate the hardware-gate sentinel: {risk_marker}", errors)

    try:
        lock_text = LOCK.read_text(encoding="utf-8")
        lock_sha256 = hashlib.sha256(lock_text.encode()).hexdigest()
        setup_sources = [source for source in cell_sources if "LOCKED_REQUIREMENTS =" in source]
        if len(setup_sources) != 1:
            fail(f"expected one locked setup cell, found {len(setup_sources)}", errors)
        else:
            setup_assignments = literal_assignments(setup_sources[0])
            if setup_assignments.get("LOCKED_REQUIREMENTS") != lock_text:
                fail("embedded dependency lock differs from tracked lock file", errors)
            if setup_assignments.get("EXPECTED_LOCK_SHA256") != lock_sha256:
                fail("embedded dependency lock SHA-256 is incorrect", errors)
        for pin in ("torch==2.4.1+cu121", "transformers==4.57.0", "modelscope==1.33.0"):
            if pin not in lock_text:
                fail(f"dependency lock missing required pin: {pin}", errors)
        if "--hash=sha256:" not in lock_text:
            fail("dependency lock does not contain package hashes", errors)
    except OSError as exc:
        fail(f"cannot validate dependency lock: {exc}", errors)

    for name, pattern in BANNED_PATTERNS.items():
        if pattern.search(all_text):
            fail(f"banned content found: {name}", errors)

    for index, cell in enumerate(cells, start=1):
        if cell.get("cell_type") != "code":
            continue
        code = "".join(cell.get("source", []))
        try:
            compile(code, f"{NOTEBOOK.name}:cell-{index}", "exec")
        except SyntaxError as exc:
            fail(f"Python compile failed in cell {index}: {exc}", errors)
        if cell.get("outputs"):
            fail(f"cell {index} contains committed outputs", errors)
        if cell.get("execution_count") is not None:
            fail(f"cell {index} contains an execution count", errors)

    try:
        config = json.loads((SAMPLES / "generation_config.json").read_text(encoding="utf-8"))
        if config != EXPECTED_GENERATION:
            fail("sample generation_config.json differs from notebook contract", errors)
        tags = (SAMPLES / "workout_tags.txt").read_text(encoding="utf-8").strip()
        structure = (SAMPLES / "instrumental_structure.txt").read_text(encoding="utf-8")
        if "instrumental" not in tags or "no-vocals" not in tags:
            fail("sample tags must request an instrumental/no-vocals track", errors)
        if not all(section in structure for section in ("[Intro]", "[Instrumental]", "[Outro]")):
            fail("sample structure is missing required sections", errors)
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot validate sample inputs: {exc}", errors)

    try:
        with tempfile.TemporaryDirectory(prefix="heartmula-notebook-check-") as temp_dir:
            rebuilt = Path(temp_dir) / NOTEBOOK.name
            env = os.environ.copy()
            env["HEARTMULA_NOTEBOOK_OUTPUT"] = str(rebuilt)
            result = subprocess.run(
                [sys.executable, str(BUILDER)],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            if result.returncode != 0:
                fail(f"notebook builder failed with exit {result.returncode}: {result.stderr.strip()}", errors)
            elif rebuilt.read_bytes() != NOTEBOOK.read_bytes():
                fail("checked-in notebook differs from deterministic builder output", errors)
    except OSError as exc:
        fail(f"cannot compare notebook with builder output: {exc}", errors)

    if errors:
        print("HEARTMULA COLAB VALIDATION: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    code_cells = sum(cell.get("cell_type") == "code" for cell in cells)
    print("HEARTMULA COLAB VALIDATION: PASS")
    print(f"- JSON/nbformat: PASS ({len(cells)} cells)")
    print(f"- Python compile: PASS ({code_cells} code cells)")
    print("- Static secret/paid-API/artist-imitation review: PASS")
    print("- Exact pins, hashed lock, cell ordering, and sample inputs: PASS")
    print("- Deterministic builder parity: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
