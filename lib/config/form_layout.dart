// lib/config/form_layout.dart
// ─────────────────────────────────────────────────────────────────────────────
// X,Y coordinates (in PDF points) for overlaying text on the GA-31 form scans.
//
//   Page 1 → assets/images/ga31_page1.png  (Travelling Allowance Journal - front)
//   Page 2 → assets/images/ga31_page2.png  (Continuation table + Certificates)
//
// Coordinate system: origin (0,0) is the TOP-LEFT corner of the page, "top"
// increases DOWNWARDS — matching pw.Positioned(top:, left:) in the pdf package.
//
// These numbers were derived by measuring the scanned form images at 150 DPI
// (1 px = 0.48 pt, since 72/150 = 0.48). page1/page2 dimensions below match the
// scanned images' aspect ratio so BoxFit.fill does not distort them.
//
// ⚠️ CALIBRATION: Generate a test PDF and compare it against your physical
// GA-31 form (or print it and hold it against a real filled form). If a value
// prints slightly off, nudge the corresponding X/Y constant below by a few
// points and regenerate. This is normal — exact alignment depends a little on
// your printer/scanner margins.
//
// CONTINGENT BILL: prints directly below the TA table, on whichever page the
// TA table's last row + Grand Total ends on (page 1 or page 2, both still
// using the GA-31 scanned background — no separate blank page). The starting
// Y for the Contingent block is computed at render time from where the TA
// table actually ended, so the two tables never overlap regardless of how
// many TA rows there are. Adjust `contingentGapAfterTa` below if you want
// more/less breathing room between the two tables.
// ─────────────────────────────────────────────────────────────────────────────

class FormLayout {
  // ════════════════════════════════════════════════════════════════════════
  // PAGE SIZES (points) — must match scanned image aspect ratio
  // ════════════════════════════════════════════════════════════════════════
  static const double page1Width = 565.4;
  static const double page1Height = 792.0;
  static const double page2Width = 559.7;
  static const double page2Height = 792.0;

  // ════════════════════════════════════════════════════════════════════════
  // PAGE 1 — Header strip (employee / posting details)
  // ════════════════════════════════════════════════════════════════════════

  // Row: "शाखा/Branch ____  मंडल/जिला/Division/District ____  सदर मुकाम/HQ ____"
  static const double branchDivisionHqY = 84.0;
  static const double branchX = 58.0;
  static const double divisionX = 238.0;
  static const double headquartersX = 475.0;

  // Row: "...performed by Shri ____ for which allowance ____ 20__ is claimed"
  static const double shriRowY = 118.0;
  static const double employeeNameX = 166.0; // employee's name
  static const double monthX = 338.0; // month name (e.g. "June")
  static const double yearX = 454.0; // last 2 digits of year

  // Row: "पद/Designation ____ वेतन/Pay ____ नियुक्ति की तारीख/Date of appointment ____"
  static const double designationRowY = 134.0;
  static const double designationX = 96.0;
  static const double payX = 245.0;
  static const double dateOfAppointmentX = 485.0;

  // Row: "किस नियम से शासित/Rule by which governed ____"
  static const double ruleY = 150.0;
  static const double ruleX = 200.0;

  // ════════════════════════════════════════════════════════════════════════
  // PAGE 1 — TA Table (9 columns; col-5 splits From|To, col-9 splits Rs|Paise)
  // ════════════════════════════════════════════════════════════════════════
  static const double dateX = 38.0; // 1. महीना और तारीख / Month & date
  static const double vehicleX = 93.0; // 2. गाड़ी नं. / No. of Train
  static const double departureX = 128.0; // 3. प्रस्थान का समय / Time left
  static const double arrivalX = 162.0; // 4. पहुंचने का समय / Time arrived
  static const double fromX = 198.0; // 5a. से/From
  static const double toX = 261.0; // 5b. तक/To
  static const double kmX = 320.0; // 6. किलोमीटर / Kilometre
  static const double dayNightX = 359.0; // 7. दिन/रात / Day-Night
  static const double purposeX = 392.0; // 8. यात्रा का उद्देश्य / Object of Journey
  static const double purposeWidth = 78.0; // width of column 8 (for text wrap)
  static const double amountRsX = 474.0; // 9a. रुपये/Rs.
  static const double amountPaiseX = 510.0; // 9b. पैसे/Paise

  // Table body Y-bounds on page 1
  static const double firstRowY = 234.0; // top of first data row
  static const double tableBottomY1 = 705.0; // table's bottom border

  // ════════════════════════════════════════════════════════════════════════
  // PAGE 2 — Continuation table (same column X positions as page 1)
  // ════════════════════════════════════════════════════════════════════════
  static const double firstRowY2 = 70.0; // top of first data row
  static const double tableBottomY2 = 372.0; // table's bottom border

  // "मैं प्रमाणित करता हूँ कि श्री ____ बिल में दिये गये समय के लिए..."
  static const double certNameX = 116.0;
  static const double certNameY = 524.0;

  // ════════════════════════════════════════════════════════════════════════
  // Row sizing — one rowHeight/fontSize pair is chosen for the WHOLE table
  // (page 1 + page 2 combined) based on total entry count, so the table looks
  // consistent across both pages.
  // ════════════════════════════════════════════════════════════════════════
  static const double fontSizeNormal = 9.0; // up to ~19 rows
  static const double fontSizeMid = 8.0; // up to ~30 rows
  static const double fontSizeCompact = 7.0; // up to ~42 rows
  static const double fontSizeMin = 6.5; // 43+ rows

  static const double rowHeightMax = 24.0;
  static const double rowHeightMid = 18.0;
  static const double rowHeightMin = 13.0;
  static const double rowHeightCompact = 11.0;

  /// Row height (pt) for the given total number of TA entries.
  /// More entries → smaller spacing. Fewer entries → larger spacing.
  static double rowHeightForCount(int entryCount) {
    if (entryCount <= 19) return rowHeightMax;
    if (entryCount <= 30) return rowHeightMid;
    if (entryCount <= 42) return rowHeightMin;
    return rowHeightCompact;
  }

  /// Font size (pt) for the given total number of TA entries.
  static double fontSizeForRows(int rows) {
    if (rows <= 19) return fontSizeNormal;
    if (rows <= 30) return fontSizeMid;
    if (rows <= 42) return fontSizeCompact;
    return fontSizeMin;
  }

  /// How many table rows fit in the body of page 1 at the given row height.
  static int page1Capacity(double rowHeight) =>
      ((tableBottomY1 - firstRowY) / rowHeight).floor();

  /// How many table rows fit in the body of page 2 at the given row height.
  static int page2Capacity(double rowHeight) =>
      ((tableBottomY2 - firstRowY2) / rowHeight).floor();

  // ════════════════════════════════════════════════════════════════════════
  // Contingent bill — printed directly below the TA table on whichever
  // scanned page (1 or 2) the TA table's Grand Total row ended on. Uses the
  // same X column positions style as the TA table, sized to the same
  // dynamic row-height/font-size rules (more entries = tighter spacing).
  //
  // ⚠️ These X positions are a starting approximation — nudge them once you
  // can compare a generated PDF against the printed Contingent area of your
  // physical form.
  // ════════════════════════════════════════════════════════════════════════
  static const double contingentGapAfterTa = 18.0; // space below TA grand total
  static const double contingentDateX = 38.0;
  static const double contingentFromX = 130.0;
  static const double contingentToX = 220.0;
  static const double contingentKmX = 320.0;
  static const double contingentAmountX = 400.0;

  // Bottom limits for the Contingent block, mirroring the TA table bounds —
  // used to decide whether the Contingent rows still fit on the same page
  // as the TA total, or need to continue further down / onto page 2.
  static const double contingentBottomY1 = 705.0;
  static const double contingentBottomY2 = 372.0;

  /// Row height (pt) for the given total number of Contingent entries.
  /// Same compacting behaviour as the TA table.
  static double contingentRowHeightForCount(int entryCount) {
    if (entryCount <= 10) return rowHeightMax;
    if (entryCount <= 18) return rowHeightMid;
    if (entryCount <= 28) return rowHeightMin;
    return rowHeightCompact;
  }

  /// Font size (pt) for the given total number of Contingent entries.
  static double contingentFontSizeForRows(int rows) {
    if (rows <= 10) return fontSizeNormal;
    if (rows <= 18) return fontSizeMid;
    if (rows <= 28) return fontSizeCompact;
    return fontSizeMin;
  }
}
