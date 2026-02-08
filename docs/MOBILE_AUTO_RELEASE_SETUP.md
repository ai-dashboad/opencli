# OpenCLI Mobile - Automated Release Setup Guide

**Date**: 2026-01-31
**Status**: ✅ Configured
**Platforms**: iOS, Android

---

## 📋 Overview

This guide explains the automated release setup for OpenCLI Mobile apps to:
- **Google Play Store** (Android)
- **Apple App Store** (iOS/Mac)

Both platforms use GitHub Actions workflows that automatically build and deploy apps when triggered.

---

## 🎯 Current Status

### ✅ Completed Configuration

1. **Fastlane Setup**
   - ✅ Android fastlane configuration
   - ✅ iOS fastlane configuration
   - ✅ Automated upload lanes

2. **GitHub Workflows**
   - ✅ `.github/workflows/android-play-store.yml`
   - ✅ `.github/workflows/ios-app-store.yml`

3. **GitHub Secrets**
   - ✅ ANDROID_KEYSTORE_BASE64
   - ✅ ANDROID_KEYSTORE_PASSWORD
   - ✅ ANDROID_KEY_ALIAS
   - ✅ ANDROID_KEY_PASSWORD
   - ✅ PLAY_STORE_JSON_KEY

4. **Pending Configuration**
   - 🔨 APP_STORE_CONNECT_API_KEY_ID
   - 🔨 APP_STORE_CONNECT_ISSUER_ID
   - 🔨 APP_STORE_CONNECT_API_KEY_BASE64
   - 🔨 DISTRIBUTION_CERTIFICATE_BASE64
   - 🔨 DISTRIBUTION_CERTIFICATE_PASSWORD
   - 🔨 KEYCHAIN_PASSWORD
   - 🔨 PROVISIONING_PROFILE_BASE64

---

## 🤖 Android Release Setup

### Prerequisites

- ✅ Google Play Console account
- ✅ App created in Play Console
- ✅ Service account JSON key
- ✅ Android keystore (already configured)

### GitHub Secrets (Already Set)

```bash
# All Android secrets are already configured! ✅
gh secret list
```

### How to Release

**Option 1: Tag-based Release (Automatic)**
```bash
# Will release to 'internal' track by default
git tag v0.1.2
git push origin v0.1.2
```

**Option 2: Manual Release (Choose Track)**
```bash
# Go to GitHub Actions
# Select "Android - Google Play Store Release" workflow
# Click "Run workflow"
# Choose track: internal/beta/production
```

### Available Tracks

1. **Internal Testing** - For internal team testing
2. **Beta (Closed Testing)** - For selected beta testers
3. **Production** - Public release

### Fastlane Commands (Local)

```bash
cd opencli_mobile/android

# Set environment variable
export PLAY_STORE_JSON_KEY='<json content>'

# Deploy to internal testing
fastlane internal

# Deploy to beta
fastlane beta

# Deploy to production
fastlane production

# Promote from internal to beta
fastlane promote_to_beta

# Promote from beta to production
fastlane promote_to_production
```

---

## 🍎 iOS Release Setup

### Prerequisites

- Apple Developer Program membership ($99/year)
- App created in App Store Connect
- App Store Connect API Key
- Distribution certificate (.p12)
- Provisioning profile

### Step 1: Create App Store Connect API Key

1. **Login to App Store Connect**
   - Visit: https://appstoreconnect.apple.com
   - Go to: Users and Access → Keys

2. **Generate API Key**
   - Click: "+" to create new key
   - Name: "OpenCLI Mobile GitHub Actions"
   - Access: App Manager
   - Click: Generate

3. **Download and Save**
   - Download the `.p8` file (only shown once!)
   - Note the **Key ID** (e.g., ABC123XYZ)
   - Note the **Issuer ID** (top of page)

4. **Encode for GitHub Secret**
   ```bash
   # Base64 encode the .p8 file
   base64 -i AuthKey_ABC123XYZ.p8 | pbcopy

   # Set GitHub secrets
   gh secret set APP_STORE_CONNECT_API_KEY_ID -b"ABC123XYZ"
   gh secret set APP_STORE_CONNECT_ISSUER_ID -b"YOUR-ISSUER-ID"

   # Paste the base64 content from clipboard
   gh secret set APP_STORE_CONNECT_API_KEY_BASE64
   ```

### Step 2: Create Distribution Certificate

1. **Open Keychain Access (Mac)**
   - Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
   - User Email: your-email@example.com
   - Common Name: OpenCLI Mobile Distribution
   - Save to disk

2. **Create Certificate in Developer Portal**
   - Visit: https://developer.apple.com/account/resources/certificates
   - Click: "+" to add certificate
   - Select: "Apple Distribution"
   - Upload the CSR file
   - Download certificate (.cer file)

3. **Install Certificate**
   - Double-click the downloaded .cer file
   - It will be added to your Keychain

4. **Export Certificate as .p12**
   ```bash
   # In Keychain Access:
   # 1. Find "Apple Distribution: Your Name"
   # 2. Right-click → Export
   # 3. Save as: opencli-distribution.p12
   # 4. Set password (e.g., "opencli2026")
   ```

5. **Encode for GitHub Secret**
   ```bash
   # Base64 encode the .p12 file
   base64 -i opencli-distribution.p12 | pbcopy

   # Set GitHub secrets
   # Paste the base64 content from clipboard
   gh secret set DISTRIBUTION_CERTIFICATE_BASE64

   # Set the password you used
   gh secret set DISTRIBUTION_CERTIFICATE_PASSWORD -b"opencli2026"

   # Set a keychain password for CI
   gh secret set KEYCHAIN_PASSWORD -b"actions-keychain-pwd"
   ```

### Step 3: Create Provisioning Profile

1. **Register App ID (if not exists)**
   - Visit: https://developer.apple.com/account/resources/identifiers
   - Click: "+"
   - Select: App IDs
   - Bundle ID: com.opencli.mobile
   - Click: Continue → Register

2. **Create Provisioning Profile**
   - Visit: https://developer.apple.com/account/resources/profiles
   - Click: "+"
   - Select: "App Store"
   - Choose App ID: com.opencli.mobile
   - Select Certificate: The distribution certificate you created
   - Name: "OpenCLI Mobile Distribution"
   - Click: Generate
   - Download the .mobileprovision file

3. **Encode for GitHub Secret**
   ```bash
   # Base64 encode the provisioning profile
   base64 -i OpenCLI_Mobile_Distribution.mobileprovision | pbcopy

   # Set GitHub secret
   # Paste the base64 content from clipboard
   gh secret set PROVISIONING_PROFILE_BASE64
   ```

### How to Release

**Option 1: Tag-based Release (Automatic)**
```bash
git tag v0.1.2
git push origin v0.1.2
# Workflow will build and upload to App Store Connect
```

**Option 2: Manual Release**
```bash
# Go to GitHub Actions
# Select "iOS/Mac - App Store Release" workflow
# Click "Run workflow"
# Optionally check "Submit for review"
```

### Fastlane Commands (Local)

```bash
cd opencli_mobile/ios

# Set environment variables
export APP_STORE_CONNECT_API_KEY_ID="ABC123XYZ"
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_API_KEY_FILEPATH="/path/to/AuthKey_ABC123XYZ.p8"

# Build and upload to App Store
fastlane release

# Build ad-hoc for testing
fastlane beta

# Setup certificates (using match)
fastlane setup_certificates
```

---

## 🔐 GitHub Secrets Reference

### Android Secrets (✅ Already Set)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| ANDROID_KEYSTORE_BASE64 | Base64 encoded keystore | `base64 release.keystore` |
| ANDROID_KEYSTORE_PASSWORD | Keystore password | From keystore.properties |
| ANDROID_KEY_ALIAS | Key alias | From keystore.properties |
| ANDROID_KEY_PASSWORD | Key password | From keystore.properties |
| PLAY_STORE_JSON_KEY | Service account JSON | From Google Play Console |

### iOS Secrets (🔨 Need to Configure)

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| APP_STORE_CONNECT_API_KEY_ID | API Key ID | App Store Connect → Keys |
| APP_STORE_CONNECT_ISSUER_ID | Issuer ID | App Store Connect → Keys |
| APP_STORE_CONNECT_API_KEY_BASE64 | Base64 encoded .p8 | `base64 AuthKey_XXX.p8` |
| DISTRIBUTION_CERTIFICATE_BASE64 | Base64 encoded .p12 | Export from Keychain |
| DISTRIBUTION_CERTIFICATE_PASSWORD | Certificate password | Password set during export |
| KEYCHAIN_PASSWORD | CI keychain password | Any secure password |
| PROVISIONING_PROFILE_BASE64 | Base64 encoded profile | Developer Portal |

---

## 🚀 Release Workflow

### Automated Release Process

1. **Trigger Release**
   ```bash
   # Update version in pubspec.yaml first if needed
   git tag v0.1.2
   git push origin v0.1.2
   ```

2. **GitHub Actions Automatically:**
   - Android:
     - ✅ Builds AAB
     - ✅ Signs AAB
     - ✅ Uploads to Google Play Internal Testing
     - ✅ Creates GitHub Release with AAB

   - iOS:
     - 🔨 Builds IPA (requires secrets)
     - 🔨 Signs IPA
     - 🔨 Uploads to App Store Connect
     - 🔨 Creates GitHub Release with IPA

3. **Post-Upload Actions**
   - Android:
     - Review in Play Console
     - Promote to Beta/Production when ready
     - Submit for review if needed

   - iOS:
     - App processes in App Store Connect (5-30 min)
     - Add to TestFlight (optional)
     - Submit for review

---

## 📊 Workflow Status

### Check Workflow Runs

```bash
# List recent workflow runs
gh run list

# Watch a running workflow
gh run watch

# View workflow logs
gh run view <run-id> --log
```

### Monitor App Stores

**Google Play Console**
- Visit: https://play.google.com/console
- Navigate to: Release → Production/Testing
- Check status and reviews

**App Store Connect**
- Visit: https://appstoreconnect.apple.com
- Navigate to: My Apps → OpenCLI
- Check build processing and review status

---

## 🔧 Troubleshooting

### Common Android Issues

**Issue: AAB upload fails**
```bash
# Check if AAB file exists
ls -lh opencli_mobile/build/app/outputs/bundle/release/

# Verify PLAY_STORE_JSON_KEY secret is set
gh secret list | grep PLAY

# Test locally
cd opencli_mobile/android
export PLAY_STORE_JSON_KEY='<content>'
fastlane internal
```

**Issue: Keystore not found**
```bash
# Verify keystore secret
gh secret list | grep ANDROID

# Check keystore.properties format
cat opencli_mobile/android/keystore.properties
```

### Common iOS Issues

**Issue: Certificate import fails**
```bash
# Verify certificate password
# Check DISTRIBUTION_CERTIFICATE_PASSWORD secret

# Test certificate locally
security import opencli-distribution.p12 -k ~/Library/Keychains/login.keychain
```

**Issue: Provisioning profile not found**
```bash
# Check if profile is installed
ls -lh ~/Library/MobileDevice/Provisioning\ Profiles/

# Verify base64 encoding
echo "$PROVISIONING_PROFILE_BASE64" | base64 --decode > test.mobileprovision
```

**Issue: API key authentication fails**
```bash
# Verify API key file exists
ls -lh ~/private_keys/AuthKey_*.p8

# Check API key permissions
# Must have "App Manager" role in App Store Connect
```

### Debug Mode

Enable debug output in workflows:
```yaml
env:
  FASTLANE_VERBOSE: "true"
  DEBUG: "1"
```

---

## 📁 File Structure

```
opencli_mobile/
├── android/
│   ├── app/
│   │   └── release.keystore          # Android signing key
│   ├── keystore.properties           # Keystore config
│   └── fastlane/
│       ├── Appfile                   # Android fastlane app config
│       ├── Fastfile                  # Android fastlane lanes
│       └── metadata/                 # Play Store metadata
│           └── android/
│               ├── en-US/
│               └── zh-CN/
├── ios/
│   ├── ExportOptions.plist           # iOS export config
│   └── fastlane/
│       ├── Appfile                   # iOS fastlane app config
│       ├── Fastfile                  # iOS fastlane lanes
│       └── metadata/                 # App Store metadata
│           └── en-US/
└── pubspec.yaml                      # Version number

.github/workflows/
├── android-play-store.yml            # Android release workflow
└── ios-app-store.yml                 # iOS release workflow
```

---

## 🎓 Best Practices

### Version Management

1. **Update version in pubspec.yaml**
   ```yaml
   version: 0.1.2+6  # version+build
   ```

2. **Create git tag**
   ```bash
   git tag v0.1.2
   git push origin v0.1.2
   ```

3. **Workflows automatically use the version**

### Release Strategy

**Recommended Flow:**
1. Internal Testing → Test with team
2. Closed Beta → Test with selected users
3. Open Beta → Public beta (optional)
4. Production → Full release

**For Each Release:**
- Update changelog
- Test thoroughly
- Review crash reports
- Monitor user feedback

### Security

- ✅ Never commit certificates or keys to git
- ✅ Use GitHub Secrets for all sensitive data
- ✅ Rotate API keys periodically
- ✅ Use strong passwords for certificates
- ✅ Enable 2FA on Apple ID and Google account

---

## 📞 Support Resources

### Documentation
- Google Play: https://support.google.com/googleplay/android-developer
- App Store: https://developer.apple.com/support/app-store-connect
- Fastlane: https://docs.fastlane.tools

### Quick Commands

```bash
# Setup all secrets (after obtaining them)
./scripts/setup-mobile-secrets.sh

# Test fastlane locally
cd opencli_mobile/android && fastlane internal
cd opencli_mobile/ios && fastlane beta

# Trigger release
git tag v0.1.2 && git push origin v0.1.2

# Monitor workflow
gh run watch
```

---

## ✅ Setup Checklist

### Android (✅ Complete)
- [x] Google Play Console account
- [x] App created in Play Console
- [x] Service account JSON key obtained
- [x] PLAY_STORE_JSON_KEY secret set
- [x] Android keystore secrets set
- [x] Fastlane configured
- [x] GitHub workflow created

### iOS (🔨 Needs Configuration)
- [ ] Apple Developer Program membership
- [ ] App created in App Store Connect
- [ ] App Store Connect API Key created
- [ ] API key secrets set (KEY_ID, ISSUER_ID, KEY_BASE64)
- [ ] Distribution certificate created and exported
- [ ] Certificate secrets set (CERT_BASE64, CERT_PASSWORD)
- [ ] Provisioning profile created
- [ ] Profile secret set (PROFILE_BASE64)
- [x] Fastlane configured
- [x] GitHub workflow created

---

**Created**: 2026-01-31
**Last Updated**: 2026-01-31
**Status**: Android Ready ✅ | iOS Needs Secrets 🔨

🚀 **Android releases are fully automated! Configure iOS secrets to enable iOS releases.**
