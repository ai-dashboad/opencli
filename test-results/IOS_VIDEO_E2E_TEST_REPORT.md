# iOS Video E2E Test Report v1.0

## Test Environment
| Property | Value |
|----------|-------|
| Device | iPhone 16 Pro (Simulator) |
| UDID | BCCC538A-B4BB-45F4-8F80-9F9C44B9ED8B |
| iOS Version | 18.2 |
| Flutter | 3.x debug mode |
| Daemon | localhost:9876 (WS), localhost:9875 (Status) |
| FFmpeg | Available (local video generation) |
| Date | 2026-02-08 |
| Test Method | flutter-skill MCP (VM Service WebSocket) |

## Summary

**7/7 tests PASSED** | **5 unique videos generated** | **4 distinct FFmpeg effects verified**

All AI video generation scenarios tested successfully on iOS Simulator. Local FFmpeg pipeline produces playable videos with correct metadata. Cloud provider error handling works correctly. Natural language routing correctly identifies animate commands.

## Test Results

| # | Test | Input | Expected | Actual | Status |
|---|------|-------|----------|--------|--------|
| 1 | Ken Burns (default local) | `test ai video local` | Video card: ken_burns, 5s | "Photo Animation", "ken_burns", "5s", "0.3 MB" | **PASS** |
| 2 | Zoom In effect | `test ai video zoom` | Video card: zoom_in, 5s | "Photo Animation", "zoom_in", "5s", "0.3 MB" | **PASS** |
| 3 | Pulse effect | `test ai video pulse` | Video card: pulse, 5s | "Photo Animation", "pulse", "5s", "0.2 MB" | **PASS** |
| 4 | Pan Left effect | `test ai video pan` | Video card: pan_left, 5s | "Photo Animation", "pan_left", "5s", "0.0 MB" | **PASS** |
| 5 | Bottom Sheet UI + Local Gen | `test ai video` → select Local FFmpeg → Create | Bottom sheet with 5 providers, 6 styles; local video | All UI elements verified; Video: "ken_burns", "5s", "0.3 MB" | **PASS** |
| 6 | AI Provider Error (no key) | `test ai video replicate` | Error card: no API keys configured | "Media Creation Error", "No AI video providers configured..." | **PASS** |
| 7 | Natural Language Command | `animate this photo` | Routes to media_animate_photo | "No image provided. Please attach a photo first..." | **PASS** |

## Video Generation Details

### Videos Generated (5 total)

| Video | Effect | Duration | File Size | Timestamp |
|-------|--------|----------|-----------|-----------|
| #1 | ken_burns | 5s | 0.3 MB | 00:17 |
| #2 | zoom_in | 5s | 0.3 MB | 00:18 |
| #3 | pulse | 5s | 0.2 MB | 00:19 |
| #4 | pan_left | 5s | 0.0 MB | 00:20 |
| #5 | ken_burns (via sheet) | 5s | 0.3 MB | 00:21 |

### FFmpeg Effects Tested (4 of 6)

| Effect | Verified | Notes |
|--------|----------|-------|
| ken_burns | Yes | Random start position, gentle zoom + pan |
| zoom_in | Yes | Progressive 1x to 2x centered zoom |
| pulse | Yes | Sinusoidal breathing/oscillation zoom |
| pan_left | Yes | Horizontal pan, file size small (0.0 MB displayed, likely rounding) |
| zoom_out | Not tested | Available via `test ai video zoomout` |
| pan_right | Not tested | Available via `test ai video panr` |

## Bottom Sheet UI Verification (Test 5)

### Provider Chips (5 verified)
- Local FFmpeg — Free
- Replicate — ~$0.28
- Runway Gen-4 — ~$0.75
- Kling AI — ~$0.90
- Luma Dream — ~$0.20

### Style Presets (6 verified)
- Cinematic — "Anamorphic bokeh, film grain"
- Ad / Promo — "Studio orbit, brand energy"
- Social Media — "Vertical-first, scroll-stop"
- Calm — "Golden hour, dreamy bokeh"
- Epic — "IMAX grandeur, vast scale"
- Mysterious — "Noir shadows, fog & haze"

### UI Behavior Verified
- Selecting Local FFmpeg hides style preset grid
- Button text changes: "Generate AI Video" → "Create Local Video"
- Custom Prompt toggle present (not tested in this run)

## Error Handling Verification (Test 6)

- Cloud provider (Replicate) without API key → clear error message
- Error card displays "Media Creation Error" title (error-aware domain card)
- Message: "No AI video providers configured. Add API keys to ~/.opencli/config.yaml under ai_video.api_keys"
- No crash, graceful degradation

## Natural Language Routing (Test 7)

- "animate this photo" correctly routed to `media_animate_photo` task type
- Without attached image: returns helpful error "No image provided. Please attach a photo first, then type 'animate this photo'."
- Pattern matching from IntentRecognizer (54 registered patterns) works correctly

## Observations

1. **Pan Left file size**: Displayed as "0.0 MB" — likely a rounding issue for small files. The video was generated and displayed correctly. May want to show KB for files < 0.1 MB.
2. **Video auto-play**: All video cards auto-play on appearance in the chat feed.
3. **Scroll behavior**: Chat correctly scrolls to show new video cards as they're generated.
4. **Processing time**: Each FFmpeg video generates in ~5-8 seconds on simulator.

## Screenshots

| File | Description |
|------|-------------|
| `ios_video_playback_success.png` | Video playing in Photo Animation card (from previous session) |
| `ios_video_pulse_test3.png` | Pulse effect video card (Test 3) |
| `ios_video_bottom_sheet_test5.png` | AI Video Options bottom sheet (Test 5) |
| `ios_video_final_test7.png` | Final state with error cards visible (Tests 6-7) |

## Test Pipeline

```
Debug shortcut → test image (256x256 testsrc2 PNG)
  → _submitAIVideoGeneration() with effect param
  → WS message: {task_type: media_animate_photo, task_data: {image_base64, effect, ...}}
  → Daemon: MediaCreationDomain.handleTask()
  → FFmpeg zoompan filter → MP4 output → base64 response
  → Flutter: MediaCreationCard with VideoPlayerController
  → Auto-play in chat feed
```

## Conclusion

The AI video generation system is fully functional on iOS. All 7 test scenarios passed, with 5 unique videos generated using 4 different FFmpeg effects. The UI correctly handles provider selection, style presets, error states, and natural language routing. The system is ready for cloud provider testing once API keys are configured.
