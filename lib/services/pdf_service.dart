// lib/services/pdf_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Generates a filled GA-31 (Travelling Allowance Journal) PDF.
//
//   Page 1 = assets/images/ga31_page1.png   (front of the form)
//   Page 2 = assets/images/ga31_page2.png   (continuation table + certificates)
//   Page 3+ = blank A4 page(s) for the Contingent Bill (if selected)
//
// Text is overlaid on the scanned form images at X,Y positions from
// FormLayout. If a TA month has more entries than fit on page 1, the
// remaining rows automatically continue onto page 2's table.
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

/// A single TA-table row paired with the formal "purpose" text of the trip
/// it belongs to (the purpose is only printed once, on the last row of the
/// trip — same behaviour as before).
class _FlatRow {
  final TripRow row;
  final String purposeFormal;
  const _FlatRow(this.row, this.purposeFormal);
}

/// Rupees + Paise split for printing into the form's two Rate sub-columns.
class _Amount {
  final String rupees;
  final String paise;
  const _Amount(this.rupees, this.paise);
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

    final hasTa = session.selectTa && session.formDataTa != null;
    final hasContingent =
        session.selectContingent && session.formDataContingent != null;

    TaFormData? taData;
    ContingentFormData? contingentData;

    if (hasTa) taData = TaFormData.fromJson(session.formDataTa!);
    if (hasContingent) {
      contingentData = ContingentFormData.fromJson(session.formDataContingent!);
    }

    // ── Flatten all TA rows (across trips) into one ordered list ───────────
    final flatRows = <_FlatRow>[];
    if (taData != null) {
      for (final trip in taData.trips) {
        for (final row in trip.rows) {
          flatRows.add(_FlatRow(row, trip.purposeFormal));
        }
      }
    }

    // ── Decide row height / font size for the WHOLE table, then split rows
    //    between page 1 and page 2 based on how many fit on page 1. ────────
    final rowHeight = FormLayout.rowHeightForCount(flatRows.length);
    final fontSize = FormLayout.fontSizeForRows(flatRows.length);
    final page1Cap = FormLayout.page1Capacity(rowHeight);

    final page1Rows = flatRows.length <= page1Cap
        ? flatRows
        : flatRows.sublist(0, page1Cap);
    final page2Rows =
        flatRows.length <= page1Cap ? <_FlatRow>[] : flatRows.sublist(page1Cap);

    final totalPrintsOnPage2 = page2Rows.isNotEmpty;

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
            ..._tableRows(page1Rows, rowHeight, fontSize, FormLayout.firstRowY),
            if (!totalPrintsOnPage2 && taData != null)
              ..._totalOverlay(
                taData,
                FormLayout.firstRowY + page1Rows.length * rowHeight + 4,
                fontSize,
              ),
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
            ..._tableRows(page2Rows, rowHeight, fontSize, FormLayout.firstRowY2),
            if (totalPrintsOnPage2 && taData != null)
              ..._totalOverlay(
                taData,
                FormLayout.firstRowY2 + page2Rows.length * rowHeight + 4,
                fontSize,
              ),
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

    // ── PAGE 3+ — Contingent Bill (own form, no scanned background) ──────────
    if (contingentData != null) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Stack(
            children: [
              _overlayText(
                'Contingent Bill — ${_capitalize(session.month)} ${session.year}',
                45,
                FormLayout.contingentTitleY,
                12,
                bold: true,
              ),
              ..._buildContingentRows(contingentData!),
            ],
          ),
        ),
      );
    }

    // ── Save to app documents directory ───────────────────────────────────
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'TA_${session.month}_${session.year}_${profile.employeeId}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  // ── Header strip overlay (page 1 only) ────────────────────────────────────
  static List<pw.Widget> _headerOverlay(
      EmployeeProfile profile, TaSession session) {
    final yearShort = session.year.length >= 2
        ? session.year.substring(session.year.length - 2)
        : session.year;

    return [
      // शाखा/Branch ... मंडल/जिला/Division/District ... सदर मुकाम/Headquarters
      // NOTE: EmployeeProfile only has a single `division` field, so it is
      // printed in both Branch and Division/District. Add a dedicated
      // `branch` field to EmployeeProfile later if these should differ.
      _overlayText(profile.division, FormLayout.branchX,
          FormLayout.branchDivisionHqY, FormLayout.fontSizeNormal),
      _overlayText(profile.division, FormLayout.divisionX,
          FormLayout.branchDivisionHqY, FormLayout.fontSizeNormal),
      _overlayText(profile.headquarters, FormLayout.headquartersX,
          FormLayout.branchDivisionHqY, FormLayout.fontSizeNormal),

      // ...performed by Shri ____ for which allowance ____ 20__ is claimed
      _overlayText(profile.name, FormLayout.employeeNameX,
          FormLayout.shriRowY, FormLayout.fontSizeNormal),
      _overlayText(_capitalize(session.month), FormLayout.monthX,
          FormLayout.shriRowY, FormLayout.fontSizeNormal),
      _overlayText(yearShort, FormLayout.yearX, FormLayout.shriRowY,
          FormLayout.fontSizeNormal),

      // पद/Designation ... वेतन/Pay ... नियुक्ति की तारीख/Date of appointment
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

  // ── TA table rows (used for both page 1 & page 2) ─────────────────────────
  static List<pw.Widget> _tableRows(
    List<_FlatRow> rows,
    double rowHeight,
    double fontSize,
    double startY,
  ) {
    final widgets = <pw.Widget>[];
    double y = startY;

    for (final flat in rows) {
      final row = flat.row;

      if (row.rowType == RowType.stay) {
        // ── Stay/halt row: merged across columns 2-7 ──────────────────────
        final stayText =
            'Stay: ${row.location}  ${row.dateFrom} - ${row.dateTo}';
        widgets.add(_overlayTextBox(
            stayText, FormLayout.vehicleX, y, fontSize, width: 260));
        widgets.add(_overlayText(
            'Night x${row.nights}', FormLayout.dayNightX, y, fontSize));

        final amt = _splitAmount(row.daAmount);
        widgets.add(_overlayText(amt.rupees, FormLayout.amountRsX, y, fontSize));
        widgets.add(_overlayText(amt.paise, FormLayout.amountPaiseX, y, fontSize));
      } else {
        // ── Normal travel row: one entry per form column ──────────────────
        widgets.add(_overlayText(row.date, FormLayout.dateX, y, fontSize));
        widgets.add(_overlayText(row.vehicleNumber, FormLayout.vehicleX, y, fontSize));
        widgets.add(_overlayText(row.departureTime, FormLayout.departureX, y, fontSize));
        widgets.add(_overlayText(row.arrivalTime, FormLayout.arrivalX, y, fontSize));
        widgets.add(_overlayText(row.fromLocation, FormLayout.fromX, y, fontSize));
        widgets.add(_overlayText(row.toLocation, FormLayout.toX, y, fontSize));
        widgets.add(_overlayText(
            row.distanceKm == 0 ? '' : row.distanceKm.toStringAsFixed(0),
            FormLayout.kmX, y, fontSize));
        widgets.add(_overlayText(row.dayNight, FormLayout.dayNightX, y, fontSize));

        // Purpose ("Object of Journey") printed once, on the last row of trip
        if (row.isLastRowOfTrip && flat.purposeFormal.isNotEmpty) {
          widgets.add(_overlayTextBox(flat.purposeFormal, FormLayout.purposeX,
              y, fontSize, width: FormLayout.purposeWidth));
        }

        final amt = _splitAmount(row.rateAmount);
        widgets.add(_overlayText(amt.rupees, FormLayout.amountRsX, y, fontSize));
        widgets.add(_overlayText(amt.paise, FormLayout.amountPaiseX, y, fontSize));
      }

      y += rowHeight;
    }

    return widgets;
  }

  // ── Grand total row (printed right after the last TA row) ────────────────
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

  // ── Contingent bill rows (own blank page) ─────────────────────────────────
  static List<pw.Widget> _buildContingentRows(
      ContingentFormData contingentData) {
    final widgets = <pw.Widget>[];
    double currentY = FormLayout.contingentStartY;
    const fontSize = FormLayout.fontSizeNormal;
    const rowHeight = FormLayout.rowHeightMid;

    for (final entry in contingentData.entries) {
      widgets.add(_overlayText(
          entry.date, FormLayout.contingentDateX, currentY, fontSize));
      widgets.add(_overlayText(
          entry.by, FormLayout.contingentByX, currentY, fontSize));
      widgets.add(_overlayText(
          entry.fromLocation, FormLayout.contingentFromX, currentY, fontSize));
      widgets.add(_overlayText(
          entry.toLocation, FormLayout.contingentToX, currentY, fontSize));
      widgets.add(_overlayText(
          entry.distanceKm == 0 ? '' : entry.distanceKm.toStringAsFixed(0),
          FormLayout.contingentKmX, currentY, fontSize));
      widgets.add(_overlayText('Rs. ${entry.amount.toStringAsFixed(0)}',
          FormLayout.contingentAmountX, currentY, fontSize));
      currentY += rowHeight;
    }

    widgets.add(_overlayText(
      'Total: Rs. ${contingentData.totalAmount.toStringAsFixed(0)}',
      FormLayout.contingentAmountX,
      currentY + 4,
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

  // ── Width-constrained (wrapping) text overlay — used for long fields like
  //    "Object of Journey" and "Stay at ..." which can run past one column ──
  static pw.Widget _overlayTextBox(
    String text,
    double x,
    double y,
    double fontSize, {
    required double width,
    bool bold = false,
  }) {
    return pw.Positioned(
      left: x,
      top: y,
      child: pw.SizedBox(
        width: width,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: bold ? pw.Font.courierBold() : pw.Font.courier(),
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }

  // ── Load a bundled asset (returns null if missing, e.g. dev hasn't added
  //    the form scans yet — pages then render with a blank/white background) ─
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
