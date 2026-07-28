#!/usr/bin/env python3
"""Build the checked-in HeartMuLa Colab notebook deterministically."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "notebooks" / "heartmula_colab_free.ipynb"
OUTPUT = Path(os.environ.get("HEARTMULA_NOTEBOOK_OUTPUT", DEFAULT_OUTPUT))
LOCK_PATH = ROOT / "notebooks" / "heartmula_requirements_py310.lock"
LOCKED_REQUIREMENTS = LOCK_PATH.read_text(encoding="utf-8")
LOCK_SHA256 = hashlib.sha256(LOCKED_REQUIREMENTS.encode()).hexdigest()


def source(text: str) -> list[str]:
    normalized = dedent(text).strip("\n") + "\n"
    return normalized.splitlines(keepends=True)


def markdown(text: str) -> dict[str, object]:
    return {"cell_type": "markdown", "metadata": {}, "source": source(text)}


def code(text: str) -> dict[str, object]:
    return {
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": source(text),
    }


cells = [
    code(
        r'''
        # 1. Mandatory hardware gate: no downloads happen before this cell passes.
        import subprocess
        import torch

        if not torch.cuda.is_available():
            raise SystemExit(
                "CUDA GPU not detected. In Colab choose Runtime > Change runtime type > T4 GPU, then retry."
            )

        gpu_index = torch.cuda.current_device()
        gpu_name = torch.cuda.get_device_name(gpu_index)
        total_vram_gib = torch.cuda.get_device_properties(gpu_index).total_memory / 1024**3
        print(f"CUDA GPU: {gpu_name}")
        print(f"Total VRAM: {total_vram_gib:.2f} GiB")
        subprocess.run(["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"], check=True)

        if total_vram_gib < 8.0:
            raise SystemExit(
                f"HeartMuLa 3B requires at least 8 GiB VRAM; this runtime has {total_vram_gib:.2f} GiB."
            )
        HEARTMULA_HARDWARE_GATE = {
            "status": "PASS",
            "gpu_name": gpu_name,
            "total_vram_gib": total_vram_gib,
        }
        print("Hardware gate: PASS (this confirms capacity, not a guaranteed T4 allocation).")
        '''
    ),
    markdown(
        r'''
        # HeartMuLa 3B — Google Colab Free pipeline for Abs Trainer

        [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/EZaretskiy777/abs-trainer-ios/blob/feature/heartmula-colab-free/notebooks/heartmula_colab_free.ipynb)

        Generates an original instrumental workout draft from structural markers and tags. It uses only free Colab resources and public, ungated Apache-2.0 HeartMuLa repositories. Free Colab does **not** guarantee a T4, session duration, disk retention, or availability.

        Run cells in order. Do not skip the hardware gate. A concrete generated output still needs listening, similarity, rights, and product review before release.
        '''
    ),
    markdown(
        r'''
        ## 2. Reproducible configuration and optional Google Drive cache

        Source and model snapshots are immutable revisions. Google Drive is optional and disabled by default. Enabling it stores only the large public model cache in your Drive; inputs, generated audio, and the manifest remain in ephemeral `/content` until you download them. No credentials are printed or written by this notebook. The Hugging Face repositories are public and ungated, so no HF token is required.
        '''
    ),
    code(
        r'''
        import json
        import os
        from pathlib import Path

        USE_GOOGLE_DRIVE = False
        RUNTIME_ROOT = Path("/content/heartmula-runtime")
        SOURCE_ROOT = RUNTIME_ROOT / "heartlib"
        VENV = RUNTIME_ROOT / ".venv"
        PYTHON = VENV / "bin" / "python"
        OUTPUT_DIR = RUNTIME_ROOT / "outputs"

        HEARTLIB_COMMIT = "3783bdb8441f2c298b1e64c8651173aac200361c"
        MODEL_REVISIONS = {
            "HeartMuLa/HeartMuLaGen": "9906b2bcd4598772a32cad4aec0760170fe0d177",
            "HeartMuLa/HeartMuLa-oss-3B-happy-new-year": "41f6fc68490e11dc43fdabaa6b5767946408c903",
            "HeartMuLa/HeartCodec-oss-20260123": "f889dab0532cfa4bf459f2a3367eb6d346b8eeda",
        }
        GENERATION = {
            "seed": 20260728,
            "duration_ms": 60_000,
            "topk": 50,
            "temperature": 1.0,
            "cfg_scale": 1.5,
        }
        TAGS = (
            "instrumental,no-vocals,energetic,electronic,workout,driving-drums,"
            "pulsing-bass,bright-synthesizer,128-bpm"
        )
        STRUCTURE = """[Intro]

        [Instrumental]

        [Build]

        [Instrumental]

        [Breakdown]

        [Instrumental]

        [Finale]

        [Outro]
        """

        def require_heartmula_hardware_gate():
            import torch

            gate = globals().get("HEARTMULA_HARDWARE_GATE")
            if not isinstance(gate, dict) or gate.get("status") != "PASS":
                raise RuntimeError("Run the first hardware-gate cell successfully before this operation.")
            if not torch.cuda.is_available():
                raise RuntimeError("CUDA became unavailable after the hardware gate; stop and reconnect a GPU runtime.")
            current_vram_gib = torch.cuda.get_device_properties(torch.cuda.current_device()).total_memory / 1024**3
            if current_vram_gib < 8.0:
                raise RuntimeError(f"Current GPU has only {current_vram_gib:.2f} GiB VRAM; at least 8 GiB is required.")
            return gate

        if USE_GOOGLE_DRIVE:
            from google.colab import drive
            drive.mount("/content/drive")
            CACHE_ROOT = Path("/content/drive/MyDrive/AbsTrainer/heartmula-cache")
        else:
            CACHE_ROOT = RUNTIME_ROOT / "cache"

        CHECKPOINT_ROOT = CACHE_ROOT / "checkpoints"
        for directory in (RUNTIME_ROOT, CACHE_ROOT, CHECKPOINT_ROOT, OUTPUT_DIR):
            directory.mkdir(parents=True, exist_ok=True)

        (RUNTIME_ROOT / "workout_tags.txt").write_text(TAGS + "\n", encoding="utf-8")
        (RUNTIME_ROOT / "instrumental_structure.txt").write_text(STRUCTURE, encoding="utf-8")
        (RUNTIME_ROOT / "generation_config.json").write_text(
            json.dumps(GENERATION, indent=2) + "\n", encoding="utf-8"
        )
        os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
        print(f"Cache: {CACHE_ROOT} (Google Drive: {USE_GOOGLE_DRIVE})")
        print(json.dumps(GENERATION, indent=2))
        '''
    ),
    markdown(
        r'''
        ## 3. Install pinned source in an isolated Python 3.10.18 environment

        The notebook installs `uv==0.8.3`, Python 3.10.18, and a fully resolved, hash-verified Linux lock containing CUDA 12.1 PyTorch 2.4.1 and all transitive dependencies. It then installs official `heartlib` at the pinned commit without resolving additional packages. This cell does not download model weights.
        '''
    ),
    code(
        r'''
        import shutil
        import subprocess
        import sys

        UV_VERSION = "0.8.3"
        PYTHON_VERSION = "3.10.18"
        PACKAGE_INDEX = "https://pypi.org/simple"
        PYTORCH_INDEX = "https://download.pytorch.org/whl/cu121"
        LOCKED_REQUIREMENTS = __HEARTMULA_LOCK_REPR__
        EXPECTED_LOCK_SHA256 = "__HEARTMULA_LOCK_SHA256__"
        runtime_lock = RUNTIME_ROOT / "heartmula_requirements_py310.lock"
        runtime_lock.write_text(LOCKED_REQUIREMENTS, encoding="utf-8")
        actual_lock_sha256 = __import__("hashlib").sha256(runtime_lock.read_bytes()).hexdigest()
        if actual_lock_sha256 != EXPECTED_LOCK_SHA256:
            raise RuntimeError(f"Embedded dependency lock hash mismatch: {actual_lock_sha256}")

        subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", f"uv=={UV_VERSION}"], check=True)
        subprocess.run([sys.executable, "-m", "uv", "python", "install", PYTHON_VERSION], check=True)
        subprocess.run([sys.executable, "-m", "uv", "venv", "--python", PYTHON_VERSION, str(VENV)], check=True)

        if not (SOURCE_ROOT / ".git").exists():
            subprocess.run(
                ["git", "clone", "--filter=blob:none", "https://github.com/HeartMuLa/heartlib.git", str(SOURCE_ROOT)],
                check=True,
            )
        subprocess.run(["git", "-C", str(SOURCE_ROOT), "fetch", "origin", HEARTLIB_COMMIT], check=True)
        subprocess.run(["git", "-C", str(SOURCE_ROOT), "checkout", "--detach", HEARTLIB_COMMIT], check=True)
        actual_commit = subprocess.check_output(
            ["git", "-C", str(SOURCE_ROOT), "rev-parse", "HEAD"], text=True
        ).strip()
        if actual_commit != HEARTLIB_COMMIT:
            raise RuntimeError(f"Unexpected heartlib commit: {actual_commit}")

        subprocess.run(
            [
                sys.executable, "-m", "uv", "pip", "install", "--python", str(PYTHON),
                "--require-hashes", "--index-url", PACKAGE_INDEX,
                "--extra-index-url", PYTORCH_INDEX, "--index-strategy", "unsafe-best-match",
                "--requirements", str(runtime_lock),
            ],
            check=True,
        )
        subprocess.run(
            [
                sys.executable, "-m", "uv", "pip", "install", "--python", str(PYTHON),
                "--no-deps", "--no-build-isolation", "--editable", str(SOURCE_ROOT),
            ],
            check=True,
        )
        print(f"heartlib source: {actual_commit}")
        print(f"dependency lock sha256: {actual_lock_sha256}")
        subprocess.run([str(PYTHON), "--version"], check=True)
        subprocess.run([str(PYTHON), "-c", "import torch; print('venv torch:', torch.__version__, 'CUDA:', torch.version.cuda)"], check=True)
        '''.replace("__HEARTMULA_LOCK_REPR__", repr(LOCKED_REQUIREMENTS)).replace(
            "__HEARTMULA_LOCK_SHA256__", LOCK_SHA256
        )
    ),
    markdown(
        r'''
        ## 4. Apply narrowly scoped compatibility fixes

        Two guarded, idempotent source patches are applied to the pinned checkout:

        1. `HeartCodec.from_pretrained(..., ignore_mismatched_sizes=True)` handles checkpoint scalar-buffer shape differences documented in [heartlib issue #100](https://github.com/HeartMuLa/heartlib/issues/100). Both eager and lazy paths are patched.
        2. RoPE cache initialization is repeated after meta-device loading, before inference cache setup. Without this, affected `torchtune`/Transformers loading paths can leave `Llama3ScaledRoPE` caches unbuilt.

        Each patch requires exact expected upstream text and fails closed if the pinned source changes.
        '''
    ),
    code(
        r'''
        from pathlib import Path
        import subprocess

        pipeline_path = SOURCE_ROOT / "src/heartlib/pipelines/music_generation.py"
        pipeline_text = pipeline_path.read_text(encoding="utf-8")
        codec_sites = [
            (
                "            self._codec = HeartCodec.from_pretrained(\n"
                "                self.codec_path,\n"
                "                device_map=self.codec_device,\n"
                "                dtype=self.codec_dtype,\n"
                "            )",
                "            self._codec = HeartCodec.from_pretrained(\n"
                "                self.codec_path,\n"
                "                device_map=self.codec_device,\n"
                "                dtype=self.codec_dtype,\n"
                "                ignore_mismatched_sizes=True,\n"
                "            )",
            ),
            (
                "        self._codec = HeartCodec.from_pretrained(\n"
                "            self.codec_path,\n"
                "            device_map=self.codec_device,\n"
                "            dtype=self.codec_dtype,\n"
                "        )",
                "        self._codec = HeartCodec.from_pretrained(\n"
                "            self.codec_path,\n"
                "            device_map=self.codec_device,\n"
                "            dtype=self.codec_dtype,\n"
                "            ignore_mismatched_sizes=True,\n"
                "        )",
            ),
        ]
        for site_number, (old, new) in enumerate(codec_sites, start=1):
            if new in pipeline_text:
                continue
            matches = pipeline_text.count(old)
            if matches != 1:
                raise RuntimeError(f"Expected HeartCodec loading site {site_number} once, found {matches}")
            pipeline_text = pipeline_text.replace(old, new)
        pipeline_path.write_text(pipeline_text, encoding="utf-8")

        model_path = SOURCE_ROOT / "src/heartlib/heartmula/modeling_heartmula.py"
        model_text = model_path.read_text(encoding="utf-8")
        rope_anchor = (
            "        except RuntimeError:\n"
            "            pass\n\n"
            "        with device:"
        )
        rope_patch = (
            "        except RuntimeError:\n"
            "            pass\n\n"
            "        # Rebuild RoPE caches skipped while pretrained weights were on the meta device.\n"
            "        from torchtune.models.llama3_1._position_embeddings import Llama3ScaledRoPE\n"
            "        for module in self.modules():\n"
            "            if isinstance(module, Llama3ScaledRoPE) and not module.is_cache_built:\n"
            "                module.rope_init()\n"
            "                module.to(device)\n\n"
            "        with device:"
        )
        if "Rebuild RoPE caches skipped" not in model_text:
            matches = model_text.count(rope_anchor)
            if matches != 1:
                raise RuntimeError(f"Expected 1 setup_caches anchor, found {matches}")
            model_path.write_text(model_text.replace(rope_anchor, rope_patch), encoding="utf-8")

        subprocess.run(["git", "-C", str(SOURCE_ROOT), "diff", "--check"], check=True)
        print(subprocess.check_output(["git", "-C", str(SOURCE_ROOT), "diff", "--stat"], text=True))
        '''
    ),
    markdown(
        r'''
        ## 5. Download public model snapshots (large download)

        This starts only after the hardware gate. The three anonymous downloads total roughly 22 GB. No Hugging Face token is requested. With Drive caching, interrupted `hf download` calls can reuse existing files; without Drive, Colab deletes the runtime files when the session ends.
        '''
    ),
    code(
        r'''
        import os
        import subprocess

        require_heartmula_hardware_gate()
        HF = VENV / "bin" / "hf"
        DOWNLOADS = [
            ("HeartMuLa/HeartMuLaGen", CHECKPOINT_ROOT),
            ("HeartMuLa/HeartMuLa-oss-3B-happy-new-year", CHECKPOINT_ROOT / "HeartMuLa-oss-3B"),
            ("HeartMuLa/HeartCodec-oss-20260123", CHECKPOINT_ROOT / "HeartCodec-oss"),
        ]
        download_env = os.environ.copy()
        download_env["HF_HUB_DISABLE_TELEMETRY"] = "1"
        for repo_id, destination in DOWNLOADS:
            destination.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                [str(HF), "download", repo_id, "--revision", MODEL_REVISIONS[repo_id], "--local-dir", str(destination)],
                check=True,
                env=download_env,
            )
        print("Pinned model snapshots: READY")
        '''
    ),
    markdown(
        r'''
        ## 6. Recovery after a Colab disconnect

        If the runtime disconnects, reconnect with a GPU and rerun cells 1–4. If Drive caching was enabled previously, set `USE_GOOGLE_DRIVE = True` again and run this recovery cell. Snapshot downloads are content-addressed and resume/reuse cached files. Without Drive, the previous runtime data is not persistent and must be downloaded again.
        '''
    ),
    code(
        r'''
        import os
        import subprocess

        require_heartmula_hardware_gate()
        required_files = [
            CHECKPOINT_ROOT / "gen_config.json",
            CHECKPOINT_ROOT / "tokenizer.json",
            CHECKPOINT_ROOT / "HeartMuLa-oss-3B" / "model.safetensors.index.json",
            CHECKPOINT_ROOT / "HeartCodec-oss" / "model.safetensors.index.json",
        ]
        print("Revalidating every pinned snapshot and resuming any missing files...")
        recovery_env = os.environ.copy()
        recovery_env["HF_HUB_DISABLE_TELEMETRY"] = "1"
        for repo_id, destination in DOWNLOADS:
            subprocess.run(
                [str(HF), "download", repo_id, "--revision", MODEL_REVISIONS[repo_id], "--local-dir", str(destination)],
                check=True,
                env=recovery_env,
            )
        still_missing = [str(path) for path in required_files if not path.exists()]
        if still_missing:
            raise RuntimeError("Checkpoint recovery incomplete: " + ", ".join(still_missing))
        print("Recovery/checkpoint integrity gate: PASS")
        '''
    ),
    markdown(
        r'''
        ## 7. Generate the real audio draft

        Generation uses HeartMuLa 3B with `lazy_load=True`, bfloat16 for HeartMuLa and float32 for HeartCodec. The sample has no copyrighted lyrics or named-artist imitation. The seed improves repeatability but CUDA/model inference is not guaranteed bit-for-bit deterministic. Tags may be weakly followed; listen to the result rather than trusting labels.
        '''
    ),
    code(
        r"""
        import subprocess
        from textwrap import dedent

        require_heartmula_hardware_gate()
        generation_script = RUNTIME_ROOT / "generate_workout_track.py"
        generation_script.write_text(
            dedent(
                f'''\
                import random
                import numpy as np
                import torch
                from heartlib import HeartMuLaGenPipeline

                seed = {GENERATION["seed"]}
                random.seed(seed)
                np.random.seed(seed)
                torch.manual_seed(seed)
                torch.cuda.manual_seed_all(seed)

                pipeline = HeartMuLaGenPipeline.from_pretrained(
                    {str(CHECKPOINT_ROOT)!r},
                    device={{"mula": torch.device("cuda:0"), "codec": torch.device("cuda:0")}},
                    dtype={{"mula": torch.bfloat16, "codec": torch.float32}},
                    version="3B",
                    lazy_load=True,
                )
                with torch.no_grad():
                    pipeline(
                        {{
                            "lyrics": {str(RUNTIME_ROOT / "instrumental_structure.txt")!r},
                            "tags": {str(RUNTIME_ROOT / "workout_tags.txt")!r},
                        }},
                        max_audio_length_ms={GENERATION["duration_ms"]},
                        save_path={str(OUTPUT_DIR / "abs_trainer_workout.mp3")!r},
                        topk={GENERATION["topk"]},
                        temperature={GENERATION["temperature"]},
                        cfg_scale={GENERATION["cfg_scale"]},
                    )
                print("Generated:", {str(OUTPUT_DIR / "abs_trainer_workout.mp3")!r})
                '''
            ),
            encoding="utf-8",
        )
        subprocess.run([str(PYTHON), str(generation_script)], cwd=str(SOURCE_ROOT), check=True)
        generated_mp3 = OUTPUT_DIR / "abs_trainer_workout.mp3"
        if not generated_mp3.exists() or generated_mp3.stat().st_size == 0:
            raise RuntimeError("HeartMuLa did not create a non-empty MP3")
        print(f"Real audio output: {generated_mp3} ({generated_mp3.stat().st_size:,} bytes)")
        """
    ),
    markdown(
        r'''
        ## 8. Inspect and post-process for the local iOS music pipeline

        `ffprobe` prints machine-readable source metadata. `ffmpeg` creates a 48 kHz stereo PCM WAV master and AAC/M4A delivery file. These are handoff assets, not automatically bundled into the iOS app.
        '''
    ),
    code(
        r'''
        import json
        import shutil
        import subprocess

        if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
            subprocess.run(["apt-get", "update", "-qq"], check=True)
            subprocess.run(["apt-get", "install", "-y", "-qq", "ffmpeg"], check=True)

        probe_command = [
            "ffprobe", "-v", "error", "-show_entries",
            "format=filename,duration,size,bit_rate:stream=codec_name,sample_rate,channels",
            "-of", "json", str(generated_mp3),
        ]
        source_metadata = json.loads(subprocess.check_output(probe_command, text=True))
        print(json.dumps(source_metadata, indent=2))

        wav_master = OUTPUT_DIR / "abs_trainer_workout_master.wav"
        ios_m4a = OUTPUT_DIR / "abs_trainer_workout_ios.m4a"
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(generated_mp3), "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le", str(wav_master)],
            check=True,
        )
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(wav_master), "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(ios_m4a)],
            check=True,
        )
        for artifact in (generated_mp3, wav_master, ios_m4a):
            if not artifact.exists() or artifact.stat().st_size == 0:
                raise RuntimeError(f"Missing post-process artifact: {artifact}")
            print(f"READY: {artifact} ({artifact.stat().st_size:,} bytes)")
        '''
    ),
    markdown(
        r'''
        ## 9. Preserve provenance and download artifacts

        Apache-2.0 applies to the pinned source/model repositories; it does not by itself prove that every generated output is commercially clear. The manifest preserves source/model evidence, parameters, and output hashes. Review the concrete audio for recognizable lyrics, artist/style imitation, similarity, artifacts, and product fit before any release.
        '''
    ),
    code(
        r'''
        import hashlib
        import json
        import subprocess
        from datetime import datetime, timezone

        artifacts = [generated_mp3, wav_master, ios_m4a]
        runtime_environment = json.loads(
            subprocess.check_output(
                [
                    str(PYTHON), "-c",
                    "import json,platform,torch; print(json.dumps({'python': platform.python_version(), 'torch': torch.__version__, 'cuda': torch.version.cuda}))",
                ],
                text=True,
            )
        )
        manifest = {
            "created_at_utc": datetime.now(timezone.utc).isoformat(),
            "environment": {
                **runtime_environment,
                "dependency_lock_sha256": actual_lock_sha256,
            },
            "heartlib": {
                "url": "https://github.com/HeartMuLa/heartlib",
                "revision": HEARTLIB_COMMIT,
                "license": "Apache-2.0",
            },
            "models": [
                {"repo": repo, "revision": revision, "license": "Apache-2.0"}
                for repo, revision in MODEL_REVISIONS.items()
            ],
            "generation": GENERATION,
            "tags": TAGS,
            "structure": STRUCTURE,
            "commercial_clearance": "NOT_ASSERTED_REQUIRES_OUTPUT_REVIEW",
            "outputs": [
                {
                    "filename": path.name,
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
                for path in artifacts
            ],
        }
        manifest_path = OUTPUT_DIR / "heartmula_generation_manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(manifest, indent=2))

        from google.colab import files
        for path in [*artifacts, manifest_path]:
            files.download(str(path))
        '''
    ),
    markdown(
        r'''
        ## 10. Cleanup

        Download desired outputs first. Runtime cleanup is opt-in and preserves a Drive cache unless separately confirmed. Colab may erase `/content` automatically when the runtime ends.
        '''
    ),
    code(
        r'''
        import gc
        import shutil
        import torch

        CONFIRM_RUNTIME_CLEANUP = False
        CONFIRM_DRIVE_CACHE_DELETE = False

        if CONFIRM_RUNTIME_CLEANUP:
            shutil.rmtree(RUNTIME_ROOT, ignore_errors=True)
            gc.collect()
            torch.cuda.empty_cache()
            print("Deleted runtime files under", RUNTIME_ROOT)
        else:
            print("Runtime cleanup skipped. Set CONFIRM_RUNTIME_CLEANUP=True after downloading outputs.")

        if USE_GOOGLE_DRIVE and CONFIRM_DRIVE_CACHE_DELETE:
            shutil.rmtree(CACHE_ROOT, ignore_errors=True)
            print("Deleted optional Drive cache", CACHE_ROOT)
        elif USE_GOOGLE_DRIVE:
            print("Drive cache preserved. Set CONFIRM_DRIVE_CACHE_DELETE=True to delete it explicitly.")
        '''
    ),
]

notebook = {
    "cells": cells,
    "metadata": {
        "accelerator": "GPU",
        "colab": {"gpuType": "T4", "provenance": []},
        "kernelspec": {"display_name": "Python 3", "name": "python3"},
        "language_info": {"name": "python", "version": "3.x"},
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(notebook, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {OUTPUT}")
