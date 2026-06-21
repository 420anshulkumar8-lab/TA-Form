# Developer Setup Guide

## 1. Prerequisites

- Flutter SDK >= 3.2.0
- Android Studio or VS Code with Flutter extension

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

### How the layout works
- **Page 1** gets the header fields (name, designation, pay, HQ, etc.) and as
  many TA-table rows as fit in the table area on the front page.
- **Page 2** automatically receives any remaining TA rows as a continuation of
  the same table, plus the employee's name in the certificate paragraph.
- The Grand Total row is printed right after the last TA entry, on whichever
  page that entry landed on.
- **Contingent Bill** (if filled) prints directly below the TA table's Grand
  Total, on the same scanned page — no separate blank page. If it doesn't fit
  in the remaining space on that page, it continues onto page 2.
  Tune `contingentDateX/FromX/ToX/KmX/AmountX` and
  `contingentGapAfterTa` in `FormLayout` once you can compare a generated
  PDF against your physical form's Contingent area.

---

## 5. Adjust TA Rates

Open `lib/config/ta_rates.dart`. Amount is calculated from the journey
duration (departure → arrival) and the employee's Level (1-9):

| Duration       | Level 1–5 | Level 6–9 |
|----------------|-----------|-----------|
| up to 6 hours  | ₹187.5    | ₹300      |
| 6–12 hours     | ₹437.5    | ₹700      |
| above 12 hours | ₹625      | ₹1000     |

---

## 6. Run the App

```bash
flutter run                     # debug
flutter build apk --release     # release APK
flutter build appbundle         # Play Store bundle
```

---

## 7. Android Permissions

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

## 8. Common Issues

| Problem | Fix |
|---|---|
| Hive adapter not found | Run `build_runner build` |
| PDF text misaligned | Tune X/Y in `lib/config/form_layout.dart` |
| Contingent table overlaps TA table | Increase `contingentGapAfterTa` in `FormLayout` |
| Crop screen doesn't open / build error on `image_cropper` | Ensure `android/app/build.gradle.kts` has `compileSdk >= 34` and `minSdk >= 21` (already set in this project) |
