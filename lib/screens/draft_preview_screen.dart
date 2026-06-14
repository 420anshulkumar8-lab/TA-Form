// lib/screens/draft_preview_screen.dart
// Section 8 — Draft / Fresh State Screen
import 'package:flutter/material.dart';
import '../models/ta_session.dart';
import '../models/trip_model.dart';
import '../services/hive_service.dart';
import '../widgets/status_badge_widget.dart';
import 'chat_screen.dart';

class DraftPreviewScreen extends StatefulWidget {
  final TaSession session;

  const DraftPreviewScreen({super.key, required this.session});

  @override
  State<DraftPreviewScreen> createState() => _DraftPreviewScreenState();
}

class _DraftPreviewScreenState extends State<DraftPreviewScreen> {
  bool _isCardView = true;

  TaFormData? get _taData {
    if (widget.session.formDataTa == null) return null;
    try {
      return TaFormData.fromJson(widget.session.formDataTa!);
    } catch (_) {
      return null;
    }
  }

  int get _tripCount => _taData?.trips.length ?? 0;

  String? get _lastJourneyDate {
    final ta = _taData;
    if (ta == null || ta.trips.isEmpty) return null;
    final lastTrip = ta.trips.last;
    if (lastTrip.rows.isEmpty) return null;
    for (final row in lastTrip.rows.reversed) {
      if (row.rowType == RowType.travel) return row.date;
    }
    return null;
  }

  // ── Fresh: no data at all ─────────────────────────────────────────────────
  Widget _buildFreshCard() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined,
                  size: 64, color: Color(0xFF1565C0)),
              const SizedBox(height: 16),
              Text(
                widget.session.displayLabel,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Koi purana draft nahi mila.\nNayi journey se shuru karein.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Naya TA Form Bharna Shuru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
                onPressed: _goToChat,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Draft: data exists ────────────────────────────────────────────────────
  Widget _buildDraftView() {
    final ta = _taData!;

    return Column(
      children: [
        // ── Stats bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withOpacity(0.5),
          child: Row(
            children: [
              _StatChip(label: 'Trips', value: '$_tripCount'),
              const SizedBox(width: 8),
              if (_lastJourneyDate != null)
                _StatChip(
                    label: 'Last',
                    value: _lastJourneyDate!),
              const Spacer(),
              _StatChip(
                  label: 'Total',
                  value: 'Rs. ${ta.grandTotal.toStringAsFixed(0)}'),
            ],
          ),
        ),

        // ── View toggle ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  label: Text('Card View'),
                  icon: Icon(Icons.view_agenda)),
              ButtonSegment(
                  value: false,
                  label: Text('Form View'),
                  icon: Icon(Icons.table_chart)),
            ],
            selected: {_isCardView},
            onSelectionChanged: (s) =>
                setState(() => _isCardView = s.first),
          ),
        ),

        // ── Data view ──────────────────────────────────────────────────────
        Expanded(
          child: _isCardView
              ? _buildCardView(ta)
              : _buildFormView(ta),
        ),

        // ── Action buttons ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Wahan se Aage Bharein'),
                  onPressed: _goToChat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Naye Sire se Bharein'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _confirmReset,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardView(TaFormData ta) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: ta.trips.length,
      itemBuilder: (_, i) => _TripSummaryCard(
        trip: ta.trips[i],
        tripNumber: i + 1,
      ),
    );
  }

  Widget _buildFormView(TaFormData ta) {
    final theme = Theme.of(context);
    final allRows = ta.trips.expand((t) => t.rows).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            theme.colorScheme.primary.withOpacity(0.08),
          ),
          border: TableBorder.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          columnSpacing: 12,
          headingTextStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
          dataTextStyle: theme.textTheme.bodySmall,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('From')),
            DataColumn(label: Text('To')),
            DataColumn(label: Text('Mode')),
            DataColumn(label: Text('Dist (km)'), numeric: true),
            DataColumn(label: Text('Dep')),
            DataColumn(label: Text('Arr')),
            DataColumn(label: Text('Purpose')),
            DataColumn(label: Text('Amt (Rs)'), numeric: true),
          ],
          rows: allRows
              .where((r) => r.rowType == RowType.travel)
              .map((r) => DataRow(cells: [
                    DataCell(Text(r.date)),
                    DataCell(Text(r.fromLocation, overflow: TextOverflow.ellipsis)),
                    DataCell(Text(r.toLocation, overflow: TextOverflow.ellipsis)),
                    DataCell(Text(r.mode)),
                    DataCell(Text(r.distanceKm.toStringAsFixed(1))),
                    DataCell(Text(r.departureTime)),
                    DataCell(Text(r.arrivalTime)),
                    DataCell(SizedBox(
                      width: 100,
                      child: Text(r.purpose, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(r.rateAmount.toStringAsFixed(2))),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  void _goToChat({bool fresh = false}) {
    if (fresh) {
      widget.session
        ..formDataTa = null
        ..formDataContingent = null
        ..chatHistoryTa = []
        ..chatHistoryContingent = []
        ..status = SessionStatus.draft
        ..lastUpdated = DateTime.now().toIso8601String();
      HiveService.saveSession(widget.session);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(session: widget.session),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(
          '${widget.session.displayLabel} ka poora draft delete ho jayega.\nKya aap sure hain?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            child: const Text('Haan, Naya Shuru Karein'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _goToChat(fresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDraft = widget.session.formDataTa != null &&
        _taData != null &&
        _taData!.trips.isNotEmpty;

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
      body: hasDraft ? _buildDraftView() : _buildFreshCard(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local card widget for displaying a Trip summary in the draft preview.
// ─────────────────────────────────────────────────────────────────────────────
class _TripSummaryCard extends StatelessWidget {
  final Trip trip;
  final int tripNumber;

  const _TripSummaryCard({required this.trip, required this.tripNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final travelRows = trip.rows.where((r) => r.rowType == RowType.travel).toList();
    final stayRows = trip.rows.where((r) => r.rowType == RowType.stay).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$tripNumber',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trip.purposeFormal,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs. ${trip.tripTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),

            if (travelRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...travelRows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.directions_car_outlined, size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${r.date}  ${r.fromLocation} → ${r.toLocation}'
                        '  (${r.distanceKm.toStringAsFixed(1)} km)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],

            if (stayRows.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...stayRows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.hotel_outlined, size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${r.location}  ${r.dateFrom} – ${r.dateTo}'
                        '  (${r.nights} night${r.nights == 1 ? '' : 's'})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
