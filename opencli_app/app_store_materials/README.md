# App Store Materials

This directory contains all materials needed for Google Play Store and Apple App Store submission.

## 📁 Directory Structure

```
app_store_materials/
├── README.md                      # This file
├── APP_DESCRIPTION.md             # ✅ Complete app descriptions
├── ICON_CREATION_GUIDE.md         # ✅ Guide for creating icons
├── icon_512.png                   # 🔨 TO CREATE - Android icon
├── icon_1024.png                  # 🔨 TO CREATE - iOS icon
├── feature_graphic.png            # 🔨 TO CREATE - Google Play feature graphic
└── screenshots/                   # 🔨 TO CREATE - App screenshots
    ├── android/
    │   ├── phone/                 # 1080x1920 or higher (2-8 images)
    │   └── tablet/                # Optional: 1920x1200
    └── ios/
        ├── 6.7/                   # 1290x2796 (iPhone 14 Pro Max)
        ├── 6.5/                   # 1242x2688 (iPhone 11 Pro Max)
        └── 5.5/                   # 1242x2208 (iPhone 8 Plus)
```

## ✅ What's Ready

1. **APP_DESCRIPTION.md**
   - Complete app descriptions (English & Chinese)
   - Keywords and categories
   - Privacy policy content
   - Version information
   - Support URLs

2. **ICON_CREATION_GUIDE.md**
   - Step-by-step icon creation instructions
   - Recommended tools and templates
   - Design guidelines
   - Export specifications

## 🔨 What Needs to Be Created

### 1. App Icons (30-45 minutes)

**Android Icon: icon_512.png**
- Size: 512 x 512 pixels
- Format: PNG, 32-bit
- No transparency

**iOS Icon: icon_1024.png**
- Size: 1024 x 1024 pixels
- Format: PNG, 24-bit RGB
- No transparency, no rounded corners

**Quick Method:**
1. Visit https://icon.kitchen
2. Upload a 1024x1024 PNG design
3. Download both 512x512 and 1024x1024
4. Save to this directory

### 2. Feature Graphic (15-30 minutes)

**feature_graphic.png**
- Size: 1024 x 500 pixels
- Format: PNG or JPG
- Content: App icon + "OpenCLI" + tagline
- Background: Blue gradient

**Quick Method:**
1. Use Canva or Figma
2. Create 1024x500 canvas
3. Add app icon, app name, and tagline
4. Export and save here

### 3. Screenshots (30-60 minutes)

Use the automated script:
```bash
cd ../
./scripts/generate_screenshots.sh
```

Or manually:
1. Run app on simulators/emulators
2. Navigate to each screen (Tasks, Status, Settings)
3. Take screenshots (Cmd+S or camera icon)
4. Save to appropriate screenshot folders

**Required Screens:**
- Tasks page (with Submit button)
- Status page (daemon status)
- Settings page
- Dark mode example (optional)

## 🎨 Design Guidelines

### Color Scheme
Use Material Blue to match the app:
- Primary: #1976D2
- Light: #42A5F5
- Dark: #1565C0

### Icon Concepts
- Terminal symbol (>_)
- Command line theme
- Clean, minimalist design
- Works on light and dark backgrounds

### Screenshot Tips
- Use release build for clean UI
- Capture in light mode primarily
- Show actual content, not empty states
- Keep UI elements readable
- Consider adding device frames (optional)

## 📋 Pre-Submission Checklist

Before submitting to app stores:

### Files Created
- [ ] icon_512.png
- [ ] icon_1024.png
- [ ] feature_graphic.png
- [ ] Android screenshots (2-8 images in screenshots/android/phone/)
- [ ] iOS screenshots (3-10 images in each: screenshots/ios/6.7/, 6.5/, 5.5/)

### Files Verified
- [ ] Icons are correct size and format
- [ ] Screenshots show app features clearly
- [ ] Feature graphic looks professional
- [ ] All files are under 1MB each
- [ ] Icons work on light and dark backgrounds

### Information Ready
- [ ] Read APP_DESCRIPTION.md
- [ ] Privacy policy ready at https://opencli.ai/privacy
- [ ] Support email accessible: support@opencli.ai

## 🚀 Next Steps

1. **Create Assets** (1-2 hours total)
   ```bash
   # Create icons using Icon Kitchen or Canva
   # Generate screenshots using script
   ../scripts/generate_screenshots.sh
   ```

2. **Verify Assets**
   ```bash
   # Check all files are created
   ls -lh icon_*.png
   ls -lh feature_graphic.png
   ls -lh screenshots/android/phone/
   ls -lh screenshots/ios/*/
   ```

3. **Submit to Stores**
   - Follow: `../../docs/GOOGLE_PLAY_SUBMISSION_GUIDE.md`
   - Follow: `../../docs/APP_STORE_SUBMISSION_GUIDE.md`
   - Quick start: `../../docs/APP_STORE_QUICK_START.md`

## 📞 Resources

### Icon Creation Tools
- Icon Kitchen: https://icon.kitchen (Recommended)
- Canva: https://www.canva.com
- Figma: https://www.figma.com

### Screenshot Enhancement
- Screenshot.rocks: https://screenshot.rocks
- App Mockup: https://app-mockup.com

### Guides
- Icon creation: See ICON_CREATION_GUIDE.md
- Full descriptions: See APP_DESCRIPTION.md
- Submission guides: See ../../docs/

## ⏱️ Time Estimates

- Icon creation: 30-45 minutes
- Feature graphic: 15-30 minutes
- Screenshots: 30-60 minutes
- **Total**: 1.5-2.5 hours

---

**Status**: Ready for asset creation
**Last Updated**: 2026-01-31
**Version**: 0.1.1

🎨 Start creating your app store assets!
