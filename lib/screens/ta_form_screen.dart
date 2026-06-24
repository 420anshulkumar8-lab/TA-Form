// lib/screens/ta_form_screen.dart
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
import '../widgets/merged_amount_cell_widget.dart';
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
  late Map<String, double> _dateAmounts; // date → user-selected amount
  late List<ContingentEntry> _contingentEntries;
  bool _showContingent = false;
  bool _isEditing = true;
  bool _isSaving = false;

  int get _monthNum => monthNameToNumber(widget.session.month);
  int get _yearNum => int.tryParse(widget.session.year) ?? DateTime.now().year;
  EmployeeProfile get _profile => context.read<AppProvider>().profile;

  // Column widths
  static const double _colDate = 100.0;
  static const double _colVehicle = 110.0;
  static const double _colTime = 80.0;
  static const double _colLoc = 110.0;
  static const double _colKm = 70.0;
  static const double _colDayNight = 80.0;
  static const double _colPurpose = 130.0;
  static const double _colAmount = 90.0;
  static const double _colAction = 40.0;
  static const double _rowHeight = 58.0;

  @override
  void initState() {
    super.initState();
    final isSubmitted = widget.session.status == SessionStatus.submitted;
    _isEditing = !isSubmitted;

    if (widget.session.formDataTa != null) {
      final taData = TaFormData.fromJson(widget.session.formDataTa!);
      _trips = taData.trips;
      _dateAmounts = Map<String, double>.from(taData.dateAmounts);
    } else {
      _trips = [TripGroup.blank()];
      _dateAmounts = {};
    }

    if (widget.session.formDataContingent != null) {
      _contingentEntries =
          ContingentFormData.fromJson(widget.session.formDataContingent!).entries;
      _showContingent = true;
    } else {
      _contingentEntries = [];
    }
  }

  // ── Amount helpers ────────────────────────────────────────────────────────

  void _syncDateAmounts() {
    _dateAmounts = TaCalculationService.syncDateAmounts(_trips, _dateAmounts);
  }

  void _setDateAmount(String date, double amount) {
    setState(() => _dateAmounts[date] = amount);
    _saveDraft();
  }

  double get _grandTaTotal => TaCalculationService.grandTaTotal(_dateAmounts);
  double get _grandContingentTotal =>
      TaCalculationService.grandContingentTotal(_contingentEntries);

  // ── Trip/leg mutation helpers ─────────────────────────────────────────────

  void _updateLeg(int tripIndex, int legIndex, TripRow Function(TripRow) fn) {
    setState(() {
      final trip = _trips[tripIndex];
      final legs = List<TripRow>.from(trip.legs);
      legs[legIndex] = fn(legs[legIndex]);
      final rechained = TaCalculationService.recalculateChain(legs);
      _trips[tripIndex] = trip.copyWith(legs: rechained);
      _syncDateAmounts();
    });
    _saveDraft();
  }

  void _updateTripPurpose(int tripIndex, String purpose) {
    setState(() => _trips[tripIndex] = _trips[tripIndex].copyWith(purpose: purpose));
    _saveDraft();
  }

  void _addLeg(int tripIndex) {
    setState(() {
      final trip = _trips[tripIndex];
      final suggested = TaCalculationService.buildSuggestedLeg(trip.legs);
      _trips[tripIndex] = trip.copyWith(legs: [...trip.legs, suggested]);
      _syncDateAmounts();
    });
    _saveDraft();
  }

  void _removeLeg(int tripIndex, int legIndex) {
    if (_trips[tripIndex].legs.length <= 1) return;
    setState(() {
      final legs = List<TripRow>.from(_trips[tripIndex].legs)..removeAt(legIndex);
      _trips[tripIndex] = _trips[tripIndex].copyWith(
          legs: TaCalculationService.recalculateChain(legs));
      _syncDateAmounts();
    });
    _saveDraft();
  }

  void _addTrip() {
    setState(() {
      _trips.add(TripGroup.blank());
      _syncDateAmounts();
    });
    _saveDraft();
  }

  void _removeTrip(int tripIndex) {
    if (_trips.length <= 1) return;
    setState(() {
      _trips.removeAt(tripIndex);
      _syncDateAmounts();
    });
    _saveDraft();
  }

  // ── Contingent helpers ────────────────────────────────────────────────────

  void _updateContingent(int i, ContingentEntry Function(ContingentEntry) fn) {
    setState(() => _contingentEntries[i] = fn(_contingentEntries[i]));
    _saveDraft();
  }

  void _addContingentSection() {
    setState(() {
      _showContingent = true;
      if (_contingentEntries.isEmpty) _contingentEntries = [const ContingentEntry()];
    });
    _saveDraft();
  }

  void _addContingentRow() {
    setState(() => _contingentEntries.add(const ContingentEntry()));
    _saveDraft();
  }

  void _removeContingentRow(int i) {
    if (_contingentEntries.length <= 1) return;
    setState(() => _contingentEntries.removeAt(i));
    _saveDraft();
  }

  void _removeContingentSection() {
    setState(() {
      _showContingent = false;
      _contingentEntries = [];
    });
    _saveDraft();
  }

  // ── Data check ────────────────────────────────────────────────────────────

  bool get _hasTaData => _trips.any((t) =>
      t.purpose.isNotEmpty ||
      t.legs.any((l) => l.fromLocation.isNotEmpty || l.toLocation.isNotEmpty));

  bool get _hasContingentData =>
      _showContingent &&
      _contingentEntries.any((e) => e.date.isNotEmpty || e.amount > 0);

  // ── Save / Final ──────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    if (!_isEditing) return;
    final p = _profile;
    widget.session.formDataTa = _hasTaData
        ? TaFormData(
            employeeId: p.employeeNo,
            month: widget.session.month,
            year: widget.session.year,
            trips: _trips,
            dateAmounts: _dateAmounts,
            grandTotal: _grandTaTotal,
            status: 'draft',
          ).toJson()
        : null;
    widget.session.formDataContingent = _hasContingentData
        ? ContingentFormData(
            employeeId: p.employeeNo,
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

  Future<void> _confirmFinal() async {
    if (!_hasTaData && !_hasContingentData) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kripya kam se kam ek entry bharein.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Do you want to final this TA?'),
        content: const Text(
            'Once finalized, you cannot edit this month\'s TA again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final p = _profile;
    widget.session.formDataTa = _hasTaData
        ? TaFormData(
            employeeId: p.employeeNo,
            month: widget.session.month,
            year: widget.session.year,
            trips: _trips,
            dateAmounts: _dateAmounts,
            grandTotal: _grandTaTotal,
            status: 'submitted',
          ).toJson()
        : null;
    widget.session.formDataContingent = _hasContingentData
        ? ContingentFormData(
            employeeId: p.employeeNo,
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

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    setState(() => _isSaving = true);
    try {
      final pdfPath = await PdfService.generatePdf(
          session: widget.session, profile: _profile);
      widget.session.pdfPath = pdfPath;
      HiveService.saveSession(widget.session);
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
                pdfPath: pdfPath,
                title: '${widget.session.displayLabel} TA Form')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(widget.session.displayLabel),
          const SizedBox(width: 8),
          StatusBadgeWidget(status: widget.session.status),
        ]),
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
                    child: Text('Travel Allowance',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),

                  // ── Trip blocks ──────────────────────────────────────────
                  for (int t = 0; t < _trips.length; t++)
                    _buildTripBlock(t),

                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      child: OutlinedButton.icon(
                        onPressed: _addTrip,
                        icon: const Icon(Icons.add_road),
                        label: const Text('Add Trip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(
                              color: Color(0xFF1565C0), width: 1.4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),

                  // ── Divider before contingent ────────────────────────────
                  const SizedBox(height: 32),
                  const Divider(indent: 12, endIndent: 12),
                  const SizedBox(height: 16),

                  // ── Contingent section ───────────────────────────────────
                  if (_showContingent) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Expanded(
                          child: Text('Contingent Bill',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (_isEditing)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: _removeContingentSection,
                          ),
                      ]),
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

                  if (_isEditing && !_showContingent)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: OutlinedButton.icon(
                        onPressed: _addContingentSection,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Contingent'),
                      ),
                    ),

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

  // ── TRIP BLOCK ────────────────────────────────────────────────────────────

  Widget _buildTripBlock(int tripIndex) {
    final trip = _trips[tripIndex];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1.2),
            ),
            child: Row(
              children: [
                Icon(Icons.alt_route,
                    size: 18, color: theme.colorScheme.primary),
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
                    child:
                        const Icon(Icons.cancel, color: Colors.red, size: 20),
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
                  foregroundColor:
                      theme.colorScheme.onSurface.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── TRIP TABLE ────────────────────────────────────────────────────────────
  // Layout per leg row:
  //   [Date | Vehicle | Dep | Arr | From | To | Km | Day/Night]  ← left block
  //   [Purpose — merged per trip]                                  ← middle
  //   [Amount — merged per date across ALL trips]                  ← right
  //   [Action ✕]

  Widget _buildTripTable(int tripIndex, TripGroup trip) {
    final level = _profile.level;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tableHeaderRow([
            _HeaderCell('Date', _colDate),
            _HeaderCell('Train/Veh No.', _colVehicle),
            _HeaderCell('Dep', _colTime),
            _HeaderCell('Arr', _colTime),
            _HeaderCell('From', _colLoc),
            _HeaderCell('To', _colLoc),
            _HeaderCell('Km', _colKm),
            _HeaderCell('Day/Night', _colDayNight),
            _HeaderCell('Purpose', _colPurpose),
            _HeaderCell('Amount', _colAmount),
            if (_isEditing) _HeaderCell('', _colAction),
          ]),
          // Build rows using a date-merge-aware layout
          _buildTripRows(tripIndex, trip, level),
        ],
      ),
    );
  }

  /// Builds the leg rows for one trip, grouping consecutive same-date legs
  /// so the Amount cell can span them.
  Widget _buildTripRows(int tripIndex, TripGroup trip, int level) {
    final legs = trip.legs;

    // Identify contiguous same-date runs WITHIN this trip
    // We'll use IntrinsicHeight + Rows to handle the vertical spanning
    final rows = <Widget>[];
    int i = 0;
    while (i < legs.length) {
      final date = legs[i].date;
      // Count how many consecutive legs in this trip share the same date
      int j = i + 1;
      while (j < legs.length && legs[j].date == date) j++;
      final sameCount = j - i;

      // Build those legs as a block with merged Amount
      rows.add(_buildDateBlock(
          tripIndex, trip, i, sameCount, date, level));
      i = j;
    }
    return Column(children: rows);
  }

  Widget _buildDateBlock(
    int tripIndex,
    TripGroup trip,
    int startLegIndex,
    int legCount,
    String date,
    int level,
  ) {
    final legs = trip.legs;

    // Count rows across ALL trips on this date for the Amount cell height
    int totalRowsOnDate = 0;
    for (final t in _trips) {
      totalRowsOnDate += t.legs.where((l) => l.date == date).length;
    }

    // Only show Amount for the FIRST occurrence of this date in this trip
    // (the merged cell height is handled via totalRowsOnDate, but we only
    // render the merged cell on the first trip/block where this date starts)
    final isFirstOccurrence = _isFirstTripWithDate(tripIndex, date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left block: all per-leg cells (Date→DayNight) + Purpose merged
          Column(
            children: [
              for (int k = startLegIndex; k < startLegIndex + legCount; k++)
                SizedBox(
                  height: _rowHeight,
                  child: _buildLegLeftCells(tripIndex, k, legs[k]),
                ),
            ],
          ),
          // Purpose — merged across all legs of this trip (rendered once per trip)
          if (startLegIndex == 0)
            MergedPurposeCellWidget(
              width: _colPurpose,
              rowHeight: _rowHeight,
              legCount: trip.legs.length,
              purpose: trip.purpose,
              enabled: _isEditing,
              onChanged: (v) => _updateTripPurpose(tripIndex, v),
            )
          else
            // Filler for Purpose column for non-first date blocks in same trip
            SizedBox(
              width: _colPurpose,
              height: _rowHeight * legCount,
            ),
          // Amount — merged per date, only rendered by first trip that has this date
          if (isFirstOccurrence && date.isNotEmpty)
            MergedAmountCellWidget(
              width: _colAmount,
              rowHeight: _rowHeight,
              rowCount: totalRowsOnDate,
              amount: _dateAmounts[date] ?? 0.0,
              employeeLevel: level,
              enabled: _isEditing,
              onChanged: (v) => _setDateAmount(date, v),
            )
          else if (!isFirstOccurrence && date.isNotEmpty)
            // Filler: this trip's legs on this date are "covered" by the
            // merged Amount cell rendered by the first trip
            SizedBox(width: _colAmount, height: _rowHeight * legCount)
          else
            // No date set yet — show plain empty cell per leg
            Column(
              children: List.generate(
                legCount,
                (_) => SizedBox(
                  width: _colAmount,
                  height: _rowHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.25)),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('—',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
            ),
          // Action buttons (delete row), one per leg
          if (_isEditing)
            Column(
              children: [
                for (int k = startLegIndex; k < startLegIndex + legCount; k++)
                  SizedBox(
                    width: _colAction,
                    height: _rowHeight,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.cancel,
                            color: Colors.red, size: 20),
                        onPressed: trip.legs.length > 1
                            ? () => _removeLeg(tripIndex, k)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Returns true if tripIndex is the FIRST trip in _trips that has any leg
  /// with the given date.
  bool _isFirstTripWithDate(int tripIndex, String date) {
    for (int t = 0; t < _trips.length; t++) {
      if (_trips[t].legs.any((l) => l.date == date)) {
        return t == tripIndex;
      }
    }
    return false;
  }

  Widget _buildLegLeftCells(int tripIndex, int legIndex, TripRow leg) {
    final theme = Theme.of(context);
    final isHalt = leg.vehicleEntryType == VehicleEntryType.halt;

    // Total width of columns that merge into "Halt at X" cell
    const double mergedHaltWidth = _colVehicle +
        _colTime + _colTime +
        _colLoc + _colLoc +
        _colKm + _colDayNight; // 110+80+80+110+110+70+80 = 640

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // Date — always shown
          EditableDateCell(
            width: _colDate,
            value: leg.date,
            month: _monthNum,
            year: _yearNum,
            enabled: _isEditing,
            isSuggested: leg.dateIsSuggested,
            onChanged: (v) => _updateLeg(tripIndex, legIndex,
                (r) => r.copyWith(date: v, dateIsSuggested: false)),
          ),

          if (isHalt)
            // ── "Halt at Location" merged cell ───────────────────────────
            GestureDetector(
              onTap: _isEditing
                  ? () async {
                      final ctrl =
                          TextEditingController(text: leg.vehicleNumber);
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(children: [
                            Icon(Icons.hotel, color: Color(0xFF3949AB)),
                            SizedBox(width: 8),
                            Text('Halt Location'),
                          ]),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'e.g. Nagpur, Delhi...',
                              labelText: 'City / Station name',
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, ctrl.text),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      if (result != null && result.trim().isNotEmpty) {
                        _updateLeg(tripIndex, legIndex,
                            (r) => r.copyWith(vehicleNumber: result.trim()));
                      }
                    }
                  : null,
              child: Container(
                width: mergedHaltWidth,
                height: _rowHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF3949AB).withOpacity(0.06),
                  border: Border(
                    right: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.25)),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hotel,
                        size: 15,
                        color: const Color(0xFF3949AB).withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text(
                      leg.vehicleNumber.isEmpty
                          ? 'Halt  (tap to set location)'
                          : 'Halt at ${leg.vehicleNumber}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: leg.vehicleNumber.isEmpty
                            ? Colors.grey
                            : const Color(0xFF3949AB),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // ── Normal journey columns ────────────────────────────────────
            EditableVehicleCell(
              width: _colVehicle,
              value: leg.vehicleNumber,
              vehicleType: leg.vehicleEntryType,
              enabled: _isEditing,
              onChanged: (v, type) => _updateLeg(
                  tripIndex,
                  legIndex,
                  (r) => r.copyWith(vehicleNumber: v, vehicleEntryType: type)),
            ),
            EditableTimeCell(
              width: _colTime,
              value: leg.departureTime,
              enabled: _isEditing,
              onChanged: (v) => _updateLeg(
                  tripIndex, legIndex, (r) => r.copyWith(departureTime: v)),
            ),
            EditableTimeCell(
              width: _colTime,
              value: leg.arrivalTime,
              enabled: _isEditing,
              onChanged: (v) => _updateLeg(
                  tripIndex, legIndex, (r) => r.copyWith(arrivalTime: v)),
            ),
            EditableTextCell(
              width: _colLoc,
              value: leg.fromLocation,
              label: 'From',
              enabled: _isEditing,
              isSuggested: leg.fromIsSuggested,
              onChanged: (v) => _updateLeg(tripIndex, legIndex,
                  (r) => r.copyWith(fromLocation: v, fromIsSuggested: false)),
            ),
            EditableTextCell(
              width: _colLoc,
              value: leg.toLocation,
              label: 'To',
              enabled: _isEditing,
              isSuggested: leg.toIsSuggested,
              onChanged: (v) => _updateLeg(tripIndex, legIndex,
                  (r) => r.copyWith(toLocation: v, toIsSuggested: false)),
            ),
            EditableTextCell(
              width: _colKm,
              value: leg.distanceKm == 0
                  ? ''
                  : leg.distanceKm.toStringAsFixed(0),
              label: 'Kilometre',
              enabled: _isEditing,
              keyboardType: TextInputType.number,
              onChanged: (v) => _updateLeg(tripIndex, legIndex,
                  (r) => r.copyWith(distanceKm: double.tryParse(v) ?? 0)),
            ),
            EditableDayNightCell(
              width: _colDayNight,
              value: leg.dayNight,
              enabled: _isEditing,
              onChanged: (v) => _updateLeg(
                  tripIndex, legIndex, (r) => r.copyWith(dayNight: v)),
            ),
          ],
        ],
      ),
    );
  }

  // ── CONTINGENT TABLE ──────────────────────────────────────────────────────

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
                  onPressed: _addContingentRow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContingentRow(
      int i, double colDate, double colLoc, double colKm,
      double colAmount, double colAction) {
    final entry = _contingentEntries[i];
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2)),
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
              onChanged: (v) => _updateContingent(i, (e) => e.copyWith(date: v))),
          EditableTextCell(
              width: colLoc,
              value: entry.fromLocation,
              label: 'From',
              enabled: _isEditing,
              onChanged: (v) =>
                  _updateContingent(i, (e) => e.copyWith(fromLocation: v))),
          EditableTextCell(
              width: colLoc,
              value: entry.toLocation,
              label: 'To',
              enabled: _isEditing,
              onChanged: (v) =>
                  _updateContingent(i, (e) => e.copyWith(toLocation: v))),
          EditableTextCell(
            width: colKm,
            value: entry.distanceKm == 0
                ? ''
                : entry.distanceKm.toStringAsFixed(0),
            label: 'Kilometre',
            enabled: _isEditing,
            keyboardType: TextInputType.number,
            onChanged: (v) => _updateContingent(
                i, (e) => e.copyWith(distanceKm: double.tryParse(v) ?? 0)),
          ),
          EditableTextCell(
            width: colAmount,
            value: entry.amount == 0 ? '' : entry.amount.toStringAsFixed(0),
            label: 'Amount',
            enabled: _isEditing,
            keyboardType: TextInputType.number,
            onChanged: (v) => _updateContingent(
                i, (e) => e.copyWith(amount: double.tryParse(v) ?? 0)),
          ),
          if (_isEditing)
            SizedBox(
              width: colAction,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  onPressed: _contingentEntries.length > 1
                      ? () => _removeContingentRow(i)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── HEADER ROW ────────────────────────────────────────────────────────────

  Widget _tableHeaderRow(List<_HeaderCell> cells) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.08)),
      child: Row(
        children: cells
            .map((c) => Container(
                  width: c.width,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
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

  // ── BOTTOM BAR ────────────────────────────────────────────────────────────

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
            ? SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _generatePdf,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_isSaving ? 'Generating...' : 'Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isEditing
                            ? null
                            : () => setState(() => _isEditing = true),
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
