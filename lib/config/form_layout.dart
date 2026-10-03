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
  // Employee No. / Token No. — top-right corner of page 1 (10pt, left).
  static const double empNoX = 420;
  static const double empNoY = 8;
  static const double tokenNoX = 420;
  static const double tokenNoY = 18;
  static const double idFieldFontSize = 10.0;

  // PAGE 1 — Header strip (employee / posting details)
  // ════════════════════════════════════════════════════════════════════════

  // All profile-sourced header fields print at one uniform size/weight/
  // alignment: 11pt, bold, centered.
  static const double profileFieldFontSize = 11.0;

  // Row: "शाखा/Branch ____  मंडल/जिला/Division/District ____  सदर मुकाम/HQ ____"
  static const double branchY = 77; // was 78, moved up 1pt
  static const double branchX = 89.1;
  static const double branchWidth = 90;
  static const String branchAlign = 'center';
  static const double divisionY = 77.5; // was 78, moved up 0.5pt
  static const double divisionX = 249.4;
  static const double divisionWidth = 130;
  static const String divisionAlign = 'center';
  static const double headquartersY = 78;
  static const double headquartersX = 457.5; // +1
  static const double headquartersWidth = 90;
  static const String headquartersAlign = 'center';

  // Row: "...performed by Shri ____ for which allowance ____ 20__ is claimed"
  static const double shriRowY = 109.9; // was 111.9, moved up 2pt
  static const double employeeNameX = 179.9; // employee's name
  static const double employeeNameWidth = 150;
  static const String employeeNameAlign = 'center';
  static const double monthX = 387.6; // month name (e.g. "June")
  static const double monthWidth = 100;
  static const String monthAlign = 'center';
  static const double yearX = 459.6; // was 458.6, moved right 1pt
  static const double yearY = 111.9; // unchanged (no Y shift requested)
  static const double yearWidth = 40;
  static const String yearAlign = 'center';

  // Row: "पद/Designation ____ वेतन/Pay ____ नियुक्ति की तारीख/Date of appointment ____"
  static const double designationRowY = 126.5; // was 128.5, moved up 2pt
  static const double designationX = 88;
  static const double designationWidth = 130;
  static const String designationAlign = 'center';
  static const double payX = 229.3;
  static const double payWidth = 90;
  static const String payAlign = 'center';
  static const double dateOfAppointmentX = 446.6;
  static const double dateOfAppointmentY = 127.5; // was 128.5, moved up 1pt
  static const double dateOfAppointmentWidth = 90;
  static const String dateOfAppointmentAlign = 'center';

  // Row: "किस नियम से शासित/Rule by which governed ____"
  static const double ruleY = 143; // was 145, moved up 2pt
  static const double ruleX = 224.9;
  static const double ruleWidth = 200;
  static const String ruleAlign = 'center';
  // Fixed value printed for this field — not sourced from employee profile.
  // Keep this at or under 45 characters (may be replaced with a specific
  // rule reference later).
  static const String ruleText = 'Railway Rule';

  // ════════════════════════════════════════════════════════════════════════
  // PAGE 1 — TA Table (9 columns; col-5 splits From|To, col-9 splits Rs|Paise)
  // ════════════════════════════════════════════════════════════════════════
  static const double dateX = 27; // 1. महीना और तारीख / Month & date
  static const double vehicleX = 92; // 2. गाड़ी नं. / No. of Train
  static const double departureX = 126; // 3. प्रस्थान का समय / Time left
  static const double arrivalX = 159; // 4. पहुंचने का समय / Time arrived
  static const double fromX = 195; // 5a. से/From
  static const double toX = 259; // 5b. तक/To
  static const double kmX = 318; // 6. किलोमीटर / Kilometre
  static const double dayNightX = 357; // 7. दिन/रात / Day-Night
  static const double purposeX = 390; // 8. यात्रा का उद्देश्य / Object of Journey
  static const double purposeWidth = 80.0; // width of column 8 (for text wrap)
  static const String purposeAlign = 'left';
  static const double amountRsX = 472; // 9a. रुपये/Rs.
  static const double amountPaiseX = 508; // 9b. पैसे/Paise

  // Table body Y-bounds on page 1
  static const double firstRowY = 241.3; // top of first data row (was 239.3, +2)
  static const double tableBottomY1 = 705.0; // table's bottom border

  // ════════════════════════════════════════════════════════════════════════
  // PAGE 2 — Continuation table (same column X positions as page 1)
  // ════════════════════════════════════════════════════════════════════════
  // Page 2's scan is shifted LEFT vs page 1: every table X below (date …
  // paise, plus the Purpose/Amount brackets) is printed at (page-1 X − this).
  static const double page2XShift = 20.3;
  // Time columns (Time left + Time arrived), BOTH pages: width +1 pt each.
  static const double timeWidthExtra = 1.0;
  // Page 1 only: nudge From / To columns RIGHT (pt). Widths unchanged.
  static const double page1FromShift = 1.0;
  static const double page1ToShift = 1.0;
  // Page 1 only: Purpose bracket (after Day/Night) RIGHT. 388 + 1.4 - 0.8 = 388.6
  static const double page1PurposeBracketShift = 1.4;
  // Extra LEFT shift on page 2 only, on top of page2XShift (pt):
  static const double page2OtherNudge = 0.5; // RIGHT: Date, Vehicle, Times, Km, Amount text
  static const double page2FromShift = 0.5; // (was 1.0, +0.5 right)
  static const double page2ToShift = 1.7; // (was 2.0, +0.3 right)
  static const double page2KmShift = 3.0; // (+ page2OtherNudge)
  static const double page2DayNightShift = 2.5; // (was 3.0, +0.5 right)
  static const double page2PurposeShift = 2.6; // Purpose TEXT only (was 3.0, +0.4 right)
  static const double page2AmountShift = 3.0; // Rs + Paise text (+ page2OtherNudge)
  // Brackets: LEFT shift from (page-1 X − page2XShift), independent of text.
  static const double page2PurposeBracketShift = 6.0; // total 26.3 left
  static const double page2AmountBracketShift = 4.0; // total 24.3 left (was 6.0, +2 right)
  // ════════════════════════════════════════════════════════════════════════
  // GRAND TOTAL — ALWAYS printed on PAGE 2 at these fixed absolute
  // coordinates (11pt, bold, center). Page-2 column shifts do NOT apply.
  // ════════════════════════════════════════════════════════════════════════
  static const String grandTotalLabel = 'Grand Total';
  static const double grandTotalFontSize = 11.0;
  static const double grandTotalY = 358.0;
  static const double grandTotalLabelX = 367.0;
  static const double grandTotalLabelWidth = 81.0;
  static const double grandTotalRsX = 449.5;
  static const double grandTotalRsWidth = 35.0;
  static const double grandTotalPaiseX = 488.0;
  static const double grandTotalPaiseWidth = 20.0;
  static const double firstRowY2 = 78.7; // top of first data row (was 76.7, +2)
  static const double tableBottomY2 = 372.0; // table's bottom border

  // "मैं प्रमाणित करता हूँ कि श्री ____ बिल में दिये गये समय के लिए..."
  static const double certNameX = 142.0;
  static const double certNameY = 565.0;
  static const double certNameWidth = 165;
  static const String certNameAlign = 'center';

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
  // Date / Km / Purpose / Amount use the TA table's own X + widths (and the
  // same page-2 shifts). Only From / To are contingent-specific: wide, with
  // a small gap between them (page-1 X, shifted like TA From / To on p.2):
  //   Date ends 90 → From starts 93 | From 93..202 | gap 4 | To 206..315 |
  //   Km starts 318.
  static const double contingentFromX = 93.0;
  static const double contingentFromWidth = 109.0;
  static const double contingentToX = 206.0;
  static const double contingentToWidth = 109.0;
  // "Contingent Bill:" line + column-label line.
  static const double contingentHeaderFontSize = 10.0; // bold
  static const double contingentHeaderRowHeight = 20.0; // line → next line
  static const double contingentHeaderBlockHeight = 40.0; // both lines

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
