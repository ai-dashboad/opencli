# OpenCLI iOS/Android Publishing Plan

## Current Situation Analysis

Based on the OpenCLI project structure, the following components exist:
- **CLI Tool** (Rust) - Desktop command-line interface
- **Daemon** (Dart) - Backend service
- **VSCode Extension** - IDE plugin (desktop only)
- **npm Package** - Node.js distribution
- **Web UI** - Web interface

**Finding**: Currently NO mobile applications exist in the OpenCLI project.

---

## Recommendation: Which Components Need Mobile Publishing?

### Option 1: Create Flutter Mobile App Wrapper (Recommended)

Create a Flutter app (`opencli-mobile/`) that provides:
- Mobile interface to interact with OpenCLI daemon
- Task submission and monitoring
- Settings and configuration
- Real-time status updates

**Benefits**:
- Single codebase for both iOS and Android
- Reuse existing Dart/Flutter skills
- Can communicate with local daemon or remote API

### Option 2: Web UI Mobile Optimization (Alternative)

Optimize the existing `web-ui/` component for mobile browsers:
- Responsive design for mobile screens
- PWA (Progressive Web App) support
- No app store distribution needed

**Benefits**:
- No new codebase
- Works on all mobile browsers
- Easier deployment

---

## Publishing Approach (If Creating Flutter App)

### Reference: dtok-app Credentials

Based on `/Users/cw/development/dtok-app`, you have:
- Android: `keystore.properties` for signing
- iOS: Provisioning profiles and certificates
- CI/CD automation experience

### Proposed Workflow Structure

```yaml
# .github/workflows/publish-mobile.yml
name: Publish Mobile Apps

on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - name: Build Android APK
        working-directory: opencli-mobile
        run: flutter build apk --release
      - name: Build Android App Bundle
        run: flutter build appbundle --release
      - name: Sign APK
        uses: r0adkll/sign-android-release@v1
        with:
          releaseDirectory: build/app/outputs/bundle/release
          signingKeyBase64: ${{ secrets.ANDROID_SIGNING_KEY }}
          alias: ${{ secrets.ANDROID_KEY_ALIAS }}
          keyStorePassword: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyPassword: ${{ secrets.ANDROID_KEY_PASSWORD }}
      - name: Upload to Google Play
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.opencli.mobile
          releaseFiles: build/app/outputs/bundle/release/*.aab
          track: production

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - name: Install CocoaPods
        run: gem install cocoapods
      - name: Build iOS
        working-directory: opencli-mobile
        run: flutter build ios --release --no-codesign
      - name: Build IPA
        run: |
          cd ios
          pod install
          xcodebuild -workspace Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -archivePath build/Runner.xcarchive \
            archive
      - name: Export IPA
        run: |
          xcodebuild -exportArchive \
            -archivePath build/Runner.xcarchive \
            -exportPath build \
            -exportOptionsPlist ExportOptions.plist
      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: build/Runner.ipa
          issuer-id: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          api-key-id: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          api-private-key: ${{ secrets.APP_STORE_CONNECT_API_PRIVATE_KEY }}
```

### Required GitHub Secrets (Copy from dtok-app)

**Android**:
```bash
# From dtok-app/android/keystore.properties
ANDROID_SIGNING_KEY           # Base64 encoded keystore file
ANDROID_KEY_ALIAS             # Key alias
ANDROID_KEYSTORE_PASSWORD     # Keystore password
ANDROID_KEY_PASSWORD          # Key password
GOOGLE_PLAY_SERVICE_ACCOUNT   # Service account JSON
```

**iOS**:
```bash
# From dtok-app iOS certificates
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_PRIVATE_KEY
IOS_CERTIFICATE_P12           # Base64 encoded certificate
IOS_CERTIFICATE_PASSWORD
IOS_PROVISION_PROFILE         # Base64 encoded provisioning profile
```

### Migration Commands (Copy Credentials from dtok-app)

```bash
# 1. Copy Android signing configuration
cp /Users/cw/development/dtok-app/android/keystore.properties \
   /Users/cw/development/opencli/opencli-mobile/android/

cp /Users/cw/development/dtok-app/android/app/upload-keystore.jks \
   /Users/cw/development/opencli/opencli-mobile/android/app/

# 2. Copy iOS certificates (if exist)
cp -r /Users/cw/development/dtok-app/ios/certificates \
      /Users/cw/development/opencli/opencli-mobile/ios/

# 3. Extract and set GitHub Secrets
# Android
KEYSTORE_BASE64=$(base64 -i opencli-mobile/android/app/upload-keystore.jks)
gh secret set ANDROID_SIGNING_KEY --body "$KEYSTORE_BASE64"

# (Read from keystore.properties and set other secrets similarly)

# iOS
CERT_BASE64=$(base64 -i opencli-mobile/ios/certificates/distribution.p12)
gh secret set IOS_CERTIFICATE_P12 --body "$CERT_BASE64"
```

---

## Implementation Phases

### Phase 1: Project Setup (1-2 days)
- [ ] Create Flutter project: `flutter create opencli-mobile`
- [ ] Set up project structure
- [ ] Configure Android package name: `com.opencli.mobile`
- [ ] Configure iOS bundle ID: `com.opencli.mobile`

### Phase 2: Core Development (3-5 days)
- [ ] Design mobile UI/UX
- [ ] Implement daemon communication
- [ ] Add task management features
- [ ] Testing on simulators/emulators

### Phase 3: Release Configuration (1-2 days)
- [ ] Copy signing credentials from dtok-app
- [ ] Set up GitHub Secrets
- [ ] Create mobile publishing workflow
- [ ] Test builds locally

### Phase 4: First Release (1 day)
- [ ] Create internal test release
- [ ] Upload to TestFlight (iOS)
- [ ] Upload to Google Play Internal Testing (Android)
- [ ] Validate automated workflow

---

## Quick Start Commands

```bash
# Option 1: If you want to create a Flutter mobile app
cd /Users/cw/development/opencli
flutter create opencli-mobile --org com.opencli
cd opencli-mobile

# Copy credentials from dtok-app
cp /Users/cw/development/dtok-app/android/keystore.properties android/
cp /Users/cw/development/dtok-app/android/app/upload-keystore.jks android/app/

# Test local build
flutter build apk --release
flutter build ios --release --no-codesign

# Option 2: If you prefer PWA (no native app)
cd web-ui
npm install
npm run build
# Deploy as PWA with app manifest
```

---

## Estimated Timeline

- **Flutter App Approach**: 7-10 days (development + setup)
- **PWA Approach**: 2-3 days (optimization only)

## Recommendation

**Start with PWA approach** for faster time-to-market, then **evaluate Flutter app** if native features are needed (push notifications, background tasks, etc.).

Would you like me to proceed with creating the Flutter mobile app structure, or would you prefer to optimize the web-ui as a PWA first?
