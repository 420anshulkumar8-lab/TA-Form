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

    // ── Decide row height / font size for the WHOLE TA table, then split
    //    legs between page 1 and page 2 based on how many fit on page 1. ───
    final rowHeight = FormLayout.rowHeightForCount(flatLegs.length);
    final fontSize = FormLayout.fontSizeForRows(flatLegs.length);
    final page1Cap = FormLayout.page1Capacity(rowHeight);

    final page1Legs =
        flatLegs.length <= page1Cap ? flatLegs : flatLegs.sublist(0, page1Cap);
    final page2Legs =
        flatLegs.length <= page1Cap ? <_FlatLeg>[] : flatLegs.sublist(page1Cap);

    final taEndsOnPage2 = page2Legs.isNotEmpty;

    // ── Where does the TA table (incl. Grand Total) end? Used as the start
    //    Y for the Contingent block on that same page. ──────────────────────
    final taEndY = taEndsOnPage2
        ? FormLayout.firstRowY2 + page2Legs.length * rowHeight + 4
        : FormLayout.firstRowY + page1Legs.length * rowHeight + 4;

    // ── Contingent sizing ──────────────────────────────────────────────────
    final contingentEntries = contingentData?.entries ?? <ContingentEntry>[];
    final contingentRowHeight =
        FormLayout.contingentRowHeightForCount(contingentEntries.length);
    final contingentFontSize =
        FormLayout.contingentFontSizeForRows(contingentEntries.length);
    final contingentStartY = taEndY + FormLayout.contingentGapAfterTa;
    final contingentBottomLimit = taEndsOnPage2
        ? FormLayout.contingentBottomY2
        : FormLayout.contingentBottomY1;
    final contingentFitsAfterTa = !taEndsOnPage2 &&
        (contingentStartY +
                contingentEntries.length * contingentRowHeight +
                20) <=
            contingentBottomLimit;
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
            ..._legRows(page1Legs, rowHeight, fontSize, FormLayout.firstRowY),
            ..._purposeOverlay(page1Legs, rowHeight, fontSize, FormLayout.firstRowY),
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
            ..._legRows(page2Legs, rowHeight, fontSize, FormLayout.firstRowY2),
            ..._purposeOverlay(page2Legs, rowHeight, fontSize, FormLayout.firstRowY2),
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

    return [
      _overlayText(profile.department, FormLayout.branchX,
          FormLayout.branchDivisionHqY, FormLayout.fontSizeNormal),
      _overlayText(profile.division, FormLayout.divisionX,
          FormLayout.branchDivisionHqY, FormLayout.fontSizeNormal),
      _overlayText(profile.headquarter, FormLayout.headquartersX,
          FormLayout.branchDivisionHqY, FormLayout.fontSizeNormal),
      _overlayText(profile.name, FormLayout.employeeNameX,
          FormLayout.shriRowY, FormLayout.fontSizeNormal),
      _overlayText(_capitalize(session.month), FormLayout.monthX,
          FormLayout.shriRowY, FormLayout.fontSizeNormal),
      _overlayText(yearShort, FormLayout.yearX, FormLayout.shriRowY,
          FormLayout.fontSizeNormal),
      _overlayText(profile.designation, FormLayout.designationX,
          FormLayout.designationRowY, FormLayout.fontSizeNormal),
      _overlayText(
        profile.basicPay > 0 ? profile.basicPay.toStringAsFixed(0) : '',
        FormLayout.payX,
        FormLayout.designationRowY,
        FormLayout.fontSizeNormal,
      ),
      _overlayText(profile.dateOfAppointment, FormLayout.dateOfAppointmentX,
          FormLayout.designationRowY, FormLayout.fontSizeNormal),
    ];
  }

  // ── Leg rows (everything except Purpose column) ───────────────────────────
  static List<pw.Widget> _legRows(
    List<_FlatLeg> flatLegs,
    double rowHeight,
    double fontSize,
    double startY,
  ) {
    final widgets = <pw.Widget>[];
    double y = startY;
    final seenDates = <String>{};

    for (final flat in flatLegs) {
      final leg = flat.leg;

      if (leg.vehicleEntryType == VehicleEntryType.halt) {
        // ── Halt row: only Date + centred "Halt at X" across middle columns
        widgets.add(_overlayText(leg.date, FormLayout.dateX, y, fontSize));
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
        ));
      } else {
        // ── Normal journey row
        widgets.add(_overlayText(leg.date, FormLayout.dateX, y, fontSize));
        widgets.add(_overlayText(leg.vehicleNumber, FormLayout.vehicleX, y, fontSize));
        widgets.add(_overlayText(leg.departureTime, FormLayout.departureX, y, fontSize));
        widgets.add(_overlayText(leg.arrivalTime, FormLayout.arrivalX, y, fontSize));
        widgets.add(_overlayText(leg.fromLocation, FormLayout.fromX, y, fontSize));
        widgets.add(_overlayText(leg.toLocation, FormLayout.toX, y, fontSize));
        widgets.add(_overlayText(
            leg.distanceKm == 0 ? '' : leg.distanceKm.toStringAsFixed(0),
            FormLayout.kmX, y, fontSize));
        widgets.add(_overlayText(leg.dayNight, FormLayout.dayNightX, y, fontSize));
      }

      // Amount: print only on first occurrence of this date (date-merged)
      if (leg.date.isNotEmpty && !seenDates.contains(leg.date)) {
        seenDates.add(leg.date);
        final amt = _splitAmount(flat.amount);
        widgets.add(_overlayText(amt.rupees, FormLayout.amountRsX, y, fontSize));
        widgets.add(_overlayText(amt.paise, FormLayout.amountPaiseX, y, fontSize));
      }

      y += rowHeight;
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
    double startY,
  ) {
    final widgets = <pw.Widget>[];
    if (flatLegs.isEmpty) return widgets;

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
      final blockTopY = startY + i * rowHeight;
      final blockHeight = legCountOnThisPage * rowHeight;
      final purpose = flatLegs[i].purpose;

      if (purpose.isNotEmpty) {
        // Curly-bracket connector only drawn when this trip has more than 1 leg on
        // this page — a single-leg trip just gets plain centered text.
        if (legCountOnThisPage > 1) {
          widgets.add(pw.Positioned(
            left: FormLayout.purposeX - 10,
            top: blockTopY,
            child: pw.SizedBox(
              height: blockHeight,
              child: pw.Center(
                child: pw.Text(
                  '}',
                  style: pw.TextStyle(
                    font: pw.Font.courier(),
                    fontSize: fontSize + (legCountOnThisPage * 2),
                  ),
                ),
              ),
            ),
          ));
        }

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
                style: pw.TextStyle(font: pw.Font.courier(), fontSize: fontSize),
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
  static List<pw.Widget> _contingentOverlay(
    ContingentFormData contingentData,
    double startY,
    double rowHeight,
    double fontSize,
  ) {
    final widgets = <pw.Widget>[];
    double y = startY;

    widgets.add(_overlayText(
      'Contingent Bill',
      FormLayout.contingentDateX,
      y,
      fontSize + 1,
      bold: true,
    ));
    y += rowHeight;

    for (final entry in contingentData.entries) {
      widgets.add(_overlayText(
          entry.date, FormLayout.contingentDateX, y, fontSize));
      widgets.add(_overlayText(
          entry.fromLocation, FormLayout.contingentFromX, y, fontSize));
      widgets.add(_overlayText(
          entry.toLocation, FormLayout.contingentToX, y, fontSize));
      widgets.add(_overlayText(
          entry.distanceKm == 0 ? '' : entry.distanceKm.toStringAsFixed(0),
          FormLayout.contingentKmX, y, fontSize));
      widgets.add(_overlayText('Rs. ${entry.amount.toStringAsFixed(0)}',
          FormLayout.contingentAmountX, y, fontSize));
      y += rowHeight;
    }

    widgets.add(_overlayText(
      'Total: Rs. ${contingentData.totalAmount.toStringAsFixed(0)}',
      FormLayout.contingentAmountX,
      y + 2,
      fontSize,
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

  // ── Single-line positioned text overlay ───────────────────────────────────
  static pw.Widget _overlayText(
    String text,
    double x,
    double y,
    double fontSize, {
    bool bold = false,
  }) {
    return pw.Positioned(
      left: x,
      top: y,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? pw.Font.courierBold() : pw.Font.courier(),
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
