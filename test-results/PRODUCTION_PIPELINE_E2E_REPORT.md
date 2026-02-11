# Production Local Anime Pipeline E2E Test Report v1.0

**Date**: 2026-02-10
**Tester**: Claude (automated)
**Branch**: feat/web-ui-complete
**Commit**: 0102eab

---

## Summary

| Category | Tests | Pass | Fail | Notes |
|----------|-------|------|------|-------|
| Episode API CRUD | 6 | 6 | 0 | Full lifecycle |
| LoRA API CRUD | 6 | 6 | 0 | Create/read/update/delete |
| Recipe API CRUD | 6 | 6 | 0 | Create/read/update/delete |
| Local Model System | 2 | 2 | 0 | Env + model list |
| Episode Generation | 4 | 3 | 1 | 1 bug found & fixed |
| Web UI Pages | 3 | 3 | 0 | List + detail + generate tab |
| **Total** | **27** | **26** | **1** | **1 critical bug fixed** |

---

## Critical Bug Found & Fixed

### BUG: Pipe Deadlock in Python Subprocess Communication

**Severity**: CRITICAL (blocked ALL local inference)
**Root Cause**: `_runInferAction()` in `local_model_manager.dart` read stdout and stderr **sequentially** with `await for`. Python's tqdm/diffusers progress bars write heavily to stderr. When stderr pipe buffer filled (64KB), the Python process blocked on write → deadlock.
**Evidence**: `lsof` showed stderr pipe at 65536 bytes (full 64KB buffer), Python process at 0% CPU
**Fix**: Changed to concurrent reading via `.listen().asFuture()` + `Future.wait()` for both streams
**File**: `daemon/lib/domains/media_creation/local_model_manager.dart:786-804`

---

## Test Results Detail

### 1. Episode API CRUD (6/6 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | `GET /api/v1/episodes` — list all | PASS — returns 2 existing episodes |
| 2 | `POST /api/v1/episodes/from-script` — create from JSON | PASS — returns 201 with full script |
| 3 | `GET /api/v1/episodes/:id` — get by ID | PASS — returns episode with status=draft |
| 4 | `PUT /api/v1/episodes/:id` — update script | PASS — title updated |
| 5 | `DELETE /api/v1/episodes/:id` — delete | PASS — returns success |
| 6 | `GET /api/v1/episodes/:id` after delete | PASS — returns 404 |

### 2. LoRA API CRUD (6/6 PASS)

| # | Test | Result |
|---|------|--------|
| 7 | `GET /api/v1/loras` — list (empty) | PASS |
| 8 | `POST /api/v1/loras` — create | PASS — 201 with ID |
| 9 | `GET /api/v1/loras/:id` — get | PASS — all fields correct |
| 10 | `PUT /api/v1/loras/:id` — update | PASS — name+weight updated |
| 11 | `DELETE /api/v1/loras/:id` — delete | PASS |
| 12 | `GET /api/v1/loras/:id` after delete | PASS — 404 |

### 3. Recipe API CRUD (6/6 PASS)

| # | Test | Result |
|---|------|--------|
| 13 | `GET /api/v1/recipes` — list (empty) | PASS |
| 14 | `POST /api/v1/recipes` — create | PASS — all fields stored |
| 15 | `GET /api/v1/recipes/:id` — get | PASS — includes controlnet_scale, ip_adapter_scale |
| 16 | `PUT /api/v1/recipes/:id` — update | PASS — quality+name updated |
| 17 | `DELETE /api/v1/recipes/:id` — delete | PASS |
| 18 | `GET /api/v1/recipes/:id` after delete | PASS — 404 |

### 4. Local Model System (2/2 PASS)

| # | Test | Result |
|---|------|--------|
| 19 | `GET /api/v1/local-models/environment` | PASS — Python 3.12, PyTorch 2.10, MPS device |
| 20 | `GET /api/v1/local-models` — list | PASS — 12 models (3 ControlNet + IP-Adapter added) |

**Downloaded models**: Animagine XL (6.5GB), Waifu Diffusion (2GB)
**New models registered**: controlnet_lineart_anime, controlnet_openpose, controlnet_depth, ip_adapter_face, animatediff_v3, realesrgan

### 5. Episode Generation (3/4 — 1 bug found & fixed)

| # | Test | Result |
|---|------|--------|
| 21 | `POST /api/v1/episodes/:id/generate` — trigger | PASS |
| 22 | `GET /api/v1/episodes/:id/progress` — poll | PASS — returns status+progress |
| 23 | `POST /api/v1/episodes/:id/cancel` — cancel | PASS — returns success |
| 24 | Full generation completion | PARTIAL — pipe deadlock fixed, SDXL@1024x1024 very slow (~30+ min) |

**Direct Python inference test**: Animagine XL at 512x512 (10 steps) completes in ~3 min. At 1024x1024 (28 steps), MPS inference takes ~25s/step = ~12 min generation + ~5 min model load.

**Previously completed episodes**: ep_pipeline_test and ep_final_test both completed successfully with full 10-phase pipeline (keyframes + video clips + TTS + subtitles + audio mix + scene assembly + final concat).

**Output specs** (ep_pipeline_test):
- Final video: 1920x1080, H.264, 25fps, AAC audio, 11MB
- 2 scenes, 7 shots total
- Assets: 4+3 keyframes, 4+3 clips, 2 subtitle files, 2 voice files

### 6. Web UI (3/3 PASS)

| # | Test | Result |
|---|------|--------|
| 25 | `/episodes` list page | PASS — shows 3 episodes with status badges |
| 26 | `/episodes/:id` detail page | PASS — Scenes/Characters/Generate tabs |
| 27 | Generate tab controls | PASS — all local pipeline controls render correctly |

**Generate tab verified controls**:
- Image Model dropdown (Animagine XL / Waifu Diffusion)
- Video Model dropdown (AnimateDiff V3 + MotionLoRA / AnimateDiff V1 / Ken Burns)
- Quality Tier dropdown (Draft / Standard / Cinematic)
- ControlNet toggle + type selector + conditioning scale slider
- IP-Adapter Face Scale slider (0.2-0.9)
- Color Grade dropdown (6 LUT presets)
- Export Platform dropdown (Default / YouTube / TikTok / E-commerce)
- Generation Progress display (3% shown during active generation)

### 7. Asset Browser API (verified via completed episode)

| # | Test | Result |
|---|------|--------|
| — | `GET /api/v1/episodes/:id/assets` | PASS — returns 23 assets with name/type/size/path |

---

## Code Quality

| Check | Result |
|-------|--------|
| `dart analyze lib/` | 0 errors (89 pre-existing warnings) |
| TypeScript `tsc --noEmit` | 0 new errors (7 pre-existing pipeline type warnings) |

---

## Performance Notes

- **Animagine XL (SDXL)** on M1 Max MPS: ~25s/step at 1024x1024, ~10s/step at 512x512
- **Waifu Diffusion (SD1.5)** on M1 Max MPS: ~2s/step at 512x512
- **Model load time**: ~40-60s for first load (diffusers imports + model weights)
- **Peak memory**: 19.8GB physical footprint during SDXL inference (fits in 32GB)
- **Recommendation**: Use 512x512 for draft, 768x768 for standard, 1024x1024 for cinematic only

---

## Files Changed

- `daemon/lib/domains/media_creation/local_model_manager.dart` — **pipe deadlock fix** (concurrent stdout/stderr reading)
- 35 files in initial commit (8,480 lines added)
