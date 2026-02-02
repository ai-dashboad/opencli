# Google Play Data Safety Declaration Template

This document helps you fill out the **Data Safety** form in Google Play Console.

## Navigation
Google Play Console → App Content → Data safety → Start

---

## Section 1: Data Collection and Security

### Does your app collect or share any of the required user data types?
**Answer**: Yes

---

## Section 2: Data Types Collected

### Device or other identifiers

**What data is collected?**
- Device ID (for device pairing and authentication)

**Is this data collected, shared, or both?**
- Collected only

**Is this data processed ephemerally?**
- No

**Is data collection required or optional?**
- Required

**Why is this user data collected?**
- App functionality
- Account management (device pairing)

---

### Audio

**What data is collected?**
- Voice or sound recordings (for voice commands)

**Is this data collected, shared, or both?**
- Collected only (processed locally, NOT transmitted to servers)

**Is this data processed ephemerally?**
- Yes (processed immediately and discarded)

**Is data collection required or optional?**
- Optional

**Why is this user data collected?**
- App functionality (voice command feature)

---

### App info and performance

**What data is collected?**
- Crash logs
- Diagnostics

**Is this data collected, shared, or both?**
- Collected only

**Is this data processed ephemerally?**
- No

**Is data collection required or optional?**
- Optional (user can disable)

**Why is this user data collected?**
- App functionality
- Analytics

---

## Section 3: Data Security

### Is all of the user data collected by your app encrypted in transit?
**Answer**: Yes

**Explanation**: All data transmission between the mobile app and computer daemon uses end-to-end encryption.

---

### Do you provide a way for users to request that their data is deleted?
**Answer**: Yes

**Explanation**: Users can delete all local data by:
1. Uninstalling the app (removes all local data)
2. Contacting support for server-side data deletion (if any)
3. Using in-app settings to clear cache and logs

---

## Section 4: Data Usage and Handling

### Device ID Usage

**How is this data used?**
- For device pairing and authentication with user's personal computer
- To maintain secure communication channel
- To prevent unauthorized access

**Is this data shared with third parties?**
- No

**Can users choose whether this data is collected?**
- No (required for core functionality)

---

### Voice Data Usage

**How is this data used?**
- Speech-to-text conversion for voice commands
- Processed locally on device
- Never stored or transmitted to external servers

**Is this data shared with third parties?**
- No

**Can users choose whether this data is collected?**
- Yes (voice commands are optional, user can grant/deny microphone permission)

---

### Crash Logs and Diagnostics

**How is this data used?**
- Bug fixing and app stability improvement
- Performance monitoring
- Aggregated and anonymized analytics

**Is this data shared with third parties?**
- No (except crash reporting service like Firebase Crashlytics if used)

**Can users choose whether this data is collected?**
- Yes (can be disabled in app settings)

---

## Section 5: Data Sharing (if applicable)

### If you use cloud AI features (optional):

**Data Shared with AI Providers** (only if user enables cloud AI):
- User queries/commands
- Context information for AI processing

**AI Providers**:
- Anthropic (Claude API)
- OpenAI (GPT API)
- Google (Gemini API)

**Purpose**: AI-powered task execution

**Can users avoid this?**: Yes (users can choose local-only processing)

---

## Recommended Answers Summary for Google Play Console

| Question | Answer |
|----------|--------|
| Does your app collect or share user data? | Yes |
| Do you collect device IDs? | Yes, required for app functionality |
| Do you collect audio data? | Yes, but processed ephemerally and optional |
| Is data encrypted in transit? | Yes |
| Do you provide data deletion? | Yes |
| Do you share data with third parties? | No (or Yes, only if user enables cloud AI) |

---

## Important Notes

1. **Be Honest**: Google can verify your claims through app analysis
2. **Update Regularly**: If you add new features that collect data, update this declaration
3. **Privacy Policy Link**: Make sure your privacy policy URL is accessible and matches this declaration
4. **Testing**: Google may test your app to verify these claims

---

## Next Steps After Filling Data Safety Form

1. ✅ Submit the form in Google Play Console
2. ✅ Ensure privacy policy is hosted and accessible at declared URL
3. ✅ Update app description to mention privacy features
4. ✅ Test app to ensure permission flows work correctly
5. ✅ Resubmit app for review

---

## Privacy Policy URL

Make sure to host the privacy policy at: `https://opencli.ai/privacy`

Or use GitHub Pages: `https://ai-dashboad.github.io/opencli/privacy`
