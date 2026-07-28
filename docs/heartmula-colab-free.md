# HeartMuLa 3B on Google Colab Free

## Purpose

`notebooks/heartmula_colab_free.ipynb` is a reproducible, free-resource pipeline for generating an original instrumental workout-music draft for Abs Trainer. It prepares MP3, 48 kHz stereo PCM WAV, and AAC/M4A outputs plus a provenance manifest. It does not modify or bundle files into the production iOS target.

[Open the pinned feature branch in Colab](https://colab.research.google.com/github/EZaretskiy777/abs-trainer-ios/blob/feature/heartmula-colab-free/notebooks/heartmula_colab_free.ipynb).

## Start

1. Open the notebook with the badge or link above.
2. In Colab select **Runtime → Change runtime type → T4 GPU** if T4 is offered. Free Colab does not guarantee a T4 or any particular GPU.
3. Run the first cell. Continue only if it reports CUDA and at least 8 GiB total VRAM.
4. Optionally set `USE_GOOGLE_DRIVE = True` in the configuration cell to persist the roughly 22 GB public model cache. Drive is not required.
5. Run cells in order through generation, `ffprobe`, post-processing, provenance, and download.
6. Download the MP3, WAV master, iOS M4A, and JSON manifest before the runtime is reclaimed.

Model downloads start only after the hardware gate. The first cell records a pass sentinel, and the initial download, recovery download, and generation cells each require that sentinel and recheck live CUDA/VRAM, so running later cells out of order fails before a model download. The default 60-second sample is intended as a smoke-quality draft; increase duration only after the end-to-end path succeeds and while monitoring Colab limits.

## Reproducibility contract

| Component | Pinned revision |
|---|---|
| `HeartMuLa/heartlib` | `3783bdb8441f2c298b1e64c8651173aac200361c` |
| `HeartMuLa/HeartMuLaGen` | `9906b2bcd4598772a32cad4aec0760170fe0d177` |
| `HeartMuLa/HeartMuLa-oss-3B-happy-new-year` | `41f6fc68490e11dc43fdabaa6b5767946408c903` |
| `HeartMuLa/HeartCodec-oss-20260123` | `f889dab0532cfa4bf459f2a3367eb6d346b8eeda` |

The notebook creates an isolated Python 3.10.18 environment and pins `uv==0.8.3`. `notebooks/heartmula_requirements_py310.lock` resolves all 110 Python packages, includes package SHA-256 hashes, and pins the CUDA 12.1 builds of PyTorch/Torchaudio `2.4.1` and Torchvision `0.19.1`. The lock is embedded into the standalone notebook and verified before installation. Heartlib is then installed from the pinned official source with dependency resolution and build isolation disabled, so runtime installation cannot silently select newer transitive packages.

Two compatibility fixes are guarded and fail closed if upstream text differs:

- both HeartCodec eager/lazy loads set `ignore_mismatched_sizes=True`, matching the checkpoint mismatch workaround documented in [heartlib issue #100](https://github.com/HeartMuLa/heartlib/issues/100);
- RoPE caches skipped during meta-device loading are rebuilt before inference cache setup.

Generation uses `lazy_load=True`, HeartMuLa bfloat16, HeartCodec float32, one CUDA device, and the tracked sample seed/config. The seed improves repeatability but does not promise bit-identical CUDA output.

## Sample inputs

- `notebooks/heartmula_samples/workout_tags.txt`
- `notebooks/heartmula_samples/instrumental_structure.txt`
- `notebooks/heartmula_samples/generation_config.json`

The sample contains only structural markers and generic production tags. It contains no copyrighted lyrics, named artist, or imitation request. HeartMuLa may weakly follow tags and may still synthesize vocal-like material; the output must be listened to and rejected if it contains intelligible or unsuitable content.

## Colab Free limitations and recovery

- GPU availability, model, runtime duration, RAM, disk, and reconnect behavior are not guaranteed. The notebook checks actual hardware and never promises T4.
- The three model repositories currently occupy about 22 GB in total. Without Drive, runtime storage is ephemeral.
- A disconnected runtime loses Python state. Reconnect with GPU, rerun hardware/config/setup/patch cells, then run the recovery cell. With Drive enabled, `hf download` resumes or reuses content-addressed snapshot files.
- Generation speed depends on the allocated GPU. Upstream reports inference around real-time factor 1.0, but free-tier load and post-processing can be slower.
- If the hardware gate fails, stop and request another free GPU runtime later; do not force CPU generation.

## Privacy and credentials

The checkpoints are public and ungated. No Hugging Face token, paid API, or other credential is required. The notebook disables Hugging Face telemetry and does not print environment variables or credentials. If Drive is enabled, Google handles its own interactive mount authorization and only the public model cache is stored under `MyDrive/AbsTrainer/heartmula-cache`. Inputs, generated audio, and the manifest stay under ephemeral `/content` until explicitly downloaded. Do not place private lyrics or user data into the sample cells.

## License evidence and release review

At the pinned revisions:

- heartlib declares Apache-2.0 in its repository `LICENSE`, README, and package metadata;
- all three Hugging Face model cards declare `license: apache-2.0` and are public/ungated.

Evidence URLs:

- https://github.com/HeartMuLa/heartlib/blob/3783bdb8441f2c298b1e64c8651173aac200361c/LICENSE
- https://huggingface.co/HeartMuLa/HeartMuLaGen/tree/9906b2bcd4598772a32cad4aec0760170fe0d177
- https://huggingface.co/HeartMuLa/HeartMuLa-oss-3B-happy-new-year/tree/41f6fc68490e11dc43fdabaa6b5767946408c903
- https://huggingface.co/HeartMuLa/HeartCodec-oss-20260123/tree/f889dab0532cfa4bf459f2a3367eb6d346b8eeda

Apache-2.0 source/model licensing is not a blanket representation that a particular generated recording is commercially clear. Before release, preserve the generated manifest and have a human review the exact output for recognizable lyrics, similarity to known recordings/artists, trademark/personality concerns, artifacts, and suitability. Record the review decision with the selected asset.

## Local music-pipeline handoff

The notebook outputs:

- `abs_trainer_workout.mp3` — generated source preview;
- `abs_trainer_workout_master.wav` — 48 kHz stereo PCM master;
- `abs_trainer_workout_ios.m4a` — 192 kbps AAC delivery candidate;
- `heartmula_generation_manifest.json` — pinned provenance, parameters, byte sizes, and SHA-256 hashes.

For local pipeline task `t_bfc83a35`, hand off the WAV master, M4A, and manifest together. Verify with:

```bash
ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,sample_rate,channels -of json abs_trainer_workout_ios.m4a
```

Do not add the asset to the iOS bundle until content/license review is recorded and the downstream owner confirms naming, loop points, loudness, and bundle-size requirements.

## Cleanup

Download outputs first. The final notebook cell deletes runtime files only when `CONFIRM_RUNTIME_CLEANUP=True`. A Drive cache is preserved unless `CONFIRM_DRIVE_CACHE_DELETE=True` is also set. Ending the Colab runtime normally erases `/content`, but it does not erase mounted Drive files.

## Repository validation

Run from the repository root:

```bash
python3 scripts/build_heartmula_notebook.py
python3 scripts/validate_heartmula_colab.py
python3 scripts/artifact_gate.py
git diff --check
```

Static validation checks notebook JSON/nbformat, compiles every Python code cell, rejects committed outputs/execution counts and banned secret/paid-API/imitation patterns, validates exact revision mappings, cell ordering, and all three hardware revalidation calls, verifies the embedded hashed lock against the tracked lock, compares the notebook byte-for-byte with a fresh deterministic build, and checks sample inputs. It cannot replace the manual Colab GPU smoke because this development server has no CUDA GPU.

## Manual Colab GPU smoke checklist

- [ ] First cell prints actual GPU name and VRAM and passes at `>= 8 GiB`.
- [ ] Python 3.10.18 venv installs the hash-verified lock and reports CUDA-enabled PyTorch.
- [ ] Pinned source checkout and guarded compatibility patches pass.
- [ ] Anonymous pinned model downloads complete or resume from Drive.
- [ ] HeartMuLa generation exits successfully with lazy loading and FP32 codec.
- [ ] MP3 exists and is non-empty; `ffprobe` reports playable audio metadata.
- [ ] WAV is PCM 48 kHz stereo and M4A is AAC 48 kHz stereo.
- [ ] All four artifacts download from Colab and manifest hashes match local files.
- [ ] Human listening/similarity/product review is recorded before release.
- [ ] Cleanup behavior is tested without deleting an unconfirmed Drive cache.
