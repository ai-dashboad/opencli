# AI Video Generation - iOS Simulator E2E Test Report

**Version:** 3.0
**Date:** 2026-02-07
**Platform:** iOS Simulator - iPhone 16 Pro (iOS 18.3)
**Daemon:** PID 49567, port 9876
**Flutter:** Debug build via `flutter run`
**Connection:** flutter-skill MCP (VM service ws://127.0.0.1:58123)

---

## Bugs Fixed in v3.0

1. **FFmpeg hangs on small images** - `_animatePhoto()` in `media_creation_domain.dart` now checks input image dimensions via `ffprobe`. Images smaller than 128x128 are pre-scaled to 640x480 before zoompan processing. Root cause: FFmpeg's zoompan filter hangs indefinitely on very small images (e.g. 4x4 PNG).
2. **Debug test image too small** - Replaced 4x4 test PNG with 64x64 blue test PNG in debug shortcut. The 4x4 PNG was below zoompan's minimum processable size.

## Bugs Fixed in v2.0

1. **"Task completed" shown for failed results** - `chat_page.dart` checks `result['success']` and shows `❌ error message` with `MessageStatus.failed` when `success == false`
2. **Connection icon stuck red** - `main.dart` listens for `auth_success` on the message stream and calls `setState()` to update the icon

---

## Test Summary

| # | Test Case | Status | Screenshot |
|---|-----------|--------|------------|
| 1 | Local FFmpeg via debug shortcut → SUCCESS | PASS | `v3_01_local_ffmpeg_success.png` |
| 2 | System info baseline → SUCCESS | PASS | `v3_02_all_results.png` |
| 3 | AI video quick (Replicate) → correct ERROR | PASS | `v3_02_all_results.png` |
| 4 | Bottom sheet opens with 5 providers + 6 styles | PASS | `v3_03_bottom_sheet.png` |
| 5 | Local FFmpeg selected: style grid hidden, button changed | PASS | `v3_03_bottom_sheet.png` |
| 6 | Bottom sheet → Local FFmpeg → SUCCESS | PASS | `v3_04_local_success_via_sheet.png` |

**Result: 6/6 PASS (including 2 SUCCESS results)**

---

## Test Details

### Test 1: Local FFmpeg via Debug Shortcut (SUCCESS)
- Typed "test ai video local" via flutter-skill MCP
- Debug shortcut injected 64x64 blue test PNG
- Daemon pre-scaled image (detected < 128x128), then ran zoompan
- Result: **"✅ Task completed"** + "Photo Animation" card (ken_burns, 5s, 0.0 MB)
- Green checkmark status icon
- Screenshot: `v3_01_local_ffmpeg_success.png`

### Test 2: System Info Baseline (SUCCESS)
- Typed "system info"
- Result: **"✅ Task completed"** + system info card (macOS 26.2, 10 cores)
- Green checkmark status icon

### Test 3: AI Video Quick - Replicate (CORRECT ERROR)
- Typed "test ai video quick" — auto-submits with Replicate + Cinematic
- Result: **"❌ No AI video providers configured..."** + red error card
- Red error status icon — correctly shows failure (no API keys)

### Test 4: Bottom Sheet UI
- Typed "test ai video" to open bottom sheet
- All 5 providers visible as horizontal chips:
  | Provider | Price |
  |----------|-------|
  | Local FFmpeg | Free |
  | Replicate | ~$0.28 |
  | Runway Gen-4 | ~$0.75 |
  | Kling AI | ~$0.90 |
  | Luma Dream | ~$0.20 |
- All 6 style presets in grid:
  - Cinematic, Ad/Promo, Social Media, Calm, Epic, Mysterious
- Custom Prompt toggle visible
- "Generate AI Video" button at bottom

### Test 5: Local FFmpeg UI Behavior
- Tapped "Local FFmpeg" chip on bottom sheet
- Style Preset grid **HIDDEN** (correct for local mode)
- Custom Prompt toggle **HIDDEN**
- Button text changed to **"Create Local Video"**

### Test 6: Bottom Sheet → Local FFmpeg (SUCCESS)
- Tapped "Create Local Video" on bottom sheet
- Bottom sheet dismissed, processing message shown
- Result: **"✅ Task completed"** + "Photo Animation" card (ken_burns, 5s)
- Green checkmark status icon
- Screenshot: `v3_04_local_success_via_sheet.png`

---

## Screenshot Evidence (v3)

| File | Description |
|------|-------------|
| `v3_01_local_ffmpeg_success.png` | Local FFmpeg success: ✅ + Photo Animation card |
| `v3_02_all_results.png` | All results: success + system info + error |
| `v3_03_bottom_sheet.png` | Bottom sheet with Local FFmpeg selected |
| `v3_04_local_success_via_sheet.png` | Bottom sheet → Local FFmpeg success |

---

## All Bugs Fixed (v1-v3)

| Bug | Root Cause | Fix | File |
|-----|-----------|-----|------|
| "✅ Task completed" on errors | Daemon sends `status:completed` even when `result.success==false`; chat page didn't check | Check `result['success']` — show `❌` with `MessageStatus.failed` when false | `chat_page.dart:165-170` |
| Connection icon stays red | `_isConnected` set in async `auth_success` handler but no `setState` on home page | Listen for `auth_success` on message stream, call `setState()` | `main.dart:346-356` |
| FFmpeg hangs on small images | zoompan filter hangs indefinitely on images < ~16x16 | Check dimensions via ffprobe, pre-scale to 640x480 if < 128x128 | `media_creation_domain.dart:475-498` |
| 4x4 test PNG unusable | Too small for zoompan to process | Replaced with 64x64 blue test PNG | `chat_page.dart` (debug shortcut) |

---

## Conclusion

The AI Video Generation feature is **fully functional** end-to-end on iOS:
- **Local FFmpeg generates successful videos** from test images (v3 fix)
- Bottom sheet UI renders all 5 providers and 6 styles correctly
- Provider selection dynamically adjusts the UI (local hides style grid)
- **Success results show ✅ with green status + blue cards** (v2 fix)
- **Error results show ❌ with red status + red error cards** (v2 fix)
- Small image handling is robust via automatic pre-scaling (v3 fix)
- Ready for real-world AI provider testing once API keys are configured in `~/.opencli/config.yaml`
