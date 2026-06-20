// lib/screens/manual_ta_form_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Manual (non-AI) entry form for the GA-31 TA table. Mirrors the exact
// columns printed on the physical form: Date | Train/Vehicle No. |
// Departure | Arrival | From | To | Km | Day/Night | Purpose | Rate.
// Builds the same TaFormData JSON structure the AI chat produces, so
// PdfService.generatePdf() works completely unchanged.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee_profile.dart';
import '../models/ta_session.dart';
import '../models/trip_model.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../services/pdf_service.dart';
import 'chat_screen.dart';
import 'pdf_preview_screen.dart';

class ManualTaFormScreen extends StatefulWidget {
  final TaSession session;
  const ManualTaFormScreen({super.key, required this.session});

  @override
  State<ManualTaFormScreen> createState() => _ManualTaFormScreenState();
}

class _ManualTaFormScreenState extends State<ManualTaFormScreen> {
  final List<_TripEditor> _trips = [_TripEditor()];
  bool _isSaving = false;

  @override
  void dispose() {
    for (final t in _trips) {
      t.dispose();
    }
    super.dispose();
  }

  // ── Totals (live) ──────────────────────────────────────────────────────
  double get _grandTravelTotal => _trips.fold(
      0, (s, t) => s + t.rows.fold(0, (rs, r) => rs + (r.type == RowType.travel ? (double.tryParse(r.rateCtrl.text) ?? 0) : 0)));
  double get _grandDaTotal => _trips.fold(
      0, (s, t) => s + t.rows.fold(0, (rs, r) => rs + (r.type == RowType.stay ? (double.tryParse(r.daCtrl.text) ?? 0) : 0)));
  double get _grandTotal => _grandTravelTotal + _grandDaTotal;

  void _addTrip() => setState(() => _trips.add(_TripEditor()));

  void _removeTrip(int i) {
    if (_trips.length == 1) return;
    setState(() {
      _trips[i].dispose();
      _trips.removeAt(i);
    });
  }

  void _addRow(_TripEditor trip) => setState(() => trip.rows.add(_RowEditor()));

  void _removeRow(_TripEditor trip, int i) {
    if (trip.rows.length == 1) return;
    setState(() => trip.rows.removeAt(i));
  }

  bool _validate() {
    for (final trip in _trips) {
      for (final row in trip.rows) {
        if (row.type == RowType.travel) {
          if (row.date == null ||
              row.fromCtrl.text.trim().isEmpty ||
              row.toCtrl.text.trim().isEmpty ||
              row.rateCtrl.text.trim().isEmpty) {
            return false;
          }
        } else {
          if (row.dateFrom == null ||
              row.dateTo == null ||
              row.stayLocationCtrl.text.trim().isEmpty ||
              row.daCtrl.text.trim().isEmpty) {
            return false;
          }
        }
      }
    }
    return true;
  }

  Map<String, dynamic> _buildFormDataJson(EmployeeProfile profile) {
    final tripJsons = <Map<String, dynamic>>[];

    for (int ti = 0; ti < _trips.length; ti++) {
      final trip = _trips[ti];
      double tripTravel = 0;
      double tripDa = 0;
      final rowJsons = <Map<String, dynamic>>[];

      for (int ri = 0; ri < trip.rows.length; ri++) {
        final row = trip.rows[ri];
        final isLast = ri == trip.rows.length - 1;

        if (row.type == RowType.travel) {
          final rate = double.tryParse(row.rateCtrl.text) ?? 0;
          tripTravel += rate;
          rowJsons.add(TripRow(
            rowType: RowType.travel,
            date: _fmtDate(row.date),
            vehicleNumber: row.vehicleCtrl.text.trim(),
            departureTime: _fmtTime(row.departure),
            arrivalTime: _fmtTime(row.arrival),
            fromLocation: row.fromCtrl.text.trim(),
            toLocation: row.toCtrl.text.trim(),
            distanceKm: double.tryParse(row.kmCtrl.text) ?? 0,
            dayNight: row.dayNight,
            isLastRowOfTrip: isLast,
            purpose: isLast ? '' : '↑',
            rateAmount: rate,
          ).toJson());
        } else {
          final da = double.tryParse(row.daCtrl.text) ?? 0;
          tripDa += da;
          rowJsons.add(TripRow(
            rowType: RowType.stay,
            dateFrom: _fmtDate(row.dateFrom),
            dateTo: _fmtDate(row.dateTo),
            location: row.stayLocationCtrl.text.trim(),
            nights: int.tryParse(row.nightsCtrl.text) ?? 0,
            daAmount: da,
            isLastRowOfTrip: isLast,
          ).toJson());
        }
      }

      tripJsons.add(Trip(
        tripId: ti + 1,
        purposeFormal: trip.purposeCtrl.text.trim(),
        rows: const [],
        tripTravelTotal: tripTravel,
        tripDaTotal: tripDa,
        tripTotal: tripTravel + tripDa,
      ).toJson()
        ..['rows'] = rowJsons);
    }

    return TaFormData(
      employeeId: profile.employeeId,
      month: widget.session.month,
      year: widget.session.year,
      trips: const [],
      grandTravelTotal: _grandTravelTotal,
      grandDaTotal: _grandDaTotal,
      grandTotal: _grandTotal,
      status: 'submitted',
    ).toJson()
      ..['trips'] = tripJsons;
  }

  Future<void> _save() async {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kripya har row mein zaroori fields bharein (date, from, to, rate/DA).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final profile = context.read<AppProvider>().profile;

    widget.session.formDataTa = _buildFormDataJson(profile);
    widget.session.status = SessionStatus.draft;
    widget.session.lastUpdated = DateTime.now().toIso8601String();
    HiveService.saveSession(widget.session);

    if (widget.session.selectContingent) {
      // Contingent abhi bhi AI se bharwana hai — TA already finalized hone
      // se uska tab apne aap unlock ho jaayega.
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(session: widget.session),
          ),
        );
      }
      return;
    }

    // Sirf TA selected tha — seedha PDF banao
    try {
      widget.session.status = SessionStatus.submitted;
      final pdfPath = await PdfService.generatePdf(
        session: widget.session,
        profile: profile,
      );
      widget.session.pdfPath = pdfPath;
      HiveService.saveSession(widget.session);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfPath: pdfPath,
              title: '${widget.session.displayLabel} TA Form',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF banane mein error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static String _fmtDate(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
  static String _fmtTime(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.session.displayLabel} — Manual TA'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < _trips.length; i++)
            _TripCard(
              index: i,
              trip: _trips[i],
              onRemoveTrip: _trips.length > 1 ? () => _removeTrip(i) : null,
              onAddRow: () => _addRow(_trips[i]),
              onRemoveRow: (ri) => _removeRow(_trips[i], ri),
              onChanged: () => setState(() {}),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addTrip,
            icon: const Icon(Icons.add),
            label: const Text('Naya Trip Jodein'),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFF0F4FF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _totalRow('Travel Total', _grandTravelTotal),
                  _totalRow('DA Total', _grandDaTotal),
                  const Divider(),
                  _totalRow('Grand Total', _grandTotal, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isSaving ? 'Save ho raha hai...' : 'PDF Banao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('₹${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editors (in-memory, not persisted until "PDF Banao" is pressed)
// ─────────────────────────────────────────────────────────────────────────────

class _RowEditor {
  RowType type = RowType.travel;

  // Travel fields
  DateTime? date;
  final vehicleCtrl = TextEditingController();
  TimeOfDay? departure;
  TimeOfDay? arrival;
  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  final kmCtrl = TextEditingController();
  String dayNight = 'Day';
  final rateCtrl = TextEditingController();

  // Stay fields
  DateTime? dateFrom;
  DateTime? dateTo;
  final stayLocationCtrl = TextEditingController();
  final nightsCtrl = TextEditingController();
  final daCtrl = TextEditingController();

  void dispose() {
    vehicleCtrl.dispose();
    fromCtrl.dispose();
    toCtrl.dispose();
    kmCtrl.dispose();
    rateCtrl.dispose();
    stayLocationCtrl.dispose();
    nightsCtrl.dispose();
    daCtrl.dispose();
  }
}

class _TripEditor {
  final purposeCtrl = TextEditingController();
  List<_RowEditor> rows = [_RowEditor()];

  void dispose() {
    purposeCtrl.dispose();
    for (final r in rows) {
      r.dispose();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip card widget
// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final int index;
  final _TripEditor trip;
  final VoidCallback? onRemoveTrip;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onChanged;

  const _TripCard({
    required this.index,
    required this.trip,
    required this.onRemoveTrip,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Trip ${index + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (onRemoveTrip != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onRemoveTrip,
                  ),
              ],
            ),
            TextField(
              controller: trip.purposeCtrl,
              decoration: const InputDecoration(
                labelText: 'Yatra ka Uddeshya (Object of Journey)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < trip.rows.length; i++)
              _RowCard(
                row: trip.rows[i],
                onRemove: trip.rows.length > 1 ? () => onRemoveRow(i) : null,
                onChanged: onChanged,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Row Jodein'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single row editor — switches between Travel / Stay layout
// ─────────────────────────────────────────────────────────────────────────────

class _RowCard extends StatefulWidget {
  final _RowEditor row;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _RowCard({required this.row, required this.onRemove, required this.onChanged});

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  Future<void> _pickDate(BuildContext context, ValueChanged<DateTime> onPicked) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) onPicked(d);
  }

  Future<void> _pickTime(BuildContext context, ValueChanged<TimeOfDay> onPicked) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) onPicked(t);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<RowType>(
                  segments: const [
                    ButtonSegment(value: RowType.travel, label: Text('Travel')),
                    ButtonSegment(value: RowType.stay, label: Text('Stay/Halt')),
                  ],
                  selected: {row.type},
                  onSelectionChanged: (s) {
                    setState(() => row.type = s.first);
                    widget.onChanged();
                  },
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (row.type == RowType.travel) _buildTravelFields(row) else _buildStayFields(row),
        ],
      ),
    );
  }

  Widget _buildTravelFields(_RowEditor row) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _dateField(
                label: 'Date',
                value: row.date,
                onTap: () => _pickDate(context, (d) => setState(() {
                  row.date = d;
                  widget.onChanged();
                })),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.vehicleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Train/Vehicle No.', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeField(
                label: 'Departure',
                value: row.departure,
                onTap: () => _pickTime(context, (t) => setState(() {
                  row.departure = t;
                  widget.onChanged();
                })),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeField(
                label: 'Arrival',
                value: row.arrival,
                onTap: () => _pickTime(context, (t) => setState(() {
                  row.arrival = t;
                  widget.onChanged();
                })),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.fromCtrl,
                decoration: const InputDecoration(
                    labelText: 'From Station', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.toCtrl,
                decoration: const InputDecoration(
                    labelText: 'To Station', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Kilometre', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: row.dayNight,
                decoration: const InputDecoration(
                    labelText: 'Day/Night', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Day', child: Text('Day')),
                  DropdownMenuItem(value: 'Night', child: Text('Night')),
                ],
                onChanged: (v) => setState(() {
                  row.dayNight = v ?? 'Day';
                  widget.onChanged();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: row.rateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Rate Amount (₹)', isDense: true, border: OutlineInputBorder()),
          onChanged: (_) => widget.onChanged(),
        ),
      ],
    );
  }

  Widget _buildStayFields(_RowEditor row) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _dateField(
                label: 'Date From',
                value: row.dateFrom,
                onTap: () => _pickDate(context, (d) => setState(() {
                  row.dateFrom = d;
                  widget.onChanged();
                })),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateField(
                label: 'Date To',
                value: row.dateTo,
                onTap: () => _pickDate(context, (d) => setState(() {
                  row.dateTo = d;
                  widget.onChanged();
                })),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: row.stayLocationCtrl,
          decoration: const InputDecoration(
              labelText: 'Stay Location', isDense: true, border: OutlineInputBorder()),
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.nightsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'No. of Nights', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.daCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'DA Amount (₹)', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, isDense: true, border: const OutlineInputBorder()),
        child: Text(
          value == null ? '—' : DateFormat('dd/MM/yyyy').format(value),
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, isDense: true, border: const OutlineInputBorder()),
        child: Text(value == null ? '—' : value.format(context)),
      ),
    );
  }
}
