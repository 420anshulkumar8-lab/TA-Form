# Developer Setup Guide

## 1. Prerequisites

- Flutter SDK >= 3.2.0
- Android Studio or VS Code with Flutter extension
- An Anthropic Claude API key

---

## 2. Install Dependencies

```bash
flutter pub get
```

---

## 3. Generate Hive Adapters

`EmployeeProfile` uses `@HiveType`. After any model changes, regenerate:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

The generated file `lib/models/employee_profile.g.dart` is already included.

---

## 4. Add Assets

### Fonts (Inter)
Download Inter from https://fonts.google.com/specimen/Inter  
Place these files in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

### GA-31 Form Scans (already included)
This project ships with two scanned pages of the GA-31 form, already placed at:
```
assets/images/ga31_page1.png   (front — header + TA table, page 1)
assets/images/ga31_page2.png   (continuation table + certificates, page 2)
```
The PDF service overlays text on these images using coordinates in
`lib/config/form_layout.dart`. If your physical form looks different (different
printer/scan margins), replace these two PNGs with your own scans — keep the
same filenames, and re-measure the X/Y constants in `FormLayout` to match.

**After first test run:** Open the generated PDF, compare field positions
against your physical form, then nudge the X/Y constants in `FormLayout`
(in points, 1pt = 1/72 inch) until alignment is correct.

If either PNG is missing, the app still works — that page will be generated on
a blank white background with all the text, no scanned form behind it.

### How the 2-page layout works
- **Page 1** gets the header fields (name, designation, pay, HQ, etc.) and as
  many TA-table rows as fit in the table area on the front page.
- **Page 2** automatically receives any remaining TA rows as a continuation of
  the same table, plus the employee's name in the certificate paragraph.
- The Grand Total row is printed right after the last TA entry, on whichever
  page that entry landed on.
- **Page 3+** (only if Contingent Bill is selected) is a separate blank A4
  page for the Contingent Bill — it isn't part of the GA-31 scan.

---

## 5. Configure Remote API Key

Open `lib/config/remote_config.dart` and set:

```dart
static const String configUrl = 'https://raw.githubusercontent.com/YOUR-ORG/YOUR-PRIVATE-REPO/main/config.json';
```

Create `config.json` in that private GitHub repo:
```json
{
  "api_key": "sk-ant-api03-XXXXXXXXX",
  "model": "claude-sonnet-4-6"
}
```

The app fetches this on every startup and caches it in Hive. If the network is
unavailable, it falls back to the cached key. The API key is NEVER bundled
inside the APK.

---

## 6. Adjust TA / DA Rates

Open `lib/config/ta_rates.dart`:
- `_mileageRates` — per-km rates by transport mode (RM)
- `contingentDailyRate` — daily rate for outstation allowance
- `_bands` — grade-level DA rate bands

---

## 7. Run the App

```bash
flutter run                     # debug
flutter build apk --release     # release APK
flutter build appbundle         # Play Store bundle
```

---

## 8. Android Permissions

The following permissions are required (already in `android/app/src/main/AndroidManifest.xml` — add if missing):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

For Android 13+, also add:
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

---

## 9. Common Issues

| Problem | Fix |
|---|---|
| Hive adapter not found | Run `build_runner build` |
| PDF text misaligned | Tune X/Y in `lib/config/form_layout.dart` |
| API key not loading | Check GitHub URL in `remote_config.dart`, ensure repo is accessible |
| Font not applied | Ensure `assets/fonts/*.ttf` files exist and match `pubspec.yaml` |
