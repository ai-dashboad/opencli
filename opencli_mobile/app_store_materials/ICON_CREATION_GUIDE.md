# App Icon Creation Guide

## 📋 Required Icon Sizes

### Android (Google Play)
- **512 x 512 pixels**
- Format: PNG, 32-bit
- File: `icon_512.png`
- No transparency (or use solid background)

### iOS (App Store)
- **1024 x 1024 pixels**
- Format: PNG, 24-bit RGB
- File: `icon_1024.png`
- No transparency
- No rounded corners (Apple adds them automatically)

### Additional Android Asset
- **Feature Graphic: 1024 x 500 pixels**
- Format: PNG or JPG
- File: `feature_graphic.png`
- Used on Google Play store listing

---

## 🎨 Design Guidelines

### Icon Design Principles

1. **Simple and Recognizable**
   - Clear at small sizes
   - Distinctive and memorable
   - Works in both light and dark backgrounds

2. **OpenCLI Brand Elements**
   - Consider using:
     - Terminal/CLI imagery
     - AI/automation symbols
     - Command prompt aesthetic
     - Blue color scheme (matching Material Design 3)

3. **Platform Guidelines**
   - Android: Can use full bleed (edge-to-edge)
   - iOS: Leave 10% safe area around edges

### Suggested Icon Concepts

**Option 1: Terminal Window**
```
┌─────────────┐
│ >_ OpenCLI  │
│ ▓▓▓▓▓▓▓     │
│ ▓▓▓▓▓       │
└─────────────┘
```

**Option 2: Command Symbol**
```
    > _
  OpenCLI
```

**Option 3: Abstract Automation**
```
  ⚙️ + 🤖
```

---

## 🛠️ Icon Creation Tools

### Option 1: Online Generators (Quickest)

**Icon Kitchen** (Recommended)
- URL: https://icon.kitchen
- Upload a 1024x1024 PNG
- Generates all required sizes automatically
- Free and easy to use

**App Icon Generator**
- URL: https://www.appicon.co
- Upload source image
- Downloads iOS and Android assets

**Make App Icon**
- URL: https://makeappicon.com
- Generates full asset catalogs

### Option 2: Design Tools (Professional)

**Figma** (Free)
1. Create 1024x1024 frame
2. Design icon with vector tools
3. Export as PNG at 1024x1024 and 512x512
4. Tutorial: https://www.figma.com/community

**Canva** (Free)
1. Create custom size: 1024x1024
2. Use templates or design from scratch
3. Download as PNG
4. Resize to 512x512 for Android

**Adobe Illustrator/Photoshop**
- Professional option
- Full control over design
- Export at required sizes

### Option 3: AI Generation (Quick)

**DALL-E / Midjourney / Stable Diffusion**
Prompt examples:
```
"Modern minimalist app icon for CLI automation tool,
blue gradient, terminal symbol, flat design, no text"

"Professional mobile app icon, command line interface theme,
gradient blue and purple, simple geometric shapes"
```

Then resize/crop to required dimensions.

---

## 📐 Step-by-Step Creation (Figma)

### 1. Set Up Figma

```bash
# Visit https://www.figma.com
# Sign up for free account
# Create new file
```

### 2. Create Icon Frame

1. Click "Frame" tool (F) or use Rectangle (R)
2. Set size: 1024 x 1024
3. Name frame: "Icon 1024"

### 3. Design Icon

Example design with terminal theme:

```
Background:
- Rectangle: 1024x1024
- Gradient: #1976D2 → #1565C0 (Material Blue)

Terminal Symbol:
- Text: ">_"
- Font: SF Mono / Roboto Mono
- Size: 400px
- Color: White
- Center aligned

Optional:
- Add OpenCLI text below
- Add subtle shadow or glow
```

### 4. Export Icons

**For iOS (1024x1024):**
1. Select frame
2. Click "Export" in bottom right
3. Format: PNG
4. Scale: 1x
5. Export as `icon_1024.png`

**For Android (512x512):**
1. Same frame
2. Export settings: PNG, 0.5x scale
3. Export as `icon_512.png`

---

## 🎯 Feature Graphic Creation (Android)

### Specifications
- Size: 1024 x 500 pixels
- Format: PNG or JPG
- Content: Promotional banner for Play Store

### Design Template

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   [App Icon]    OpenCLI                            │
│                                                     │
│                 AI Task Orchestration on Mobile    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Content Suggestions

1. **App Icon** (left side)
2. **App Name**: OpenCLI (large, bold)
3. **Tagline**: "AI Task Orchestration on Mobile"
4. **Background**: Gradient or subtle pattern
5. **Optional**: Screenshot preview or feature highlights

### Figma Template

1. Create frame: 1024 x 500
2. Add gradient background
3. Place app icon (scaled to ~200x200)
4. Add text:
   - Title: "OpenCLI" - 72pt, Bold
   - Subtitle: "AI Task Orchestration" - 36pt, Regular
5. Export as PNG or JPG

---

## ✅ Quick Start with Templates

### Using Icon Kitchen (Fastest Method)

```bash
# 1. Create a simple 1024x1024 PNG with any tool
#    (even PowerPoint or Keynote works)

# 2. Visit https://icon.kitchen

# 3. Upload your 1024x1024 PNG

# 4. Customize:
#    - Background color
#    - Padding
#    - Shape (square, rounded, circle)

# 5. Download:
#    - Android: 512x512
#    - iOS: 1024x1024
#    - Feature graphic template

# 6. Move files to app_store_materials/
```

### Using Canva Template

```bash
# 1. Visit https://www.canva.com

# 2. Search for "App Icon" templates

# 3. Customize template:
#    - Change text to "OpenCLI"
#    - Adjust colors to blue theme
#    - Add terminal/CLI symbols

# 4. Download as PNG
#    - For iOS: Download at 1024x1024
#    - For Android: Download at 512x512

# 5. Create Feature Graphic:
#    - Search "YouTube Banner" (2560x1440)
#    - Crop to 1024x500
#    - Add app icon + text
```

---

## 📂 File Organization

After creating icons, organize them:

```
opencli_mobile/app_store_materials/
├── icon_1024.png          # iOS App Store icon
├── icon_512.png           # Android Play Store icon
├── feature_graphic.png    # Android Feature Graphic
└── icons/
    ├── source/
    │   └── icon_source.fig    # Original Figma file
    └── exports/
        ├── icon_1024.png
        ├── icon_512.png
        └── feature_graphic.png
```

---

## 🔍 Icon Checklist

### Before Submission

- [ ] iOS icon is exactly 1024 x 1024 pixels
- [ ] Android icon is exactly 512 x 512 pixels
- [ ] Both icons are PNG format
- [ ] No transparency in icons
- [ ] Icons are clear and recognizable at small sizes
- [ ] Icons work on both light and dark backgrounds
- [ ] No text smaller than recommended size
- [ ] Feature graphic is 1024 x 500 pixels
- [ ] All files are under 1MB each
- [ ] Icons match OpenCLI brand colors

### Design Quality

- [ ] Icon looks professional
- [ ] Icon is unique and distinguishable
- [ ] Icon represents the app's purpose
- [ ] Icon follows platform guidelines
- [ ] Icon has been tested at various sizes

---

## 🎨 Color Palette (Material Blue)

Use these colors for consistency:

```
Primary Blue:
- Light: #42A5F5
- Main: #1976D2  ← Recommended
- Dark: #1565C0

Secondary:
- Accent: #64B5F6
- Background: #E3F2FD

Grayscale:
- White: #FFFFFF
- Light Gray: #F5F5F5
- Dark Gray: #424242
- Black: #000000
```

---

## 💡 Pro Tips

1. **Test at Multiple Sizes**
   - View icon at 48px, 96px, 192px
   - Ensure it's still clear and recognizable

2. **Check on Both Themes**
   - Preview on white background (light mode)
   - Preview on dark background (dark mode)

3. **Avoid Common Mistakes**
   - Don't use too much detail
   - Don't include small text
   - Don't use photos (unless highly stylized)
   - Don't add rounded corners for iOS (Apple does this)

4. **Get Feedback**
   - Show to colleagues or friends
   - Test on actual devices
   - Compare with similar apps

5. **Keep Source Files**
   - Save original Figma/AI/PSD files
   - Easy to update for future versions

---

## 🚀 Next Steps After Creating Icons

1. **Update Flutter Assets**
   ```bash
   # Copy icons to Flutter project
   cp icon_512.png opencli_mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
   cp icon_1024.png opencli_mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/
   ```

2. **Upload to App Stores**
   - Google Play: Upload icon_512.png and feature_graphic.png
   - App Store: Upload icon_1024.png

3. **Test Build**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   flutter build ios --release --no-codesign
   ```

---

**Created**: 2026-01-31
**Status**: Ready to use
**Estimated Time**: 30-60 minutes for basic icon

🎨 **Ready to create your OpenCLI icon!**
