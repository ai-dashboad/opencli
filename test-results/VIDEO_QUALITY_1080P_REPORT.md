# Video Quality 1080p Verification — iOS Simulator Test Report v1.0

## Test Environment
| Property | Value |
|----------|-------|
| Device | iPhone 16 Pro (Simulator) |
| UDID | BCCC538A-B4BB-45F4-8F80-9F9C44B9ED8B |
| iOS Version | 18.3 |
| Flutter | Debug mode via `flutter run` |
| Daemon | localhost:9876 (WS), localhost:9875 (Status) |
| FFmpeg | /opt/homebrew/bin/ffmpeg |
| Date | 2026-02-08 |
| Test Method | flutter-skill MCP + ffprobe verification |

## Summary

**3/3 tests PASSED** | **3 aspect ratios at 1080p** | **All faststart-enabled** | **All H.264 High/4.2**

## Quality Improvements Applied

| Setting | Before | After | Why |
|---------|--------|-------|-----|
| Resolution | 720p (720x1280, 720x720, 1280x720) | **1080p** (1080x1920, 1080x1080, 1920x1080) | Platform minimum requirements |
| CRF | 23 | **18** | Higher quality (lower = better) |
| Preset | fast | **medium** | Better compression efficiency |
| Profile | Baseline/Main | **High/4.2** | More efficient encoding features |
| faststart | No | **Yes** (`-movflags +faststart`) | Instant streaming playback |

## Test Results

| # | Platform | Aspect | Expected | Actual | Bitrate | Size | Duration | faststart | Status |
|---|----------|--------|----------|--------|---------|------|----------|-----------|--------|
| 1 | TikTok/Douyin | 9:16 | 1080x1920 | **1080x1920** | 1025 kbps | 643 KB | 5.0s | moov before mdat | **PASS** |
| 2 | Instagram | 1:1 | 1080x1080 | **1080x1080** | 997 kbps | 625 KB | 5.0s | moov before mdat | **PASS** |
| 3 | YouTube | 16:9 | 1920x1080 | **1920x1080** | 884 kbps | 555 KB | 5.0s | moov before mdat | **PASS** |

## Encoding Details (all 3 videos)

| Property | Value |
|----------|-------|
| Codec | H.264 (libx264) |
| Profile | High |
| Level | 4.2 |
| CRF | 18 |
| Preset | medium |
| Pixel format | yuv420p |
| faststart | Yes (`-movflags +faststart`) |
| moov atom | Before mdat (verified) |

## Platform Quality Requirements vs Actual

| Platform | Min Resolution | Our Output | Min Bitrate | Our Bitrate | Status |
|----------|---------------|------------|-------------|-------------|--------|
| TikTok | 720x1280 | 1080x1920 | 516 kbps | 1025 kbps | **Exceeds** |
| Instagram | 600x600 | 1080x1080 | 500 kbps | 997 kbps | **Exceeds** |
| YouTube | 1280x720 | 1920x1080 | 800 kbps | 884 kbps | **Meets** |

## Flutter UI Verification

All 3 videos were:
1. Generated via the daemon's FFmpeg pipeline
2. Sent to the Flutter app via WebSocket (`task_update` with `status: completed`)
3. Displayed in the Photo Animation card with video player
4. Video playback confirmed working on iOS Simulator
5. Save and Share buttons visible on each card

## Video Files

| File | Platform | Resolution |
|------|----------|------------|
| `output_1770539734690.mp4` | TikTok 9:16 | 1080x1920 |
| `output_1770539796566.mp4` | Instagram 1:1 | 1080x1080 |
| `output_1770539825839.mp4` | YouTube 16:9 | 1920x1080 |

## Screenshots

| File | Description |
|------|-------------|
| `quality_1080p_tiktok.png` | TikTok 1080p video card with playback |
| `quality_1080p_all_results.png` | Multiple 1080p video cards in chat |

## Bug Fixes During Testing

### 1. Capability Registry Remote Lookup Timeout
**Symptom**: Every domain task took 30+ seconds due to DNS lookup to non-existent `capabilities.opencli.io`
**Root cause**: `_capabilityRegistry.get(taskType)` called remote `_loader.get()` before checking local executors
**Fix**: Added `getLocal()` method to `capability_registry.dart`, changed `mobile_task_handler.dart` to check direct executors first
**Files**: `daemon/lib/capabilities/capability_registry.dart`, `daemon/lib/mobile/mobile_task_handler.dart`

### 2. Low Resolution Output (720p)
**Symptom**: All videos generated at 720p (720x1280, 720x720, 1280x720)
**Root cause**: `_resolutionForAspect()` mapped to 720p resolutions
**Fix**: Updated to 1080p: 9:16→1080x1920, 1:1→1080x1080, 16:9→1920x1080
**File**: `daemon/lib/domains/media_creation/media_creation_domain.dart`

### 3. Low Quality Encoding Settings
**Symptom**: Videos had low bitrate (250-540 kbps), no faststart, basic profile
**Root cause**: CRF 23, preset fast, no profile/level, no movflags
**Fix**: CRF 18, preset medium, profile high, level 4.2, +faststart
**File**: `daemon/lib/domains/media_creation/media_creation_domain.dart` (both `_animatePhoto` and `_createSlideshow`)

## Conclusion

All 3 aspect ratios now produce **1080p videos** that meet or exceed social media platform requirements:
- **TikTok/Douyin**: 1080x1920 at 1025 kbps (exceeds 720x1280 minimum)
- **Instagram**: 1080x1080 at 997 kbps (exceeds 600x600 minimum)
- **YouTube**: 1920x1080 at 884 kbps (meets 1280x720 minimum)

All videos use H.264 High Profile Level 4.2 with faststart for instant streaming playback. Video generation and playback verified working end-to-end through the Flutter iOS app.
