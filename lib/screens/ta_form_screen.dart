// lib/screens/ta_form_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Single screen for filling / viewing a month's TA form. The TA section is
// organized into Trips ("Trip 1", "Trip 2", ...) — each trip is one
// headquarters-out-and-back journey, made of one or more legs (rows), all
// sharing a single merged Purpose cell. An optional Contingent table can be
// added below.
//
// Modes:
//   - Editable (status == fresh/draft): cells are tappable, legs/trips can
//     be added/removed, bottom buttons show "Edit" and "Final".
//   - Read-only (status == submitted): cells are not tappable, "Generate
//     PDF" button is shown instead.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/ta_calc_helpers.dart';
import '../models/contingent_model.dart';
import '../models/employee_profile.dart';
import '../models/ta_session.dart';
import '../models/trip_model.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../services/pdf_service.dart';
import '../services/ta_calculation_service.dart';
import '../widgets/editable_cell_widget.dart';
import '../widgets/merged_purpose_cell_widget.dart';
import '../widgets/status_badge_widget.dart';
import 'pdf_preview_screen.dart';

class TaFormScreen extends StatefulWidget {
  final TaSession session;

  const TaFormScreen({super.key, required this.session});

  @override
  State<TaFormScreen> createState() => _TaFormScreenState();
}

class _TaFormScreenState extends State<TaFormScreen> {
  late List<TripGroup> _trips;
  late List<ContingentEntry> _contingentEntries;
  bool _showContingent = false;
  bool _isEditing = true;
  bool _isSaving = false;

  int get _monthNum => monthNameToNumber(widget.session.month);
  int get _yearNum => int.tryParse(widget.session.year) ?? DateTime.now().year;

  @override
  void initState() {
    super.initState();
    final isSubmitted = widget.session.status == SessionStatus.submitted;
    _isEditing = !isSubmitted;

    _trips = widget.session.formDataTa != null
        ? TaFormData.fromJson(widget.session.formDataTa!).trips
        : [];
    if (_trips.isEmpty) {
      _trips = [TripGroup.blank()];
    }

    _contingentEntries = widget.session.formDataContingent != null
        ? ContingentFormData.fromJson(widget.session.formDataContingent!)
            .entries
        : [];
    _showContingent = _contingentEntries.isNotEmpty;
    if (_showContingent && _contingentEntries.isEmpty) {
      _contingentEntries = [const ContingentEntry()];
    }
  }

  EmployeeProfile get _profile => context.read<AppProvider>().profile;

  TripRow _withRecalculatedAmount(TripRow leg) {
    final amount = TaCalculationService.amountForRow(
      level: _profile.level,
      departureTime: leg.departureTime,
      arrivalTime: leg.arrivalTime,
    );
    return leg.copyWith(rateAmount: amount);
  }

  // ── Trip mutation helpers ─────────────────────────────────────────────
  void _updateLeg(int tripIndex, int legIndex, TripRow Function(TripRow) update) {
    setState(() {
      final trip = _trips[tripIndex];
      final legs = List<TripRow>.from(trip.legs);
      legs[legIndex] = _withRecalculatedAmount(update(legs[legIndex]));
      // Re-chain any still-suggested From/To in later legs of this trip.
      final rechained = TaCalculationService.recalculateChain(legs);
      _trips[tripIndex] = trip.copyWith(legs: rechained);
    });
    _saveDraft();
  }

  void _updateTripPurpose(int tripIndex, String purpose) {
    setState(() {
      _trips[tripIndex] = _trips[tripIndex].copyWith(purpose: purpose);
    });
    _saveDraft();
  }

  void _addLeg(int tripIndex) {
    setState(() {
      final trip = _trips[tripIndex];
      final suggested = TaCalculationService.buildSuggestedLeg(trip.legs);
      _trips[tripIndex] =
          trip.copyWith(legs: [...trip.legs, _withRecalculatedAmount(suggested)]);
    });
    _saveDraft();
  }

  void _removeLeg(int tripIndex, int legIndex) {
    final trip = _trips[tripIndex];
    if (trip.legs.length <= 1) return;
    setState(() {
      final legs = List<TripRow>.from(trip.legs)..removeAt(legIndex);
      _trips[tripIndex] = trip.copyWith(legs: TaCalculationService.recalculateChain(legs));
    });
    _saveDraft();
  }

  void _addTrip() {
    setState(() => _trips.add(TripGroup.blank()));
    _saveDraft();
  }

  void _removeTrip(int tripIndex) {
    if (_trips.length <= 1) return;
    setState(() => _trips.removeAt(tripIndex));
    _saveDraft();
  }

  // ── Contingent row mutation helpers ───────────────────────────────────────
  void _updateContingentRow(
      int index, ContingentEntry Function(ContingentEntry) update) {
    setState(() => _contingentEntries[index] = update(_contingentEntries[index]));
    _saveDraft();
  }

  void _addContingentSection() {
    setState(() {
      _showContingent = true;
      if (_contingentEntries.isEmpty) {
        _contingentEntries = [const ContingentEntry()];
      }
    });
    _saveDraft();
  }

  void _addContingentRow() {
    setState(() => _contingentEntries.add(const ContingentEntry()));
    _saveDraft();
  }

  void _removeContingentRow(int index) {
    if (_contingentEntries.length <= 1) return;
    setState(() => _contingentEntries.removeAt(index));
    _saveDraft();
  }

  void _removeContingentSection() {
    setState(() {
      _showContingent = false;
      _contingentEntries = [];
    });
    _saveDraft();
  }

  // ── Totals ─────────────────────────────────────────────────────────────
  double get _grandTaTotal => TaCalculationService.grandTaTotal(_trips);
  double get _grandContingentTotal =>
      TaCalculationService.grandContingentTotal(_contingentEntries);

  bool get _hasTaData => _trips.any((t) =>
      t.purpose.isNotEmpty ||
      t.legs.any((l) => l.fromLocation.isNotEmpty || l.toLocation.isNotEmpty));

  bool get _hasContingentData =>
      _showContingent && _contingentEntries.any((e) => e.date.isNotEmpty || e.amount > 0);

  // ── Save (without finalizing) — called after every single edit so a
  //    draft is never lost, regardless of how the user leaves the screen. ──
  Future<void> _saveDraft() async {
    if (!_isEditing) return; // never overwrite a submitted/final session

    final profile = _profile;

    widget.session.formDataTa = _hasTaData
        ? TaFormData(
            employeeId: profile.employeeNo,
            month: widget.session.month,
            year: widget.session.year,
            trips: _trips,
            grandTotal: _grandTaTotal,
            status: 'draft',
          ).toJson()
        : null;

    widget.session.formDataContingent = _hasContingentData
        ? ContingentFormData(
            employeeId: profile.employeeNo,
            month: widget.session.month,
            year: widget.session.year,
            entries: _contingentEntries,
            totalAmount: _grandContingentTotal,
            status: 'draft',
          ).toJson()
        : null;

    widget.session.status =
        (_hasTaData || _hasContingentData) ? SessionStatus.draft : SessionStatus.fresh;
    widget.session.lastUpdated = DateTime.now().toIso8601String();
    await HiveService.saveSession(widget.session);
  }

  // ── Final ──────────────────────────────────────────────────────────────
  Future<void> _confirmFinal() async {
    if (!_hasTaData && !_hasContingentData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kripya kam se kam ek entry bharein.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Do you want to final this TA?'),
        content: const Text(
          'Once finalized, you cannot edit this month\'s TA again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final profile = _profile;

    widget.session.formDataTa = _hasTaData
        ? TaFormData(
            employeeId: profile.employeeNo,
            month: widget.session.month,
            year: widget.session.year,
            trips: _trips,
            grandTotal: _grandTaTotal,
            status: 'submitted',
          ).toJson()
        : null;

    widget.session.formDataContingent = _hasContingentData
        ? ContingentFormData(
            employeeId: profile.employeeNo,
            month: widget.session.month,
            year: widget.session.year,
            entries: _contingentEntries,
            totalAmount: _grandContingentTotal,
            status: 'submitted',
          ).toJson()
        : null;

    widget.session.status = SessionStatus.submitted;
    widget.session.lastUpdated = DateTime.now().toIso8601String();
    HiveService.saveSession(widget.session);

    setState(() => _isEditing = false);
  }

  void _enableEdit() {
    setState(() => _isEditing = true);
  }

  // ── Generate PDF ───────────────────────────────────────────────────────
  Future<void> _generatePdf() async {
    setState(() => _isSaving = true);
    try {
      final profile = _profile;
      final pdfPath = await PdfService.generatePdf(
        session: widget.session,
        profile: profile,
      );
      widget.session.pdfPath = pdfPath;
      HiveService.saveSession(widget.session);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.push(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.session.displayLabel),
            const SizedBox(width: 8),
            StatusBadgeWidget(status: widget.session.status),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Travel Allowance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),

                  for (int t = 0; t < _trips.length; t++)
                    _buildTripBlock(t),

                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: _addTrip,
                        icon: const Icon(Icons.add_road),
                        label: const Text('Add Trip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0), width: 1.4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'TA Total: Rs. ${_grandTaTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_showContingent) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Contingent Bill',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (_isEditing)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Remove Contingent',
                              onPressed: _removeContingentSection,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildContingentTable(),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Contingent Total: Rs. ${_grandContingentTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  if (_isEditing && !_showContingent) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: OutlinedButton.icon(
                        onPressed: _addContingentSection,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Contingent'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── TRIP BLOCK (header + its legs table) ──────────────────────────────
  Widget _buildTripBlock(int tripIndex) {
    final trip = _trips[tripIndex];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Trip header — visually distinct banner ──────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3), width: 1.2),
            ),
            child: Row(
              children: [
                Icon(Icons.alt_route, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Trip ${tripIndex + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_isEditing && _trips.length > 1)
                  GestureDetector(
                    onTap: () => _removeTrip(tripIndex),
                    child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildTripTable(tripIndex, trip),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: TextButton.icon(
                onPressed: () => _addLeg(tripIndex),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Row'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── TRIP TABLE — one trip's legs, with a merged Purpose column ───────────
  Widget _buildTripTable(int tripIndex, TripGroup trip) {
    const colDate = 100.0;
    const colVehicle = 110.0;
    const colTime = 80.0;
    const colLoc = 110.0;
    const colKm = 70.0;
    const colDayNight = 80.0;
    const colPurpose = 130.0;
    const colAmount = 90.0;
    const colAction = 48.0;
    const rowHeight = 58.0; // fixed visual row height for the merged-cell math

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tableHeaderRow([
            _HeaderCell('Date', colDate),
            _HeaderCell('Train/Veh No.', colVehicle),
            _HeaderCell('Dep', colTime),
            _HeaderCell('Arr', colTime),
            _HeaderCell('From', colLoc),
            _HeaderCell('To', colLoc),
            _HeaderCell('Km', colKm),
            _HeaderCell('Day/Night', colDayNight),
            _HeaderCell('Purpose', colPurpose),
            _HeaderCell('Amount', colAmount),
            if (_isEditing) _HeaderCell('', colAction),
          ]),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Legs column-stack (everything except Purpose) ─────────
                Column(
                  children: [
                    for (int i = 0; i < trip.legs.length; i++)
                      SizedBox(
                        height: rowHeight,
                        child: _buildLegRow(
                          tripIndex,
                          i,
                          trip.legs[i],
                          colDate,
                          colVehicle,
                          colTime,
                          colLoc,
                          colKm,
                          colDayNight,
                          colAmount,
                          colAction,
                        ),
                      ),
                  ],
                ),
                // ── Merged Purpose cell spanning all legs of this trip ────
                MergedPurposeCellWidget(
                  width: colPurpose,
                  rowHeight: rowHeight,
                  legCount: trip.legs.length,
                  purpose: trip.purpose,
                  enabled: _isEditing,
                  onChanged: (v) => _updateTripPurpose(tripIndex, v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegRow(
    int tripIndex,
    int legIndex,
    TripRow leg,
    double colDate,
    double colVehicle,
    double colTime,
    double colLoc,
    double colKm,
    double colDayNight,
    double colAmount,
    double colAction,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          EditableDateCell(
            width: colDate,
            value: leg.date,
            month: _monthNum,
            year: _yearNum,
            enabled: _isEditing,
            isSuggested: leg.dateIsSuggested,
            onChanged: (v) => _updateLeg(tripIndex, legIndex,
                (r) => r.copyWith(date: v, dateIsSuggested: false)),
          ),
          EditableVehicleCell(
            width: colVehicle,
            value: leg.vehicleNumber,
            isTrainType: leg.vehicleEntryType == VehicleEntryType.train,
            enabled: _isEditing,
            onChanged: (v, isTrain) => _updateLeg(
                tripIndex,
                legIndex,
                (r) => r.copyWith(
                      vehicleNumber: v,
                      vehicleEntryType:
                          isTrain ? VehicleEntryType.train : VehicleEntryType.other,
                    )),
          ),
          EditableTimeCell(
            width: colTime,
            value: leg.departureTime,
            enabled: _isEditing,
            onChanged: (v) =>
                _updateLeg(tripIndex, legIndex, (r) => r.copyWith(departureTime: v)),
          ),
          EditableTimeCell(
            width: colTime,
            value: leg.arrivalTime,
            enabled: _isEditing,
            onChanged: (v) =>
                _updateLeg(tripIndex, legIndex, (r) => r.copyWith(arrivalTime: v)),
          ),
          EditableTextCell(
            width: colLoc,
            value: leg.fromLocation,
            label: 'From',
            enabled: _isEditing,
            isSuggested: leg.fromIsSuggested,
            onChanged: (v) => _updateLeg(tripIndex, legIndex,
                (r) => r.copyWith(fromLocation: v, fromIsSuggested: false)),
          ),
          EditableTextCell(
            width: colLoc,
            value: leg.toLocation,
            label: 'To',
            enabled: _isEditing,
            isSuggested: leg.toIsSuggested,
            onChanged: (v) => _updateLeg(tripIndex, legIndex,
                (r) => r.copyWith(toLocation: v, toIsSuggested: false)),
          ),
          EditableTextCell(
            width: colKm,
            value: leg.distanceKm == 0 ? '' : leg.distanceKm.toStringAsFixed(0),
            label: 'Kilometre',
            enabled: _isEditing,
            keyboardType: TextInputType.number,
            onChanged: (v) => _updateLeg(tripIndex, legIndex,
                (r) => r.copyWith(distanceKm: double.tryParse(v) ?? 0)),
          ),
          EditableDayNightCell(
            width: colDayNight,
            value: leg.dayNight,
            enabled: _isEditing,
            onChanged: (v) =>
                _updateLeg(tripIndex, legIndex, (r) => r.copyWith(dayNight: v)),
          ),
          ReadOnlyCell(
            width: colAmount,
            value: leg.rateAmount == 0 ? '—' : leg.rateAmount.toStringAsFixed(2),
            bold: true,
          ),
          if (_isEditing)
            SizedBox(
              width: colAction,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                onPressed: _trips[tripIndex].legs.length > 1
                    ? () => _removeLeg(tripIndex, legIndex)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  // ── CONTINGENT TABLE ───────────────────────────────────────────────────
  Widget _buildContingentTable() {
    const colDate = 110.0;
    const colLoc = 120.0;
    const colKm = 80.0;
    const colAmount = 100.0;
    const colAction = 48.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tableHeaderRow([
            _HeaderCell('Date', colDate),
            _HeaderCell('From', colLoc),
            _HeaderCell('To', colLoc),
            _HeaderCell('Km', colKm),
            _HeaderCell('Amount', colAmount),
            if (_isEditing) _HeaderCell('', colAction),
          ]),
          for (int i = 0; i < _contingentEntries.length; i++)
            _buildContingentRow(i, colDate, colLoc, colKm, colAmount, colAction),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Contingent Row',
                  onPressed: _addContingentRow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContingentRow(
    int i,
    double colDate,
    double colLoc,
    double colKm,
    double colAmount,
    double colAction,
  ) {
    final entry = _contingentEntries[i];
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          EditableDateCell(
            width: colDate,
            value: entry.date,
            month: _monthNum,
            year: _yearNum,
            enabled: _isEditing,
            onChanged: (v) =>
                _updateContingentRow(i, (e) => e.copyWith(date: v)),
          ),
          EditableTextCell(
            width: colLoc,
            value: entry.fromLocation,
            label: 'From',
            enabled: _isEditing,
            onChanged: (v) =>
                _updateContingentRow(i, (e) => e.copyWith(fromLocation: v)),
          ),
          EditableTextCell(
            width: colLoc,
            value: entry.toLocation,
            label: 'To',
            enabled: _isEditing,
            onChanged: (v) =>
                _updateContingentRow(i, (e) => e.copyWith(toLocation: v)),
          ),
          EditableTextCell(
            width: colKm,
            value: entry.distanceKm == 0 ? '' : entry.distanceKm.toStringAsFixed(0),
            label: 'Kilometre',
            enabled: _isEditing,
            keyboardType: TextInputType.number,
            onChanged: (v) => _updateContingentRow(
                i, (e) => e.copyWith(distanceKm: double.tryParse(v) ?? 0)),
          ),
          EditableTextCell(
            width: colAmount,
            value: entry.amount == 0 ? '' : entry.amount.toStringAsFixed(0),
            label: 'Amount',
            enabled: _isEditing,
            keyboardType: TextInputType.number,
            onChanged: (v) => _updateContingentRow(
                i, (e) => e.copyWith(amount: double.tryParse(v) ?? 0)),
          ),
          if (_isEditing)
            SizedBox(
              width: colAction,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                onPressed: _contingentEntries.length > 1
                    ? () => _removeContingentRow(i)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableHeaderRow(List<_HeaderCell> cells) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.08)),
      child: Row(
        children: cells
            .map((c) => Container(
                  width: c.width,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Text(
                    c.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── BOTTOM BAR ─────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isSubmitted = widget.session.status == SessionStatus.submitted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: isSubmitted
            ? Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _generatePdf,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(_isSaving ? 'Generating...' : 'Generate PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isEditing ? null : _enableEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _confirmFinal,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Final'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderCell {
  final String label;
  final double width;
  const _HeaderCell(this.label, this.width);
}
