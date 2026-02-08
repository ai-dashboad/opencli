# Mobile Release Setup Guide

## GitHub Secrets Configuration

To enable automated mobile app publishing, you need to configure the following GitHub Secrets.

### Required Secrets

#### Android Secrets

1. **ANDROID_KEYSTORE_BASE64**
   ```bash
   # Encode the keystore file
   base64 -i opencli_app/android/app/release.keystore | pbcopy
   # Then paste as secret value
   ```

2. **ANDROID_KEYSTORE_PASSWORD**
   ```
   Value: dtok2026
   ```

3. **ANDROID_KEY_ALIAS**
   ```
   Value: dtok
   ```

4. **ANDROID_KEY_PASSWORD**
   ```
   Value: dtok2026
   ```

#### iOS Secrets (Optional - for App Store publishing)

5. **APP_STORE_CONNECT_ISSUER_ID**
   - Get from: https://appstoreconnect.apple.com/access/api
   - Team ID: G9VG22HGJG

6. **APP_STORE_CONNECT_API_KEY_ID**
   - Get from: https://appstoreconnect.apple.com/access/api

7. **APP_STORE_CONNECT_API_PRIVATE_KEY**
   - Download from App Store Connect
   - Paste the content of the .p8 file

---

## Setup Commands

### 1. Encode Keystore for GitHub Secrets

```bash
cd /Users/cw/development/opencli

# Encode keystore
base64 -i opencli_app/android/app/release.keystore > /tmp/keystore.b64

# Show the encoded value
cat /tmp/keystore.b64

# Copy to clipboard (macOS)
cat /tmp/keystore.b64 | pbcopy
```

### 2. Set GitHub Secrets using gh CLI

```bash
# Set Android secrets
gh secret set ANDROID_KEYSTORE_BASE64 < /tmp/keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD --body "dtok2026"
gh secret set ANDROID_KEY_ALIAS --body "dtok"
gh secret set ANDROID_KEY_PASSWORD --body "dtok2026"

# Verify secrets are set
gh secret list
```

---

## Local Build Testing

### Android

```bash
cd opencli_app

# Debug build
flutter build apk --debug

# Release build (requires keystore)
flutter build apk --release

# App Bundle (for Google Play)
flutter build appbundle --release
```

### iOS

```bash
cd opencli_app

# Build for simulator
flutter build ios --simulator

# Build for device (requires signing)
flutter build ios --release
```

---

## Publishing Workflow

The mobile publishing workflow (`.github/workflows/publish-mobile.yml`) will automatically:

1. **On Tag Push** (`v*`):
   - Build Android APK and AAB
   - Build iOS IPA
   - Upload artifacts to GitHub Release

2. **Artifacts Created**:
   - `opencli-mobile-android-apk` - Android APK file
   - `opencli-mobile-android-aab` - Android App Bundle (for Play Store)
   - `opencli-mobile-ios-ipa` - iOS IPA file

---

## Manual Publishing

### Google Play Console

1. Upload AAB file to Google Play Console
2. Create a new release in Production/Beta/Alpha track
3. Fill in release notes
4. Submit for review

### Apple App Store

1. Use Xcode to upload IPA to App Store Connect
2. Or use Transporter app
3. Create a new version in App Store Connect
4. Fill in App information
5. Submit for review

---

## Troubleshooting

### Android Build Issues

**Issue**: Keystore not found
```bash
# Check keystore file exists
ls -la opencli_app/android/app/release.keystore

# Verify keystore.properties
cat opencli_app/android/keystore.properties
```

**Issue**: Build fails with signing error
```bash
# Test keystore manually
keytool -list -v -keystore opencli_app/android/app/release.keystore
# Password: dtok2026
```

### iOS Build Issues

**Issue**: Code signing error
- Ensure you have valid Apple Developer account
- Check provisioning profiles in Xcode
- Update team ID in Xcode project settings

**Issue**: CocoaPods dependency issues
```bash
cd opencli_app/ios
pod repo update
pod install
```

---

## Version Management

The mobile app version is managed in `pubspec.yaml`:

```yaml
version: 0.1.1+5
#        ^^^^^ ^^^
#        name  build number
```

To update version:
```bash
# Edit pubspec.yaml
# version: 0.2.0+6

# Or use version bump script (to be created)
./scripts/bump_mobile_version.sh 0.2.0
```

---

## Next Steps

1. ✅ Project created
2. ✅ Android signing configured
3. ✅ iOS configuration copied
4. ✅ Publishing workflow created
5. ⏳ Set GitHub Secrets
6. ⏳ Test local builds
7. ⏳ Push and trigger automated build
8. ⏳ Verify artifacts in GitHub Release

---

**Setup Date**: 2026-01-31
**Status**: Ready for Secrets configuration
