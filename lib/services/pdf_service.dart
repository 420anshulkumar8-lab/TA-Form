// lib/services/pdf_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Generates a filled GA-31 (Travelling Allowance Journal) PDF.
//
//   Page 1 = assets/images/ga31_page1.png   (front of the form)
//   Page 2 = assets/images/ga31_page2.png   (continuation table + certificates)
//
// Text is overlaid on the scanned form images at X,Y positions from
// FormLayout. TA data is a list of Trips, each with one or more legs; all
// legs of a trip share one Purpose, printed once vertically centered next
// to that trip's leg rows, with a small curly-bracket connecting them — only
// in the PDF (the Form View shows its own merged-cell look separately).
//
// If a TA month has more legs than fit on page 1, the remaining legs
// automatically continue onto page 2's table — even mid-trip if needed; the
// bracket/Purpose is drawn relative to wherever that trip's legs actually
// landed. The Contingent Bill (if present) is printed directly below the TA
// table's Grand Total, on whichever scanned page that total ends up on.
//
// Developer note: tweak FormLayout constants after a test print to fine-tune
// alignment against your physical form.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../config/form_layout.dart';
import '../models/trip_model.dart';
import '../models/contingent_model.dart';
import '../models/employee_profile.dart';
import '../models/ta_session.dart';

/// Rupees + Paise split for printing into the form's two Rate sub-columns.
class _Amount {
  final String rupees;
  final String paise;
  const _Amount(this.rupees, this.paise);
}

/// A single printed leg, flattened out of its TripGroup, plus which trip
/// it belongs to and whether it's the first/last leg of that trip (needed
/// to know where to draw the Purpose bracket).
class _FlatLeg {
  final TripRow leg;
  final int tripIndex;
  final String purpose;
  final bool isFirstOfTrip;
  final bool isLastOfTrip;
  final double amount; // date-level amount from TaFormData.dateAmounts
  const _FlatLeg({
    required this.leg,
    required this.tripIndex,
    required this.purpose,
    required this.isFirstOfTrip,
    required this.isLastOfTrip,
    this.amount = 0,
  });
}

class PdfService {
  // ── Main entry point ──────────────────────────────────────────────────────
  static Future<String> generatePdf({
    required TaSession session,
    required EmployeeProfile profile,
  }) async {
    final pdf = pw.Document();

    final bg1 = await _loadAsset('assets/images/ga31_page1.png');
    final bg2 = await _loadAsset('assets/images/ga31_page2.png');

    final hasTa = session.formDataTa != null;
    final hasContingent = session.formDataContingent != null;

    TaFormData? taData;
    ContingentFormData? contingentData;

    if (hasTa) taData = TaFormData.fromJson(session.formDataTa!);
    if (hasContingent) {
      contingentData = ContingentFormData.fromJson(session.formDataContingent!);
    }

    final flatLegs = _flattenTrips(
        taData?.trips ?? <TripGroup>[],
        taData?.dateAmounts ?? <String, double>{});

    // ── TEST: pre-pass to compute how much extra height (if any) each
    //    DYNAMIC-mode trip's Purpose needs beyond its normal merged-rows
    //    height, so that trip's full text is never clipped. This extra
    //    height is injected as a gap AFTER that trip's last row, pushing
    //    every subsequent row down. CLIP-mode trips contribute 0 extra —
    //    their Purpose stays clipped to the normal block height instead.
    //    _extraHeightAfterRow[k] = extra gap inserted immediately after
    //    row k finishes (0.0 if none).
    final extraHeightAfterRow = <int, double>{};
    {
      int i = 0;
      while (i < flatLegs.length) {
        final tripIndex = flatLegs[i].tripIndex;
        int j = i;
        while (j < flatLegs.length && flatLegs[j].tripIndex == tripIndex) {
          j++;
        }
        // Normal (non-extended) height this trip's rows occupy.
        double normalHeight = 0;
        for (int k = i; k < j; k++) {
          normalHeight += _testRowHeightForRow(k);
        }
        if (_isDynamicModeForTrip(tripIndex)) {
          final purpose = flatLegs[i].purpose;
          final tripFontSize = _testFontSizeForRow(i);
          final extra = _dynamicExtraHeightForPurpose(
              purpose, normalHeight, tripFontSize);
          if (extra > 0) {
            extraHeightAfterRow[j - 1] = extra;
          }
        }
        i = j;
      }
    }

    /// Cumulative Y for `rowIndex`, accounting for both each row's own
    /// (possibly-per-block-varying) height AND any dynamic-mode extra gaps
    /// injected after earlier rows.
    double cumulativeYWithGaps(double startY, int rowIndex) {
      double y = startY;
      for (int k = 0; k < rowIndex; k++) {
        y += _testRowHeightForRow(k);
        y += extraHeightAfterRow[k] ?? 0.0;
      }
      return y;
    }

    // ── Decide row height / font size for the WHOLE TA table, then split
    //    legs between page 1 and page 2 based on how many fit on page 1. ───
    // TEST MODE: row height/font size now vary per-row (see the blocks
    // defined near _legRows), so page-1 capacity is computed by walking
    // cumulative heights (including dynamic-mode gaps) instead of a single
    // uniform rowHeight. `rowHeight` and `fontSize` below are kept only as
    // fallback values passed into helper signatures that still expect a
    // default.
    const rowHeight = 24.0; // unused fallback while test blocks are active
    const fontSize = 9.0; // unused fallback while test blocks are active

    int page1Cap = 0;
    {
      double y = FormLayout.firstRowY;
      while (page1Cap < flatLegs.length) {
        final h = _testRowHeightForRow(page1Cap);
        if (y + h > FormLayout.tableBottomY1) break;
        y += h;
        y += extraHeightAfterRow[page1Cap] ?? 0.0;
        page1Cap++;
      }
    }

    final page1Legs =
        flatLegs.length <= page1Cap ? flatLegs : flatLegs.sublist(0, page1Cap);
    final page2Legs =
        flatLegs.length <= page1Cap ? <_FlatLeg>[] : flatLegs.sublist(page1Cap);

    final taEndsOnPage2 = page2Legs.isNotEmpty;

    // ── Where does the TA table (incl. Grand Total) end? Used as the start
    //    Y for the Contingent block on that same page. ──────────────────────
    // NOTE (test mode): if the table spills onto page 2, page 2's rows
    // continue the SAME absolute block sequence as page 1 (row indices
    // page1Cap..flatLegs.length-1), so we sum their individual heights
    // directly rather than reusing _testCumulativeY's from-zero indexing.
    double taEndY;
    if (taEndsOnPage2) {
      double h2 = 0;
      for (int k = page1Cap; k < flatLegs.length; k++) {
        h2 += _testRowHeightForRow(k);
        h2 += extraHeightAfterRow[k] ?? 0.0;
      }
      taEndY = FormLayout.firstRowY2 + h2 + 4;
    } else {
      taEndY = cumulativeYWithGaps(FormLayout.firstRowY, page1Legs.length) + 4;
    }

    // ── Contingent sizing ──────────────────────────────────────────────────
    // TEST MODE: same 7-block calibration as the TA table. Total height =
    // the header line (Block 1's height) + each entry's own block height.
    final contingentEntries = contingentData?.entries ?? <ContingentEntry>[];
    const contingentRowHeight = 24.0; // unused fallback while test blocks are active
    const contingentFontSize = 9.0; // unused fallback while test blocks are active
    double contingentTotalHeight = _testRowHeightForRow(0); // header line
    for (int k = 0; k < contingentEntries.length; k++) {
      contingentTotalHeight += _testRowHeightForRow(k);
    }
    final contingentStartY = taEndY + FormLayout.contingentGapAfterTa;
    final contingentBottomLimit = taEndsOnPage2
        ? FormLayout.contingentBottomY2
        : FormLayout.contingentBottomY1;
    final contingentFitsAfterTa = !taEndsOnPage2 &&
        (contingentStartY + contingentTotalHeight + 20) <= contingentBottomLimit;
    final contingentOnPage1 = !taEndsOnPage2 && contingentFitsAfterTa;
    final contingentOnPage2WithTa = taEndsOnPage2;
    final contingentStartYFinal = contingentOnPage1
        ? contingentStartY
        : (contingentOnPage2WithTa
            ? contingentStartY
            : FormLayout.firstRowY2);

    // ── PAGE 1 — front of GA-31 ──────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          FormLayout.page1Width,
          FormLayout.page1Height,
        ),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            if (bg1 != null)
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(bg1), fit: pw.BoxFit.fill),
              ),
            ..._headerOverlay(profile, session),
            ..._legRows(page1Legs, rowHeight, fontSize, FormLayout.firstRowY,
                extraHeightAfterRow: extraHeightAfterRow),
            ..._purposeOverlay(page1Legs, rowHeight, fontSize, FormLayout.firstRowY,
                extraHeightAfterRow: extraHeightAfterRow),
            ..._amountOverlay(page1Legs, rowHeight, fontSize, FormLayout.firstRowY,
                extraHeightAfterRow: extraHeightAfterRow),
            if (!taEndsOnPage2 && taData != null)
              ..._totalOverlay(taData, taEndY, fontSize),
            if (contingentOnPage1 && contingentData != null)
              ..._contingentOverlay(contingentData, contingentStartYFinal,
                  contingentRowHeight, contingentFontSize),
          ],
        ),
      ),
    );

    // ── PAGE 2 — continuation table + certificates ───────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          FormLayout.page2Width,
          FormLayout.page2Height,
        ),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            if (bg2 != null)
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(bg2), fit: pw.BoxFit.fill),
              ),
            ..._legRows(page2Legs, rowHeight, fontSize, FormLayout.firstRowY2,
                rowOffset: page1Cap, extraHeightAfterRow: extraHeightAfterRow),
            ..._purposeOverlay(page2Legs, rowHeight, fontSize, FormLayout.firstRowY2,
                rowOffset: page1Cap, extraHeightAfterRow: extraHeightAfterRow),
            ..._amountOverlay(page2Legs, rowHeight, fontSize, FormLayout.firstRowY2,
                rowOffset: page1Cap, extraHeightAfterRow: extraHeightAfterRow),
            if (taEndsOnPage2 && taData != null)
              ..._totalOverlay(taData, taEndY, fontSize),
            if (!contingentOnPage1 && contingentData != null)
              ..._contingentOverlay(contingentData, contingentStartYFinal,
                  contingentRowHeight, contingentFontSize),
            // "मैं प्रमाणित करता हूँ कि श्री ____" — officer's name
            _overlayText(
              profile.name,
              FormLayout.certNameX,
              FormLayout.certNameY,
              FormLayout.fontSizeNormal,
            ),
          ],
        ),
      ),
    );

    // ── Save to app documents directory ───────────────────────────────────
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'TA_${session.month}_${session.year}_${profile.employeeNo}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  // ── Flatten Trips → legs, tagging each with its trip's shared Purpose and
  //    its first/last-of-trip position (needed for the bracket later). ──────
  static List<_FlatLeg> _flattenTrips(
      List<TripGroup> trips, Map<String, double> dateAmounts) {
    final flat = <_FlatLeg>[];
    for (int t = 0; t < trips.length; t++) {
      final trip = trips[t];
      for (int i = 0; i < trip.legs.length; i++) {
        final leg = trip.legs[i];
        flat.add(_FlatLeg(
          leg: leg,
          tripIndex: t,
          purpose: trip.purpose,
          isFirstOfTrip: i == 0,
          isLastOfTrip: i == trip.legs.length - 1,
          amount: dateAmounts[leg.date] ?? 0.0,
        ));
      }
    }
    return flat;
  }

  // ── Header strip overlay (page 1 only) ────────────────────────────────────
  static List<pw.Widget> _headerOverlay(
      EmployeeProfile profile, TaSession session) {
    final yearShort = session.year.length >= 2
        ? session.year.substring(session.year.length - 2)
        : session.year;

    // ═══════════════════════════════════════════════════════════════════════
    // TEMP CALIBRATION TEST — each header field pinned to a different font
    // size (8.5 / 9.0 / 9.5 / 10.0 / 10.5 pt) so you can print once and see
    // which size reads best on the physical form. Field → size mapping:
    //   Branch               → 8.5pt
    //   Division              → 9.0pt
    //   Headquarters          → 9.5pt
    //   Employee Name         → 10.0pt
    //   Month                 → 10.5pt
    //   Year                  → 8.5pt   (cycle repeats)
    //   Designation           → 9.0pt
    //   Pay                   → 9.5pt
    //   Date of Appointment   → 10.0pt
    // Once you've picked a winner, tell me the size and I'll set every
    // field back to that single FormLayout.fontSizeNormal-style constant.
    // ═══════════════════════════════════════════════════════════════════════
    return [
      _overlayText(profile.department, FormLayout.branchX,
          FormLayout.branchDivisionHqY, 8.5),
      _overlayText(profile.division, FormLayout.divisionX,
          FormLayout.branchDivisionHqY, 9.0),
      _overlayText(profile.headquarter, FormLayout.headquartersX,
          FormLayout.branchDivisionHqY, 9.5),
      _overlayText(profile.name, FormLayout.employeeNameX,
          FormLayout.shriRowY, 10.0),
      _overlayText(_capitalize(session.month), FormLayout.monthX,
          FormLayout.shriRowY, 10.5),
      _overlayText(yearShort, FormLayout.yearX, FormLayout.shriRowY, 8.5),
      _overlayText(profile.designation, FormLayout.designationX,
          FormLayout.designationRowY, 9.0),
      _overlayText(
        profile.basicPay > 0 ? profile.basicPay.toStringAsFixed(0) : '',
        FormLayout.payX,
        FormLayout.designationRowY,
        9.5,
      ),
      _overlayText(profile.dateOfAppointment, FormLayout.dateOfAppointmentX,
          FormLayout.designationRowY, 10.0),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMP CALIBRATION TEST — ROUND 2. Narrowed down from the earlier 7-block
  // test to the 5 font sizes you want to compare directly, each with its
  // own proportional (2x) row height. The TA table is split into 5 blocks
  // of 3 rows each. Once you've picked a winner, tell me which block number
  // looked best and I'll set FormLayout's font/rowHeight to one fixed pair
  // (removing this test scaffolding).
  //
  //   Block 1 (rows 1-3):   9.0pt font,  18pt row height
  //   Block 2 (rows 4-6):   9.5pt font,  19pt row height
  //   Block 3 (rows 7-9):   10.0pt font, 20pt row height
  //   Block 4 (rows 10-12): 10.5pt font, 21pt row height
  //   Block 5 (rows 13-15): 11.0pt font, 22pt row height
  //
  // If you add MORE than 15 rows, everything past row 15 just repeats
  // Block 5's sizing (11pt / 22pt) rather than crashing.
  // ═══════════════════════════════════════════════════════════════════════
  static const List<double> _testFontSizes = [9.0, 9.5, 10.0, 10.5, 11.0];
  static const List<double> _testRowHeights = [18.0, 19.0, 20.0, 21.0, 22.0];
  static const int _testRowsPerBlock = 3;

  // NOTE: rowIndex here must be the row's ABSOLUTE position in the full TA
  // table (0 = first leg overall), not its position within page1Legs/
  // page2Legs. For the 15-row test case this table entirely fits on page 1
  // (5 blocks × 3 rows × up to 22pt ≈ 99pt, well under the ~343pt page-1
  // table area), so page2Legs stays empty and this distinction doesn't
  // matter in practice — but if you ever test with enough rows to spill
  // onto page 2, make sure callers pass the absolute index, not a
  // page-local one.
  static double _testFontSizeForRow(int rowIndex) {
    final block = (rowIndex ~/ _testRowsPerBlock).clamp(0, _testFontSizes.length - 1);
    return _testFontSizes[block];
  }

  static double _testRowHeightForRow(int rowIndex) {
    final block = (rowIndex ~/ _testRowsPerBlock).clamp(0, _testRowHeights.length - 1);
    return _testRowHeights[block];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMP TEST — bold vs normal weight, compared block-wise:
  //   Rows 1-9   (Blocks 1-3 / 9.0-10.0pt): BOLD
  //   Rows 10-15 (Blocks 4-5 / 10.5-11.0pt): normal weight
  // Applies to every leg-row text field (Date, Train No, Dep, Arr, From, To,
  // Km, Day/Night) and to that row's Purpose/Amount text.
  // ═══════════════════════════════════════════════════════════════════════
  static const int _boldUntilRow = 9; // rows 0-8 (i.e. rows 1-9) are bold

  static bool _testBoldForRow(int rowIndex) => rowIndex < _boldUntilRow;

  // ═══════════════════════════════════════════════════════════════════════
  // TEMP TEST — Purpose overflow handling, compared side by side:
  //   Trip 1 & Trip 2 → DYNAMIC mode: if a Purpose is too long for its
  //     merged box at the fixed row height, the box grows taller to fit
  //     the full text, and every row/trip after it is pushed down by
  //     however much extra height was needed (a visible gap may appear
  //     between this trip's rows and the next).
  //   Trip 3 onward → CLIP mode: row heights never change; if a Purpose is
  //     too long, it's safely clipped instead (font size stays fixed).
  // Change `_dynamicTripCount` below to compare a different split.
  // ═══════════════════════════════════════════════════════════════════════
  static const int _dynamicTripCount = 2;

  static bool _isDynamicModeForTrip(int tripIndex) =>
      tripIndex < _dynamicTripCount;

  /// How many characters of Purpose text fit on one line of the merged box
  /// at this font size (Courier ≈ 0.6× font-size per character).
  static int _purposeCharsPerLine(double fontSize) =>
      (FormLayout.purposeWidth / (fontSize * 0.6)).floor().clamp(1, 999);

  /// How many lines `text` will actually wrap to at this font size (a rough
  /// word-wrap estimate — good enough for deciding how much extra height a
  /// long Purpose needs, without needing the PDF engine's real layout pass).
  static int _purposeWrappedLineCount(String text, double fontSize) {
    if (text.isEmpty) return 1;
    final maxChars = _purposeCharsPerLine(fontSize);
    final words = text.split(RegExp(r'\s+'));
    int lines = 1;
    int lineLen = 0;
    for (final word in words) {
      final addLen = (lineLen == 0 ? 0 : 1) + word.length;
      if (lineLen + addLen > maxChars) {
        lines++;
        lineLen = word.length;
      } else {
        lineLen += addLen;
      }
    }
    return lines;
  }

  /// In DYNAMIC mode, the extra height (beyond the normal merged-rows
  /// height) this trip's Purpose needs so its full text isn't clipped.
  /// Returns 0 if the text already fits (no extra height needed).
  static double _dynamicExtraHeightForPurpose(
    String purpose,
    double normalBlockHeight,
    double fontSize,
  ) {
    final neededLines = _purposeWrappedLineCount(purpose, fontSize);
    final lineHeight = fontSize * 1.15;
    final neededHeight = neededLines * lineHeight;
    final extra = neededHeight - normalBlockHeight;
    return extra > 0 ? extra : 0.0;
  }

  /// Cumulative Y position of `rowIndex` (0-based) given each row before it
  /// may have had a DIFFERENT height (since each 3-row block uses its own
  /// row height in this test).
  static double _testCumulativeY(double startY, int rowIndex) {
    double y = startY;
    for (int k = 0; k < rowIndex; k++) {
      y += _testRowHeightForRow(k);
    }
    return y;
  }

  // ── Leg rows (everything except Purpose column) ───────────────────────────
  // `rowOffset`: the ABSOLUTE index of flatLegs[0] within the full TA table
  // (0 for page 1; page1Cap for page 2), so per-row font/height/gap lookups
  // stay correct even when the table spans two pages.
  // `extraHeightAfterRow`: dynamic-mode gaps, keyed by ABSOLUTE row index.
  static List<pw.Widget> _legRows(
    List<_FlatLeg> flatLegs,
    double rowHeight,
    double fontSize,
    double startY, {
    int rowOffset = 0,
    Map<int, double> extraHeightAfterRow = const {},
  }) {
    final widgets = <pw.Widget>[];
    double y = startY;

    for (int localIndex = 0; localIndex < flatLegs.length; localIndex++) {
      final rowIndex = localIndex + rowOffset;
      final flat = flatLegs[localIndex];
      final leg = flat.leg;
      // TEST: per-block font/row-height instead of the single shared values.
      fontSize = _testFontSizeForRow(rowIndex);
      rowHeight = _testRowHeightForRow(rowIndex);
      final rowBold = _testBoldForRow(rowIndex);

      if (leg.vehicleEntryType == VehicleEntryType.halt) {
        // ── Halt row: Date stays normal; a single dashed line runs from
        // Train/Veh No. through to Day/Night (spanning all the columns that
        // don't apply to a halt), with "Halt at X" centered on top of it.
        widgets.add(_overlayText(leg.date, FormLayout.dateX, y, fontSize,
            bold: rowBold));

        final dashLineWidth =
            (FormLayout.dayNightX + 28) - FormLayout.vehicleX;
        widgets.add(pw.Positioned(
          left: FormLayout.vehicleX,
          top: y + (fontSize * 0.9),
          child: pw.SizedBox(
            width: dashLineWidth,
            child: pw.Text(
              '-' * (dashLineWidth / (fontSize * 0.52)).round(),
              style: pw.TextStyle(
                  font: rowBold ? pw.Font.courierBold() : pw.Font.courier(),
                  fontSize: fontSize),
              overflow: pw.TextOverflow.clip,
              maxLines: 1,
            ),
          ),
        ));

        final haltText = leg.vehicleNumber.isEmpty
            ? 'Halt'
            : 'Halt at ${leg.vehicleNumber}';
        widgets.add(_overlayTextBox(
          haltText,
          FormLayout.vehicleX,
          y,
          fontSize,
          width: FormLayout.purposeX - FormLayout.vehicleX,
          textAlign: pw.TextAlign.center,
          bold: rowBold,
        ));
      } else {
        // ── Normal journey row
        widgets.add(_overlayText(leg.date, FormLayout.dateX, y, fontSize,
            bold: rowBold));
        widgets.add(_overlayText(leg.vehicleNumber, FormLayout.vehicleX, y,
            fontSize, bold: rowBold));
        widgets.add(_overlayText(leg.departureTime, FormLayout.departureX, y,
            fontSize, bold: rowBold));
        widgets.add(_overlayText(leg.arrivalTime, FormLayout.arrivalX, y,
            fontSize, bold: rowBold));
        widgets.add(_overlayText(leg.fromLocation, FormLayout.fromX, y,
            fontSize, bold: rowBold));
        widgets.add(_overlayText(leg.toLocation, FormLayout.toX, y, fontSize,
            bold: rowBold));
        widgets.add(_overlayText(
            leg.distanceKm == 0 ? '' : leg.distanceKm.toStringAsFixed(0),
            FormLayout.kmX, y, fontSize,
            bold: rowBold));
        widgets.add(_overlayText(leg.dayNight, FormLayout.dayNightX, y,
            fontSize, bold: rowBold));
      }

      y += rowHeight;
      y += extraHeightAfterRow[rowIndex] ?? 0.0;
    }

    return widgets;
  }

  // ── Amount column — one merged entry per DATE (not per trip), vertically
  //    centered across every row that shares that date, even when those
  //    rows belong to different trips and are adjacent only because one
  //    trip's last leg and the next trip's first leg happen to share a
  //    date (e.g. Trip 1 ends 2-Mar, Trip 2 starts 2-Mar → one merged
  //    Amount box spanning both rows, centered on the combined block).
  //    Mirrors _purposeOverlay's centering approach but groups by date
  //    instead of by trip. Only legs present on THIS page are considered,
  //    since a merge can't visually span two separate PDF pages. ──────────
  static List<pw.Widget> _amountOverlay(
    List<_FlatLeg> flatLegs,
    double rowHeight,
    double fontSize,
    double startY, {
    int rowOffset = 0,
    Map<int, double> extraHeightAfterRow = const {},
  }) {
    final widgets = <pw.Widget>[];
    if (flatLegs.isEmpty) return widgets;

    double cumulativeY(int localIndex) {
      double y = startY;
      for (int k = 0; k < localIndex; k++) {
        y += _testRowHeightForRow(k + rowOffset);
        y += extraHeightAfterRow[k + rowOffset] ?? 0.0;
      }
      return y;
    }

    int i = 0;
    while (i < flatLegs.length) {
      final date = flatLegs[i].leg.date;

      // Find the contiguous run of legs (within this page) sharing this
      // date, regardless of which trip they belong to.
      int j = i;
      while (j < flatLegs.length && flatLegs[j].leg.date == date) {
        j++;
      }
      final legCountOnThisPage = j - i;
      // TEST: rows in this run may span different calibration blocks, each
      // with its own row height, so the block's total height is the sum of
      // each individual row's height rather than a uniform rowHeight * count.
      final blockTopY = cumulativeY(i);
      double blockHeight = 0;
      for (int k = i; k < j; k++) {
        blockHeight += _testRowHeightForRow(k + rowOffset);
      }
      // Use the font size of this block's FIRST row for the merged text.
      fontSize = _testFontSizeForRow(i + rowOffset);
      final rowBold = _testBoldForRow(i + rowOffset);

      if (date.isNotEmpty) {
        final amt = _splitAmount(flatLegs[i].amount);

        // Curly-bracket connector only drawn when this date spans more than
        // 1 row on this page — a single-row date just gets plain centered
        // text, matching how Purpose's bracket behaves. Drawn as an actual
        // vector shape so it always spans the full block height correctly.
        if (legCountOnThisPage > 1) {
          widgets.add(_drawnBracket(
            left: FormLayout.amountRsX - 10,
            top: blockTopY,
            height: blockHeight,
          ));
        }

        widgets.add(pw.Positioned(
          left: FormLayout.amountRsX,
          top: blockTopY,
          child: pw.SizedBox(
            height: blockHeight,
            child: pw.Center(
              child: pw.Text(
                amt.rupees,
                style: pw.TextStyle(
                    font: rowBold ? pw.Font.courierBold() : pw.Font.courier(),
                    fontSize: fontSize),
              ),
            ),
          ),
        ));
        widgets.add(pw.Positioned(
          left: FormLayout.amountPaiseX,
          top: blockTopY,
          child: pw.SizedBox(
            height: blockHeight,
            child: pw.Center(
              child: pw.Text(
                amt.paise,
                style: pw.TextStyle(
                    font: rowBold ? pw.Font.courierBold() : pw.Font.courier(),
                    fontSize: fontSize),
              ),
            ),
          ),
        ));
      }

      i = j;
    }

    return widgets;
  }

  // ── Purpose column — one merged entry per Trip, vertically centered next
  //    to that trip's legs, with a small curly-bracket spanning multi-leg
  //    trips. Handles trips that got split across page 1/page 2 by only
  //    drawing the bracket/text for the legs present on THIS page's list. ──
  static List<pw.Widget> _purposeOverlay(
    List<_FlatLeg> flatLegs,
    double rowHeight,
    double fontSize,
    double startY, {
    int rowOffset = 0,
    Map<int, double> extraHeightAfterRow = const {},
  }) {
    final widgets = <pw.Widget>[];
    if (flatLegs.isEmpty) return widgets;

    double cumulativeY(int localIndex) {
      double y = startY;
      for (int k = 0; k < localIndex; k++) {
        y += _testRowHeightForRow(k + rowOffset);
        y += extraHeightAfterRow[k + rowOffset] ?? 0.0;
      }
      return y;
    }

    int i = 0;
    while (i < flatLegs.length) {
      final tripIndex = flatLegs[i].tripIndex;
      // Find the contiguous run of legs (within this page) belonging to
      // the same trip.
      int j = i;
      while (j < flatLegs.length && flatLegs[j].tripIndex == tripIndex) {
        j++;
      }
      final legCountOnThisPage = j - i;
      // TEST: same cumulative-height approach as _amountOverlay, since each
      // 3-row calibration block has its own row height.
      final blockTopY = cumulativeY(i);
      double normalBlockHeight = 0;
      for (int k = i; k < j; k++) {
        normalBlockHeight += _testRowHeightForRow(k + rowOffset);
      }
      fontSize = _testFontSizeForRow(i + rowOffset);
      final rowBold = _testBoldForRow(i + rowOffset);
      final purpose = flatLegs[i].purpose;
      final isDynamic = _isDynamicModeForTrip(tripIndex);

      // DYNAMIC mode: the box grows to whatever height the full text needs
      // (the extra was already reserved as a gap by the pre-pass, so this
      // box visually fills that gap instead of leaving it empty).
      // CLIP mode: box stays exactly the normal merged-rows height; text
      // beyond that is safely clipped rather than resized or overflowing.
      final blockHeight = isDynamic
          ? normalBlockHeight +
              _dynamicExtraHeightForPurpose(purpose, normalBlockHeight, fontSize)
          : normalBlockHeight;

      if (purpose.isNotEmpty) {
        // Curly-bracket connector only drawn when this trip has more than 1 leg on
        // this page — a single-leg trip just gets plain centered text. Drawn
        // as an actual vector shape (not a `}` glyph) so it always spans the
        // full block height correctly, whether it's 2 rows or 6.
        if (legCountOnThisPage > 1) {
          widgets.add(_drawnBracket(
            left: FormLayout.purposeX - 10,
            top: blockTopY,
            height: blockHeight,
          ));
        }

        // Font size is ALWAYS fixed at `fontSize` — never shrunk — so every
        // Purpose entry on the form looks visually consistent.
        //   DYNAMIC trips: box height already grew to fit the full text
        //     above, so no clipping should ever be needed here.
        //   CLIP trips: box stays at the normal height; text beyond that is
        //     safely clipped (never overflows/crashes the PDF).
        widgets.add(pw.Positioned(
          left: FormLayout.purposeX,
          top: blockTopY,
          child: pw.SizedBox(
            width: FormLayout.purposeWidth,
            height: blockHeight,
            child: pw.Center(
              child: pw.Text(
                purpose,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: rowBold ? pw.Font.courierBold() : pw.Font.courier(),
                    fontSize: fontSize),
                maxLines: isDynamic
                    ? null
                    : (normalBlockHeight / (fontSize * 1.15)).floor().clamp(1, 20),
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ),
        ));
      }

      i = j;
    }

    return widgets;
  }

  // ── Grand total row (printed right after the last TA leg) ────────────────
  static List<pw.Widget> _totalOverlay(
      TaFormData taData, double y, double fontSize) {
    final amt = _splitAmount(taData.grandTotal);
    return [
      _overlayTextBox('Grand Total', FormLayout.purposeX, y, fontSize,
          width: FormLayout.purposeWidth, bold: true),
      _overlayText(amt.rupees, FormLayout.amountRsX, y, fontSize, bold: true),
      _overlayText(amt.paise, FormLayout.amountPaiseX, y, fontSize, bold: true),
    ];
  }

  // ── Contingent bill rows — printed directly under the TA table on the
  //    same scanned page (no separate blank page). Row height/font size
  //    compact automatically as entry count grows. ──────────────────────────
  // TEST MODE: Contingent entries use the SAME 7-block calibration pattern
  // as the TA table (_testFontSizeForRow / _testRowHeightForRow), with its
  // own independent row counter starting at 0 for the first Contingent
  // entry (i.e. it does NOT continue the TA table's row numbering).
  static List<pw.Widget> _contingentOverlay(
    ContingentFormData contingentData,
    double startY,
    double rowHeight,
    double fontSize,
  ) {
    final widgets = <pw.Widget>[];
    double y = startY;

    // Header line uses Block 1's font size + 1pt, kept bold as before.
    widgets.add(_overlayText(
      'Contingent Bill',
      FormLayout.contingentDateX,
      y,
      _testFontSizeForRow(0) + 1,
      bold: true,
    ));
    y += _testRowHeightForRow(0);

    for (int rowIndex = 0; rowIndex < contingentData.entries.length; rowIndex++) {
      final entry = contingentData.entries[rowIndex];
      final rowFontSize = _testFontSizeForRow(rowIndex);
      final thisRowHeight = _testRowHeightForRow(rowIndex);

      widgets.add(_overlayText(
          entry.date, FormLayout.contingentDateX, y, rowFontSize));
      widgets.add(_overlayText(
          entry.fromLocation, FormLayout.contingentFromX, y, rowFontSize));
      widgets.add(_overlayText(
          entry.toLocation, FormLayout.contingentToX, y, rowFontSize));
      widgets.add(_overlayText(
          entry.distanceKm == 0 ? '' : entry.distanceKm.toStringAsFixed(0),
          FormLayout.contingentKmX, y, rowFontSize));
      widgets.add(_overlayText('Rs. ${entry.amount.toStringAsFixed(0)}',
          FormLayout.contingentAmountX, y, rowFontSize));
      y += thisRowHeight;
    }

    final lastFontSize = contingentData.entries.isEmpty
        ? _testFontSizeForRow(0)
        : _testFontSizeForRow(contingentData.entries.length - 1);
    widgets.add(_overlayText(
      'Total: Rs. ${contingentData.totalAmount.toStringAsFixed(0)}',
      FormLayout.contingentAmountX,
      y + 2,
      lastFontSize,
      bold: true,
    ));

    return widgets;
  }

  // ── Split a decimal amount into Rupees + Paise strings ────────────────────
  static _Amount _splitAmount(double value) {
    final rupees = value.floor();
    var paise = ((value - rupees) * 100).round();
    var rs = rupees;
    if (paise == 100) {
      rs += 1;
      paise = 0;
    }
    return _Amount(rs.toString(), paise.toString().padLeft(2, '0'));
  }

  // ── Drawn curly-bracket "}" connector ──────────────────────────────────────
  // A single `}` glyph doesn't stretch to fill an arbitrary height — its
  // curve shape is fixed by the font, so on a 3+ row merge it either looks
  // too small or visually disconnected from the rows it's meant to span.
  // This draws an actual vector bracket shape instead, built from two
  // symmetric quadratic curves meeting at a middle point, so it always
  // spans exactly `height` regardless of how many rows are merged.
  static pw.Widget _drawnBracket({
    required double left,
    required double top,
    required double height,
  }) {
    const width = 9.0; // how far the bracket's tip pokes out to the left
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.CustomPaint(
        size: PdfPoint(width, height),
        painter: (canvas, size) {
          final w = size.x;
          final h = size.y;
          final midY = h / 2;
          canvas
            ..setStrokeColor(PdfColors.black)
            ..setLineWidth(0.8)
            // Top half: from top-left down to the middle tip
            ..moveTo(w, 0)
            ..curveTo(w * 0.15, 0, w * 0.15, midY * 0.85, 0, midY)
            // Bottom half: from the middle tip down to bottom-left
            ..curveTo(w * 0.15, midY * 1.15, w * 0.15, h, w, h)
            ..strokePath();
        },
      ),
    );
  }

  // ── Single-line positioned text overlay ───────────────────────────────────
  static pw.Widget _overlayText(
    String text,
    double x,
    double y,
    double fontSize, {
    bool bold = false,
    pw.Font? font,
  }) {
    return pw.Positioned(
      left: x,
      top: y,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font ?? (bold ? pw.Font.courierBold() : pw.Font.courier()),
          fontSize: fontSize,
        ),
      ),
    );
  }

  // ── Width-constrained (wrapping) text overlay ─────────────────────────────
  static pw.Widget _overlayTextBox(
    String text,
    double x,
    double y,
    double fontSize, {
    required double width,
    bool bold = false,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    return pw.Positioned(
      left: x,
      top: y,
      child: pw.SizedBox(
        width: width,
        child: pw.Text(
          text,
          textAlign: textAlign,
          style: pw.TextStyle(
            font: bold ? pw.Font.courierBold() : pw.Font.courier(),
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }

  // ── Load a bundled asset (returns null if missing) ────────────────────────
  static Future<Uint8List?> _loadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
