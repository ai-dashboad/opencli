# App Store Submission - Quick Start Guide

**Date**: 2026-01-31
**App**: OpenCLI Mobile v0.1.1 (Build 5)
**Status**: 🟢 Ready to Submit

---

## 🎯 Current Status

### ✅ Completed (Ready)

1. **Flutter App Built**
   - ✅ Android APK: 43MB (signed)
   - ✅ Android AAB: 38MB (signed, ready for Play Store)
   - ✅ iOS configured (needs Xcode build for IPA)

2. **App Configuration**
   - ✅ Package: com.opencli.mobile
   - ✅ Version: 0.1.1+5
   - ✅ Android signing configured
   - ✅ iOS Team ID: G9VG22HGJG

3. **Documentation**
   - ✅ Complete app descriptions (English & Chinese)
   - ✅ Keywords and categories defined
   - ✅ Version release notes prepared
   - ✅ Privacy policy content ready

4. **Build Files**
   ```
   ✅ opencli_app/build/app/outputs/bundle/release/app-release.aab
   ✅ opencli_app/build/app/outputs/flutter-apk/app-release.apk
   ```

### 🔨 Needs Creation (30-60 min)

1. **Visual Assets**
   - [ ] App Icon 512x512 (Android)
   - [ ] App Icon 1024x1024 (iOS)
   - [ ] Feature Graphic 1024x500 (Android)
   - [ ] Screenshots (2-8 for Android, 3-10 for iOS)

2. **Account Setup**
   - [ ] Google Play Developer account ($25 one-time)
   - [ ] Apple Developer Program ($99/year)

3. **Website Assets**
   - [ ] Privacy Policy at https://opencli.ai/privacy

---

## 🚀 Step-by-Step Submission

### Phase 1: Create Visual Assets (30-60 minutes)

#### 1.1 Create App Icons

**Quickest Method: Icon Kitchen**
```bash
# 1. Design a simple 1024x1024 PNG icon
#    Suggestion: Blue background with ">_" terminal symbol

# 2. Visit https://icon.kitchen
# 3. Upload your 1024x1024 PNG
# 4. Download:
#    - Android: 512x512 → save as icon_512.png
#    - iOS: 1024x1024 → save as icon_1024.png

# 5. Save to:
cp icon_512.png opencli_app/app_store_materials/
cp icon_1024.png opencli_app/app_store_materials/
```

See detailed guide: `opencli_app/app_store_materials/ICON_CREATION_GUIDE.md`

#### 1.2 Generate Screenshots

**Automated Method:**
```bash
cd opencli_app
./scripts/generate_screenshots.sh

# Follow prompts to:
# 1. Launch app on simulator/emulator
# 2. Navigate to Tasks, Status, Settings pages
# 3. Take screenshots (Cmd+S or Camera icon)
# 4. Save to app_store_materials/screenshots/
```

**Manual Method:**
```bash
# Android (1080x1920):
flutter run --release  # On Android emulator
# Take screenshots: Click camera icon
# Move from Desktop to opencli_app/app_store_materials/screenshots/android/

# iOS (1290x2796, 1242x2688, 1242x2208):
open -a Simulator
flutter run --release  # On iPhone 14 Pro Max
# Take screenshots: Cmd+S
# Move from Desktop to opencli_app/app_store_materials/screenshots/ios/
```

Required screenshots:
- Tasks page
- Status page
- Settings page
- Dark mode example (optional but recommended)

#### 1.3 Create Feature Graphic (Android Only)

```bash
# Use Canva or Figma
# Size: 1024 x 500 pixels
# Content:
#   - App icon (left)
#   - "OpenCLI" (large text)
#   - "AI Task Orchestration on Mobile" (subtitle)
#   - Blue gradient background

# Save as: opencli_app/app_store_materials/feature_graphic.png
```

---

### Phase 2: Google Play Store Submission (1-2 hours)

#### 2.1 Register Developer Account

```bash
# 1. Visit: https://play.google.com/console
# 2. Sign in with Google account
# 3. Pay $25 one-time registration fee
# 4. Accept Developer Distribution Agreement
# 5. Complete account details
```

#### 2.2 Create Application

Follow detailed guide: `docs/GOOGLE_PLAY_SUBMISSION_GUIDE.md`

**Quick Steps:**
1. Click "Create app"
2. Fill in:
   - Name: OpenCLI
   - Language: English (United States) or 中文(简体)
   - App type: App
   - Free/Paid: Free
3. Complete Store Listing:
   - Upload icon_512.png
   - Upload feature_graphic.png
   - Upload screenshots (2-8 images)
   - Copy description from `app_store_materials/APP_DESCRIPTION.md`
   - Privacy policy: https://opencli.ai/privacy
4. Complete App Content:
   - Data safety: No data collection
   - Ads: No
   - Target audience: 18+
   - Content rating: Everyone
5. Upload AAB:
   ```bash
   # File: opencli_app/build/app/outputs/bundle/release/app-release.aab
   ```
6. Review and submit

**Estimated Review Time**: 1-3 days

---

### Phase 3: Apple App Store Submission (2-3 hours)

#### 3.1 Register Developer Account

```bash
# 1. Visit: https://developer.apple.com/programs/
# 2. Click "Enroll"
# 3. Pay $99/year
# 4. Wait for approval (1-2 days)
```

#### 3.2 Build iOS IPA

```bash
cd opencli_app/ios
open Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device" as target
# 2. Product → Archive
# 3. Wait for build to complete
# 4. Window → Organizer opens automatically
# 5. Select archive → Distribute App
# 6. Choose "App Store Connect" → Upload
# 7. Wait for processing (5-30 minutes)
```

#### 3.3 Create App in App Store Connect

Follow detailed guide: `docs/APP_STORE_SUBMISSION_GUIDE.md`

**Quick Steps:**
1. Visit: https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: OpenCLI
   - Language: English or 简体中文
   - Bundle ID: com.opencli.mobile
   - SKU: opencli-mobile-001
4. Add App Information:
   - Upload icon_1024.png
   - Upload screenshots for 6.7", 6.5", 5.5" displays
   - Copy description from `app_store_materials/APP_DESCRIPTION.md`
   - Privacy policy: https://opencli.ai/privacy
5. Select Build:
   - Wait for build processing
   - Choose uploaded build
6. Complete App Review Information:
   - Contact info
   - Demo account (if needed)
   - Notes for reviewer
7. Submit for review

**Estimated Review Time**: 24-48 hours

---

## 📋 Pre-Submission Checklist

### Files Ready
- [ ] app-release.aab (38MB) - for Google Play
- [ ] icon_512.png - for Google Play
- [ ] icon_1024.png - for App Store
- [ ] feature_graphic.png - for Google Play
- [ ] Screenshots (Android: 2-8, iOS: 3-10 per size)
- [ ] iOS IPA built via Xcode

### Accounts & Access
- [ ] Google Play Developer account registered
- [ ] Apple Developer Program enrolled
- [ ] Privacy policy published at https://opencli.ai/privacy
- [ ] Support email accessible: support@opencli.ai

### Information Ready
- [ ] App description (copied from APP_DESCRIPTION.md)
- [ ] Release notes (copied from APP_DESCRIPTION.md)
- [ ] Keywords
- [ ] Contact information

---

## 🎯 Submission Order (Recommended)

### Option 1: Start with Google Play (Easier)

1. **Create visual assets** (30-60 min)
2. **Register Google Play account** (15 min + $25)
3. **Submit to Google Play** (1-2 hours)
4. **Wait for approval** (1-3 days)
5. **Register Apple Developer** (15 min + $99, 1-2 day approval)
6. **Build iOS IPA** (30 min)
7. **Submit to App Store** (2-3 hours)
8. **Wait for approval** (1-2 days)

**Total Time**: 5-7 days from start to both stores live

### Option 2: Parallel Submission (Faster)

1. **Create visual assets** (30-60 min)
2. **Register both accounts simultaneously**
   - Google Play: $25 (instant)
   - Apple Developer: $99 (1-2 day approval)
3. **Submit to Google Play immediately** (1-2 hours)
4. **Wait for Apple approval, then submit** (2-3 hours)

**Total Time**: 3-4 days from start to both stores live

---

## 🔄 Quick Commands Reference

### Generate Screenshots
```bash
cd opencli_app
./scripts/generate_screenshots.sh
```

### Rebuild App (if needed)
```bash
cd opencli_app

# Android
flutter clean
flutter pub get
flutter build appbundle --release  # For Play Store
flutter build apk --release         # For direct distribution

# iOS (macOS only)
flutter build ios --release --no-codesign
# Then open Xcode and Archive
```

### Check Build Files
```bash
ls -lh opencli_app/build/app/outputs/bundle/release/app-release.aab
ls -lh opencli_app/build/app/outputs/flutter-apk/app-release.apk
```

### Verify App Size
```bash
# AAB (Play Store)
du -h opencli_app/build/app/outputs/bundle/release/app-release.aab
# Should be ~38MB

# APK (Direct install)
du -h opencli_app/build/app/outputs/flutter-apk/app-release.apk
# Should be ~43MB
```

---

## 📞 Support & Resources

### Documentation
- **Google Play Guide**: `docs/GOOGLE_PLAY_SUBMISSION_GUIDE.md`
- **App Store Guide**: `docs/APP_STORE_SUBMISSION_GUIDE.md`
- **Complete Checklist**: `docs/APP_STORE_SUBMISSION_CHECKLIST.md`
- **Icon Creation**: `opencli_app/app_store_materials/ICON_CREATION_GUIDE.md`
- **App Description**: `opencli_app/app_store_materials/APP_DESCRIPTION.md`

### Help Resources
- Google Play Help: https://support.google.com/googleplay/android-developer
- App Store Connect Help: https://help.apple.com/app-store-connect
- Flutter Docs: https://docs.flutter.dev

### Common Issues

**Q: App Store submission rejected?**
A: Check Resolution Center in App Store Connect, address feedback, resubmit

**Q: Google Play submission rejected?**
A: Review rejection reason in Play Console, update and resubmit

**Q: Screenshots wrong size?**
A: Use the exact pixel dimensions specified in guides, regenerate if needed

**Q: Can't build iOS IPA?**
A: Requires macOS and Xcode, ensure certificates and provisioning profiles are configured

---

## 🎉 Success Criteria

### Google Play Launch
- ✅ App visible in Play Store search
- ✅ Can be installed on Android devices
- ✅ Store listing displays correctly
- ✅ No crashes on launch

### App Store Launch
- ✅ App shows "Ready for Sale" status
- ✅ Visible in App Store search
- ✅ Can be downloaded and installed
- ✅ All metadata displays correctly

---

## ⏱️ Estimated Timeline

| Task | Duration | Cost |
|------|----------|------|
| Create visual assets | 30-60 min | Free |
| Register Google Play | 15 min | $25 |
| Submit to Google Play | 1-2 hours | Free |
| Google Play review | 1-3 days | Free |
| Register Apple Developer | 15 min | $99/year |
| Apple approval | 1-2 days | Free |
| Build & submit to App Store | 2-3 hours | Free |
| App Store review | 1-2 days | Free |
| **Total** | **5-7 days** | **$124** |

---

## 🚀 Ready to Start?

### Immediate Next Steps (Choose One)

**If you have 1 hour now:**
```bash
# 1. Create app icon using Icon Kitchen or Canva
# 2. Generate screenshots
cd opencli_app
./scripts/generate_screenshots.sh
# 3. Review generated assets
# 4. Then follow Google Play guide to submit
```

**If you have 3-4 hours now:**
```bash
# 1. Create all visual assets (icon + screenshots)
# 2. Register Google Play Developer account
# 3. Complete Google Play submission
# 4. Register Apple Developer (start approval process)
```

**If you want to prepare everything first:**
```bash
# 1. Read all guides thoroughly
# 2. Create visual assets
# 3. Set up privacy policy at opencli.ai/privacy
# 4. Register both developer accounts
# 5. Then submit to both stores in one session
```

---

**Status**: 🟢 Everything is prepared and ready
**Next Step**: Create visual assets → Submit to stores
**Support**: Follow detailed guides in `docs/` directory

**Let's get OpenCLI Mobile published! 🚀**
