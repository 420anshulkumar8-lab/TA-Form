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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/form_layout.dart';
import '../config/ta_calc_helpers.dart';
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

/// One leg with its column lines already worked out.
class _LegBox {
  final _FlatLeg flat;
  final List<String> vehicleLines;
  final List<String> fromLines;
  final List<String> toLines;
  final int lines; // tallest of Vehicle / From / To
  final double height; // visible height of those lines
  final double advance; // this row's top → next row's top
  const _LegBox({
    required this.flat,
    required this.vehicleLines,
    required this.fromLines,
    required this.toLines,
    required this.lines,
    required this.height,
    required this.advance,
  });
}

/// One trip (or one page-chunk of a trip): its legs flowing downward, where
/// Purpose sits, and how far down the next trip starts.
class _TripBlock {
  final List<_LegBox> legs;
  final List<double> legOffsets; // leg top, relative to block top
  final List<String> purposeLines;
  final double purposeHeight;
  final double purposeTop; // Purpose top, relative to block top
  final double mergedHeight; // visible height of the merged Purpose cell
  final double height; // block top → next trip's top
  const _TripBlock({
    required this.legs,
    required this.legOffsets,
    required this.purposeLines,
    required this.purposeHeight,
    required this.purposeTop,
    required this.mergedHeight,
    required this.height,
  });

  /// Space the block needs on a page, incl. a 10pt breather after its last
  /// visible line.
  double get endHeight =>
      height > mergedHeight + 10 ? height : mergedHeight + 10;
}

/// A block plus its absolute top Y on the page.
class _PlacedBlock {
  final _TripBlock block;
  final double top;
  const _PlacedBlock(this.block, this.top);
}

/// A leg with its absolute top Y on the page (used for Amount merging).
class _PlacedLeg {
  final _FlatLeg flat;
  final double top;
  final double height;
  const _PlacedLeg({
    required this.flat,
    required this.top,
    required this.height,
  });
}

class PdfService {
  // ── Main entry point ──────────────────────────────────────────────────────
  static Future<String> generatePdf({
    required TaSession session,
    required EmployeeProfile profile,
  }) async {
    final pdf = pw.Document();

    // A finalized TA prints from the profile snapshot frozen at finalize
    // time, so later profile edits never change it. Drafts (and TAs
    // finalized before snapshots existed) use the live profile.
    if (session.status == SessionStatus.submitted &&
        session.profileSnapshot != null) {
      profile = EmployeeProfile.fromJson(session.profileSnapshot!);
    }

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

    // ── Group legs into trips, size every trip's block (height depends on
    //    its tallest content: Vehicle/From/To lines, or the Purpose), then
    //    place whole blocks on page 1 / page 2. ────────────────────────────
    final pages = _paginate(flatLegs);
    final page1Blocks = pages[0];
    final page2Blocks = pages[1];
    final taEndsOnPage2 = page2Blocks.isNotEmpty;

    // ── Where does the TA table (incl. Grand Total) end? Used as the start
    //    Y for the Contingent block on that same page. ──────────────────────
    double blocksEndY(List<_PlacedBlock> blocks, double startY) {
      if (blocks.isEmpty) return startY;
      final last = blocks.last;
      return last.top + last.block.endHeight;
    }

    final double taEndY = (taEndsOnPage2
            ? blocksEndY(page2Blocks, FormLayout.firstRowY2)
            : blocksEndY(page1Blocks, FormLayout.firstRowY)) +
        4;

    // ── Contingent sizing ──────────────────────────────────────────────────
    // TEST MODE: same 7-block calibration as the TA table. Total height =
    // the header line (Block 1's height) + each entry's own block height.
    final contingentEntries = contingentData?.entries ?? <ContingentEntry>[];
    const contingentRowHeight = 24.0; // fallback value passed into helper signatures
    const contingentFontSize = 10.0; // fallback value passed into helper signatures
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
            ..._legRows(page1Blocks),
            ..._purposeOverlay(page1Blocks),
            ..._amountOverlay(page1Blocks),
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
            ..._legRows(page2Blocks, dx: -FormLayout.page2XShift),
            ..._purposeOverlay(page2Blocks, dx: -FormLayout.page2XShift),
            ..._amountOverlay(page2Blocks, dx: -FormLayout.page2XShift),
            if (!contingentOnPage1 && contingentData != null)
              ..._contingentOverlay(contingentData, contingentStartYFinal,
                  contingentRowHeight, contingentFontSize),
            // "मैं प्रमाणित करता हूँ कि श्री ____" — officer's name
            _overlayTextBox(
              profile.name,
              FormLayout.certNameX,
              FormLayout.certNameY,
              FormLayout.profileFieldFontSize,
              width: FormLayout.certNameWidth,
              bold: true,
              textAlign: _alignFromString(FormLayout.certNameAlign),
            ),
          ],
        ),
      ),
    );

    // ── Save/deliver the generated PDF ─────────────────────────────────────
    final fileName =
        'TA_${session.month}_${session.year}_${profile.employeeNo}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      // Browsers have no writable file-system access (dart:io's File is
      // unavailable on web), so instead of saving to disk we hand the
      // bytes to `printing`'s Printing.sharePdf, which triggers the
      // browser's native "Save As" / download flow for the given bytes
      // and filename. Returning the filename here (rather than a real
      // path) is fine since nothing on web needs to re-open this "path"
      // afterwards — the download has already happened by this point.
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    } else {
      // Mobile/desktop: save to the app's documents directory as before,
      // so the returned path can be opened/shared/previewed normally.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    }
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

    // All header fields: fixed 11pt, bold, centered within their slot width.
    const fs = FormLayout.profileFieldFontSize;
    return [
      // Employee No. — top-right, 10pt, left-aligned, "Emp. No. " prefix.
      if (profile.employeeNo.trim().isNotEmpty)
        _overlayTextBox('Emp. No. ${profile.employeeNo.trim()}',
            FormLayout.empNoX, FormLayout.empNoY, FormLayout.idFieldFontSize,
            width: 140, bold: false, maxLines: 1),
      // Token / Ticket No. — only printed when the user has one (N/A or
      // empty prints nothing at all, not even the label).
      if (profile.tokenNo.trim().isNotEmpty)
        _overlayTextBox('T. No. ${profile.tokenNo.trim()}',
            FormLayout.tokenNoX, FormLayout.tokenNoY, FormLayout.idFieldFontSize,
            width: 140, bold: false, maxLines: 1),
      _overlayTextBox(profile.department, FormLayout.branchX,
          FormLayout.branchY, fs,
          width: FormLayout.branchWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.branchAlign)),
      _overlayTextBox(profile.division, FormLayout.divisionX,
          FormLayout.divisionY, fs,
          width: FormLayout.divisionWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.divisionAlign)),
      _overlayTextBox(profile.headquarter, FormLayout.headquartersX,
          FormLayout.headquartersY, fs,
          width: FormLayout.headquartersWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.headquartersAlign)),
      _overlayTextBox(profile.name, FormLayout.employeeNameX,
          FormLayout.shriRowY, fs,
          width: FormLayout.employeeNameWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.employeeNameAlign)),
      _overlayTextBox(monthNameToShort(session.month), FormLayout.monthX,
          FormLayout.shriRowY, fs,
          width: FormLayout.monthWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.monthAlign)),
      _overlayTextBox(yearShort, FormLayout.yearX, FormLayout.yearY, fs,
          width: FormLayout.yearWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.yearAlign)),
      _overlayTextBox(profile.designation, FormLayout.designationX,
          FormLayout.designationRowY, fs,
          width: FormLayout.designationWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.designationAlign)),
      _overlayTextBox(
        profile.basicPay > 0 ? profile.basicPay.toStringAsFixed(0) : '',
        FormLayout.payX,
        FormLayout.designationRowY,
        fs,
        width: FormLayout.payWidth,
        bold: true,
          maxLines: 1,
        textAlign: _alignFromString(FormLayout.payAlign),
      ),
      _overlayTextBox(profile.dateOfAppointment,
          FormLayout.dateOfAppointmentX, FormLayout.dateOfAppointmentY, fs,
          width: FormLayout.dateOfAppointmentWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.dateOfAppointmentAlign)),
      // "Rule by which governed" — fixed text (not from profile).
      _overlayTextBox(FormLayout.ruleText, FormLayout.ruleX,
          FormLayout.ruleY, fs,
          width: FormLayout.ruleWidth,
          bold: true,
          maxLines: 1,
          textAlign: _alignFromString(FormLayout.ruleAlign)),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TA TABLE LAYOUT (rows flow top → bottom, one trip = one block)
  //
  //  • Every row's FIRST line holds Date, Time, Km, Day/Night; Vehicle, From
  //    and To also start there and continue downward (words wrap greedily,
  //    a word is never split). Tightest column decides the row's lines.
  //  • Next row starts below the row's last line plus a 10pt gap
  //    (1 line = 20pt, 2 lines = 29.5pt, 3 lines = 39pt).
  //  • Purpose is compared with the trip's rows (total advance):
  //      Purpose taller  → starts at the trip top, runs downward;
  //      rows taller     → Purpose is centered against the rows.
  //    Rows are NEVER stretched or moved because of Purpose; the next trip
  //    just starts below whichever is taller.
  //  • Amount is centered across the rows sharing a date (bracket if 2+).
  // ═══════════════════════════════════════════════════════════════════════
  static const double _fontSize = 10.0; // every table column
  static const double _purposeFontSize = 9.5; // Purpose column only
  static const double _linePitch = 9.5; // line-to-line distance (10pt text)
  static const double _purposeLinePitch = 9.0; // line-to-line (9.5pt text)
  static const int _purposeCharsPerLine = 13;
  static const double _charWidthFactor = 0.6; // Courier: 0.6 × font size
  // Brackets hug the form's PRINTED column lines (never on them):
  //   Purpose bracket → Day/Night side, just LEFT of the line before Purpose
  //   Amount  bracket → Amount side, just RIGHT of the line before Amount
  static const double _purposeLineX = FormLayout.purposeX - 2; // ≈ 388
  static const double _amountLineX =
      FormLayout.purposeX + FormLayout.purposeWidth + 0.5; // ≈ 470.5
  static const double _bracketLineGap = 0.8; // space between line and bracket
  static const double _bracketTick = 2.0; // length of top/bottom ticks
  static const double _amountTextShift = 2.0; // Amount text nudged right
  static const double _rowGap = 10.0; // empty space after EVERY row (1 or more lines)
  static const double _purposeSideInset = 2.0; // Purpose text: gap from each printed line
  static const int _haltCharsPerLine = 36; // Halt text wraps after this

  // Contingent block still uses one fixed 20pt row.
  static const double _fixedRowHeight = 20.0;
  static double _testFontSizeForRow(int rowIndex) => _fontSize;
  static double _testRowHeightForRow(int rowIndex) => _fixedRowHeight;

  /// How many characters of `fontSize` Courier text fit in `width` points.
  static int _maxCharsFor(double width, double fontSize) =>
      (width / (fontSize * _charWidthFactor)).floor();

  /// Height of `lines` stacked lines: first line = font size, every extra
  /// line adds `pitch`.
  static double _heightForLines(int lines, double fontSize, double pitch) =>
      lines <= 0 ? 0.0 : fontSize + (lines - 1) * pitch;

  /// Word-wrap `text` into lines of at most `maxChars` characters: as many
  /// whole words as fit stay on a line, the rest move to the next line.
  /// With `breakLongWords` a word longer than a line is hard-broken; without
  /// it such a word stays whole on a line of its own.
  static List<String> _wrapText(String text, int maxChars,
      {bool breakLongWords = true}) {
    final t = text.trim();
    if (t.isEmpty || maxChars < 1) return <String>[t];
    final lines = <String>[];
    var cur = '';
    for (var w in t.split(RegExp(r'\s+'))) {
      while (breakLongWords && w.length > maxChars) {
        if (cur.isNotEmpty) {
          lines.add(cur);
          cur = '';
        }
        lines.add(w.substring(0, maxChars));
        w = w.substring(maxChars);
      }
      if (w.isEmpty) continue;
      if (cur.isEmpty) {
        cur = w;
      } else if (cur.length + 1 + w.length <= maxChars) {
        cur = '$cur $w';
      } else {
        lines.add(cur);
        cur = w;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines.isEmpty ? <String>[''] : lines;
  }

  /// Purpose wrapping: as many whole words as fit stay on a line. A word that
  /// does not fit is split with a trailing "-" ONLY when at least [minPart]
  /// letters stay on each side of the split; otherwise (1-2 letters would be
  /// left over) the whole word moves to the next line. A word longer than a
  /// whole line is always split.
  static List<String> _wrapPurpose(String text, int maxChars,
      {int minPart = 3}) {
    final t = text.trim();
    if (t.isEmpty || maxChars < 1) return <String>[t];
    final lines = <String>[];
    var cur = '';
    for (var w in t.split(RegExp(r'\s+'))) {
      while (w.isNotEmpty) {
        // Whole word fits on the current line.
        if (cur.isEmpty
            ? w.length <= maxChars
            : cur.length + 1 + w.length <= maxChars) {
          cur = cur.isEmpty ? w : '$cur $w';
          w = '';
          break;
        }
        // Doesn't fit: how many letters (before the "-") would stay here?
        final room = cur.isEmpty ? maxChars : maxChars - cur.length - 1;
        var take = room - 1;
        if (cur.isEmpty) {
          // Word is longer than a full line → must be split.
          if (w.length - take < minPart) take = w.length - minPart;
          if (take < 1) take = 1;
        } else if (take < minPart || w.length - take < minPart) {
          // Too few letters on one side → don't split, use a fresh line.
          lines.add(cur);
          cur = '';
          continue;
        }
        final piece = '${w.substring(0, take)}-';
        lines.add(cur.isEmpty ? piece : '$cur $piece');
        cur = '';
        w = w.substring(take);
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines.isEmpty ? <String>[''] : lines;
  }

  /// Vehicle/Train lines: a train number is one line; an "Other" entry
  /// (e.g. "By Road Taxi") is word-wrapped to the column width, never
  /// splitting a word.
  static List<String> _vehicleLines(TripRow leg) {
    final text = leg.vehicleNumber.trim();
    if (leg.vehicleEntryType != VehicleEntryType.other || text.isEmpty) {
      return <String>[text];
    }
    final maxChars = _maxCharsFor(
        FormLayout.departureX - FormLayout.vehicleX - 2, _fontSize);
    return _wrapText(text, maxChars, breakLongWords: false);
  }

  /// Distance from a row's top to the next row's top: the row's own height
  /// (1 line = 10, each extra line +9.5) plus the same 10pt gap after EVERY
  /// row, so 1 line = 20, 2 lines = 29.5, 3 lines = 39.
  static double _advanceFor(int lines) =>
      _heightForLines(lines, _fontSize, _linePitch) + _rowGap;

  /// Same idea for the Purpose text (9.5pt font, 9pt line pitch). A one-line
  /// Purpose takes the normal 20pt.
  static double _purposeAdvanceFor(int lines) => lines <= 0
      ? 0.0
      : (lines == 1
          ? _fixedRowHeight
          : _heightForLines(lines, _purposeFontSize, _purposeLinePitch) +
              _rowGap);

  /// Sizes one leg: how many lines each wrapping column needs; the tallest
  /// column decides the row.
  static _LegBox _boxForLeg(_FlatLeg flat) {
    final leg = flat.leg;
    if (leg.vehicleEntryType == VehicleEntryType.halt) {
      // Halt text may be any length: wrap it; each line gets its own
      // "line — text — line" (lines are kept in vehicleLines).
      final place = leg.vehicleNumber.trim();
      final haltLines = _wrapText(
          place.isEmpty ? 'Halt' : 'Halt at $place', _haltCharsPerLine);
      return _LegBox(
        flat: flat,
        vehicleLines: haltLines,
        fromLines: const <String>[''],
        toLines: const <String>[''],
        lines: haltLines.length,
        height: _heightForLines(haltLines.length, _fontSize, _linePitch),
        advance: _advanceFor(haltLines.length),
      );
    }
    final veh = _vehicleLines(leg);
    final from = _wrapText(
        leg.fromLocation,
        _maxCharsFor(FormLayout.toX - FormLayout.fromX - 2, _fontSize),
        breakLongWords: false);
    final to = _wrapText(
        leg.toLocation,
        _maxCharsFor(FormLayout.kmX - FormLayout.toX - 2, _fontSize),
        breakLongWords: false);
    var lines = 1;
    for (final n in <int>[veh.length, from.length, to.length]) {
      if (n > lines) lines = n;
    }
    return _LegBox(
      flat: flat,
      vehicleLines: veh,
      fromLines: from,
      toLines: to,
      lines: lines,
      height: _heightForLines(lines, _fontSize, _linePitch),
      advance: _advanceFor(lines),
    );
  }

  /// Builds the block for one trip (or one page-chunk of a trip).
  static _TripBlock _buildBlock(List<_FlatLeg> flats) {
    final legs = flats.map(_boxForLeg).toList();

    // Rows simply flow downward, each one under the previous.
    final offsets = <double>[];
    double rowsTotal = 0;
    for (final l in legs) {
      offsets.add(rowsTotal);
      rowsTotal += l.advance;
    }
    final rowsExtent = offsets.last + legs.last.height; // visible bottom

    final purpose = flats.first.purpose.trim();
    final purposeLines =
        purpose.isEmpty ? <String>[] : _wrapPurpose(purpose, _purposeCharsPerLine);
    final purposeHeight = _heightForLines(
        purposeLines.length, _purposeFontSize, _purposeLinePitch);
    final purposeAdvance = _purposeAdvanceFor(purposeLines.length);

    // Purpose taller than the rows → top-aligned, runs downward.
    // Rows taller → Purpose centered against the rows.
    final purposeTaller = purposeAdvance > rowsTotal;
    final purposeTop = purposeTaller ? 0.0 : (rowsExtent - purposeHeight) / 2;

    return _TripBlock(
      legs: legs,
      legOffsets: offsets,
      purposeLines: purposeLines,
      purposeHeight: purposeHeight,
      purposeTop: purposeTop,
      mergedHeight: purposeHeight > rowsExtent ? purposeHeight : rowsExtent,
      height: purposeTaller ? purposeAdvance : rowsTotal,
    );
  }

  /// Places trip blocks on page 1, then page 2. A trip is never split if it
  /// can be kept whole (it moves to the next page instead); only a trip too
  /// tall for a whole page is split at a leg boundary. Returns
  /// [page1Blocks, page2Blocks].
  static List<List<_PlacedBlock>> _paginate(List<_FlatLeg> flatLegs) {
    final starts = <double>[FormLayout.firstRowY, FormLayout.firstRowY2];
    final caps = <double>[
      FormLayout.tableBottomY1 - FormLayout.firstRowY,
      FormLayout.tableBottomY2 - FormLayout.firstRowY2,
    ];
    final used = <double>[0.0, 0.0];
    final pages = <List<_PlacedBlock>>[<_PlacedBlock>[], <_PlacedBlock>[]];
    int page = 0;

    void place(_TripBlock b) {
      pages[page].add(_PlacedBlock(b, starts[page] + used[page]));
      used[page] += b.height;
    }

    int i = 0;
    while (i < flatLegs.length) {
      int j = i;
      while (j < flatLegs.length &&
          flatLegs[j].tripIndex == flatLegs[i].tripIndex) {
        j++;
      }
      var remaining = flatLegs.sublist(i, j);
      i = j;

      while (remaining.isNotEmpty) {
        final whole = _buildBlock(remaining);
        // Fits here (page 2 is the last page, so it always "fits").
        if (page == 1 || used[page] + whole.endHeight <= caps[page]) {
          place(whole);
          break;
        }
        // Doesn't fit on page 1 → keep the trip whole on page 2 if it can.
        if (whole.endHeight <= caps[1]) {
          page = 1;
          continue;
        }
        // Too tall even for page 2 → split at a leg boundary.
        int k = remaining.length - 1;
        while (k >= 1) {
          final part = _buildBlock(remaining.sublist(0, k));
          if (used[0] + part.endHeight <= caps[0]) break;
          k--;
        }
        if (k < 1) {
          page = 1;
          continue;
        }
        place(_buildBlock(remaining.sublist(0, k)));
        remaining = remaining.sublist(k);
        page = 1;
      }
    }
    return pages;
  }

  /// Stacked, tightly packed lines of text, one positioned widget per line.
  /// A line wider than its column (a long unbroken word) is centered on the
  /// column and overflows equally on both sides instead of wrapping.
  static List<pw.Widget> _stackedLines(
    List<String> lines, {
    required double x,
    required double top,
    required double width,
    double fontSize = _fontSize,
    double pitch = _linePitch,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    final out = <pw.Widget>[];
    for (int k = 0; k < lines.length; k++) {
      final line = lines[k];
      if (line.isEmpty) continue;
      final needed = line.length * fontSize * _charWidthFactor;
      var boxX = x;
      var boxW = width;
      if (needed > width) {
        boxX = x - (needed - width) / 2 - 0.5;
        boxW = needed + 1;
      }
      out.add(_overlayTextBox(line, boxX, top + k * pitch, fontSize,
          width: boxW, bold: true, textAlign: align));
    }
    return out;
  }

  // ── Leg rows (everything except Purpose and Amount) ──────────────────────
  static List<pw.Widget> _legRows(List<_PlacedBlock> blocks,
      {double dx = 0}) {
    final widgets = <pw.Widget>[];

    for (final pb in blocks) {
      for (int i = 0; i < pb.block.legs.length; i++) {
        final box = pb.block.legs[i];
        final leg = box.flat.leg;
        final y = pb.top + pb.block.legOffsets[i]; // top of this leg

        if (leg.vehicleEntryType == VehicleEntryType.halt) {
          // ── Halt row: Date normal; "Halt at X" centered across the merged
          // columns with a solid line on either side (line — text — line).
          // Long text wraps; every wrapped line gets its own side lines.
          widgets.add(_overlayTextBox(leg.date, FormLayout.dateX + dx, y, _fontSize,
              width: FormLayout.vehicleX - FormLayout.dateX - 2,
              bold: true,
              textAlign: pw.TextAlign.center));

          final totalWidth = (FormLayout.dayNightX + 28) - FormLayout.vehicleX;
          const gap = 6.0;

          // Real vector line (a run of '-' characters prints dashed).
          pw.Widget solidLine(double segWidth) => pw.CustomPaint(
                size: PdfPoint(segWidth, 1),
                painter: (canvas, size) {
                  canvas
                    ..setStrokeColor(PdfColors.black)
                    ..setLineWidth(0.8)
                    ..moveTo(0, 0)
                    ..lineTo(size.x, 0)
                    ..strokePath();
                },
              );

          for (int k = 0; k < box.vehicleLines.length; k++) {
            final haltLine = box.vehicleLines[k];
            final lineTop = y + k * _linePitch;
            final lineY = lineTop + (_fontSize * 0.75);

            // Courier ≈ 0.6× font-size per character.
            final textWidth = haltLine.length * _fontSize * _charWidthFactor;
            final sideWidth = ((totalWidth - textWidth) / 2 - gap)
                .clamp(0.0, totalWidth)
                .toDouble();

            widgets.add(pw.Positioned(
              left: FormLayout.vehicleX + dx,
              top: lineY,
              child: solidLine(sideWidth),
            ));
            widgets.add(pw.Positioned(
              left: FormLayout.vehicleX + dx + sideWidth + textWidth + (gap * 2),
              top: lineY,
              child: solidLine(sideWidth),
            ));
            widgets.add(_overlayTextBox(
              haltLine,
              FormLayout.vehicleX + dx,
              lineTop,
              _fontSize,
              width: totalWidth,
              textAlign: pw.TextAlign.center,
              bold: true,
            ));
          }
        } else {
          // ── Normal journey row. Single-line fields sit on the leg's first
          // line (y). Vehicle / From / To also start at y and continue
          // downward, lines packed tightly.
          widgets.add(_overlayTextBox(leg.date, FormLayout.dateX + dx, y, _fontSize,
              width: FormLayout.vehicleX - FormLayout.dateX - 2,
              bold: true,
              textAlign: pw.TextAlign.center));
          widgets.addAll(_stackedLines(
            box.vehicleLines,
            x: FormLayout.vehicleX + dx,
            top: y,
            width: FormLayout.departureX - FormLayout.vehicleX - 2,
          ));
          widgets.add(_overlayTextBox(
              leg.departureTime, FormLayout.departureX + dx, y, _fontSize,
              width: FormLayout.arrivalX - FormLayout.departureX - 2,
              bold: true,
              textAlign: pw.TextAlign.center));
          widgets.add(_overlayTextBox(
              leg.arrivalTime, FormLayout.arrivalX + dx, y, _fontSize,
              width: FormLayout.fromX - FormLayout.arrivalX - 2,
              bold: true,
              textAlign: pw.TextAlign.center));
          widgets.addAll(_stackedLines(
            box.fromLines,
            x: FormLayout.fromX + dx,
            top: y,
            width: FormLayout.toX - FormLayout.fromX - 2,
          ));
          widgets.addAll(_stackedLines(
            box.toLines,
            x: FormLayout.toX + dx,
            top: y,
            width: FormLayout.kmX - FormLayout.toX - 2,
          ));
          widgets.add(_overlayTextBox(
              leg.distanceKm == 0 ? '' : leg.distanceKm.toStringAsFixed(0),
              FormLayout.kmX + dx,
              y,
              _fontSize,
              width: FormLayout.dayNightX - FormLayout.kmX - 2,
              bold: true,
              textAlign: pw.TextAlign.center));
          widgets.add(_overlayTextBox(
              leg.dayNight, FormLayout.dayNightX + dx, y, _fontSize,
              width: FormLayout.purposeX - FormLayout.dayNightX - 2,
              bold: true,
              textAlign: pw.TextAlign.center));
        }
      }
    }

    return widgets;
  }

  // ── Amount column — one merged entry per DATE (contiguous rows sharing a
  //    date, even across two trips), centered between the top of the first
  //    such row and the bottom of the last, with a bracket if 2+ rows. ─────
  static List<pw.Widget> _amountOverlay(List<_PlacedBlock> blocks,
      {double dx = 0}) {
    final widgets = <pw.Widget>[];

    final placed = <_PlacedLeg>[];
    for (final pb in blocks) {
      for (int i = 0; i < pb.block.legs.length; i++) {
        placed.add(_PlacedLeg(
          flat: pb.block.legs[i].flat,
          top: pb.top + pb.block.legOffsets[i],
          height: pb.block.legs[i].height,
        ));
      }
    }

    int i = 0;
    while (i < placed.length) {
      final date = placed[i].flat.leg.date;
      int j = i;
      while (j < placed.length && placed[j].flat.leg.date == date) {
        j++;
      }
      final top = placed[i].top;
      final bottom = placed[j - 1].top + placed[j - 1].height;

      if (date.isNotEmpty) {
        final amt = _splitAmount(placed[i].flat.amount);
        final textTop = ((top + bottom) / 2) - (_fontSize / 2);

        if (j - i > 1) {
          widgets.add(_drawnBracket(
            // Just RIGHT of the printed line (Amount side): ticks point left,
            // so the vertical line sits one tick-length further right.
            spineX: _amountLineX + dx + _bracketLineGap + _bracketTick,
            top: top,
            height: bottom - top,
          ));
        }
        widgets.add(_overlayTextBox(
            amt.rupees, FormLayout.amountRsX + dx + _amountTextShift, textTop, _fontSize,
            width: FormLayout.amountPaiseX - FormLayout.amountRsX - 2,
            bold: true,
            textAlign: pw.TextAlign.center));
        widgets.add(_overlayTextBox(
            amt.paise, FormLayout.amountPaiseX + dx + _amountTextShift, textTop, _fontSize,
            width: 30, bold: true, textAlign: pw.TextAlign.center));
      }
      i = j;
    }

    return widgets;
  }

  // ── Purpose column — one merged entry per trip; top-aligned when taller than
  //    the trip's rows, otherwise centered against them. Bracket when the trip
  //    has 2+ legs. ────────────────────────────────────────────────────────
  static List<pw.Widget> _purposeOverlay(List<_PlacedBlock> blocks,
      {double dx = 0}) {
    final widgets = <pw.Widget>[];

    for (final pb in blocks) {
      final b = pb.block;
      if (b.purposeLines.isEmpty) continue;

      if (b.legs.length > 1) {
        widgets.add(_drawnBracket(
          // Just LEFT of the printed line (Day/Night side).
          spineX: _purposeLineX + dx - _bracketLineGap,
          top: pb.top,
          height: b.mergedHeight,
        ));
      }

      final startTop = pb.top + b.purposeTop;
      for (int k = 0; k < b.purposeLines.length; k++) {
        widgets.add(_purposeLine(
          b.purposeLines[k],
          startTop + k * _purposeLinePitch,
          justify: k < b.purposeLines.length - 1,
          dx: dx,
        ));
      }
    }

    return widgets;
  }

  /// One Purpose line. Every line except the last is justified (words spread
  /// to both edges), like a normal paragraph.
  static pw.Widget _purposeLine(String line, double top,
      {required bool justify, double dx = 0}) {
    final style = pw.TextStyle(
      font: pw.Font.courierBold(),
      fontSize: _purposeFontSize,
    );
    final safeLine = _pdfSafe(line);
    final words = safeLine.split(' ');
    return pw.Positioned(
      left: FormLayout.purposeX + dx + _purposeSideInset,
      top: top,
      child: pw.SizedBox(
        width: FormLayout.purposeWidth - (_purposeSideInset * 2),
        child: (justify && words.length > 1)
            ? pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: words.map((w) => pw.Text(w, style: style)).toList(),
              )
            : pw.Text(safeLine, style: style),
      ),
    );
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

    // Header line: fixed 10pt, bold.
    widgets.add(_overlayText(
      'Contingent Bill',
      FormLayout.contingentDateX,
      y,
      10.0,
      bold: true,
    ));
    y += _testRowHeightForRow(0);

    for (int rowIndex = 0; rowIndex < contingentData.entries.length; rowIndex++) {
      final entry = contingentData.entries[rowIndex];
      final rowFontSize = _testFontSizeForRow(rowIndex);
      final thisRowHeight = _testRowHeightForRow(rowIndex);

      widgets.add(_overlayTextBox(
          entry.date, FormLayout.contingentDateX, y, rowFontSize,
          width: FormLayout.contingentFromX - FormLayout.contingentDateX - 2,
          bold: true,
          textAlign: pw.TextAlign.center));
      widgets.add(_overlayTextBox(
          entry.fromLocation, FormLayout.contingentFromX, y, rowFontSize,
          width: FormLayout.contingentToX - FormLayout.contingentFromX - 2,
          bold: true,
          textAlign: pw.TextAlign.center));
      widgets.add(_overlayTextBox(
          entry.toLocation, FormLayout.contingentToX, y, rowFontSize,
          width: FormLayout.contingentKmX - FormLayout.contingentToX - 2,
          bold: true,
          textAlign: pw.TextAlign.center));
      widgets.add(_overlayTextBox(
          entry.distanceKm == 0 ? '' : entry.distanceKm.toStringAsFixed(0),
          FormLayout.contingentKmX, y, rowFontSize,
          width: FormLayout.contingentAmountX - FormLayout.contingentKmX - 2,
          bold: true,
          textAlign: pw.TextAlign.center));
      widgets.add(_overlayTextBox('Rs. ${entry.amount.toStringAsFixed(0)}',
          FormLayout.contingentAmountX, y, rowFontSize,
          width: 80,
          bold: true,
          textAlign: pw.TextAlign.center));
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

  // ── Plain "]" bracket ─────────────────────────────────────────────────────
  // Vertical spine at [spineX], with a short tick at the top and at the
  // bottom pointing LEFT (so it reads as "]"). Spans [height] from [top].
  static pw.Widget _drawnBracket({
    required double spineX,
    required double top,
    required double height,
  }) {
    const tick = _bracketTick;
    return pw.Positioned(
      left: spineX - tick,
      top: top,
      child: pw.CustomPaint(
        size: PdfPoint(tick, height),
        painter: (canvas, size) {
          final w = size.x;
          final h = size.y;
          canvas
            ..setStrokeColor(PdfColors.black)
            ..setLineWidth(0.8)
            ..moveTo(0, 0)
            ..lineTo(w, 0) // top tick
            ..lineTo(w, h) // spine
            ..lineTo(0, h) // bottom tick
            ..strokePath();
        },
      ),
    );
  }

  // ── Single-line positioned text overlay ───────────────────────────────────
  // ── PDF-safe text ─────────────────────────────────────────────────────────
  // The PDF uses the built-in Courier font, which only has basic Latin-1
  // characters. The app's "—" (em dash) button, and curly quotes, are NOT in
  // that font and would print as an empty box, so swap them for plain ones
  // (same length, so line-wrapping and row heights are unaffected).
  static String _pdfSafe(String text) => text
      .replaceAll('\u2014', '-') // — em dash
      .replaceAll('\u2013', '-') // – en dash
      .replaceAll('\u2212', '-') // − minus sign
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"');

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
        _pdfSafe(text),
        style: pw.TextStyle(
          font: font ?? (bold ? pw.Font.courierBold() : pw.Font.courier()),
          fontSize: fontSize,
        ),
      ),
    );
  }

  // ── Converts the 'left'/'center'/'right' strings from FormLayout into a
  //    pw.TextAlign for use with _overlayTextBox. ───────────────────────────
  static pw.TextAlign _alignFromString(String align) {
    switch (align) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
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
    int? maxLines,
  }) {
    return pw.Positioned(
      left: x,
      top: y,
      child: pw.SizedBox(
        width: width,
        child: pw.Text(
          _pdfSafe(text),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : pw.TextOverflow.clip,
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

}
