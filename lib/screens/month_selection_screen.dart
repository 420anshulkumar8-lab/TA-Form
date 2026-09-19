// lib/screens/month_selection_screen.dart
// Shows the last 12 months (newest first), grouped by year, for the current
// employee, each with its Draft/Finalized status and submission date.
// Tapping a month opens the TA Form screen for that month (fresh, draft, or
// read-only submitted). Backend/session logic is unchanged — UI only.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/ta_session.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../widgets/status_badge_widget.dart';
import '../widgets/bottom_nav_widget.dart';
import 'ta_form_screen.dart';

class MonthSelectionScreen extends StatefulWidget {
  const MonthSelectionScreen({super.key});

  @override
  State<MonthSelectionScreen> createState() => _MonthSelectionScreenState();
}

class _MonthSelectionScreenState extends State<MonthSelectionScreen> {
  late List<_MonthOption> _months;

  @override
  void initState() {
    super.initState();
    _buildMonthList();
  }

  void _buildMonthList() {
    final profile = context.read<AppProvider>().profile;
    final now = DateTime.now();
    _months = [];

    for (int i = 0; i <= 11; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMMM').format(dt).toLowerCase();
      final year = dt.year.toString();
      final key = TaSession.buildKey(monthName, year, profile.employeeNo);
      final session = HiveService.getSession(key);
      _months.add(_MonthOption(
        label: DateFormat('MMMM yyyy').format(dt),
        monthKey: monthName,
        year: year,
        session: session,
      ));
    }
  }

  void _openMonth(_MonthOption opt) {
    final profile = context.read<AppProvider>().profile;
    final session = opt.session ??
        TaSession(
          month: opt.monthKey,
          year: opt.year,
          employeeId: profile.employeeNo,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaFormScreen(session: session),
      ),
    ).then((_) => setState(_buildMonthList));
  }

  // Groups months into year -> list, preserving newest-first order both
  // across years and within each year.
  Map<String, List<_MonthOption>> get _groupedByYear {
    final Map<String, List<_MonthOption>> grouped = {};
    for (final m in _months) {
      grouped.putIfAbsent(m.year, () => []).add(m);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByYear;
    final years = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest year first

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TA Forms',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a month to view or file your TA claim',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: years.length,
                itemBuilder: (_, yi) {
                  final year = years[yi];
                  final monthsInYear = grouped[year]!;
                  return _YearGroup(
                    year: year,
                    months: monthsInYear,
                    onTapMonth: _openMonth,
                  );
                },
              ),
            ),
            const BottomNavWidget(activeIndex: 1),
          ],
        ),
      ),
    );
  }
}

class _MonthOption {
  final String label;
  final String monthKey;
  final String year;
  final TaSession? session;

  const _MonthOption({
    required this.label,
    required this.monthKey,
    required this.year,
    this.session,
  });
}

class _YearGroup extends StatelessWidget {
  final String year;
  final List<_MonthOption> months;
  final ValueChanged<_MonthOption> onTapMonth;

  const _YearGroup({
    required this.year,
    required this.months,
    required this.onTapMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              year,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: List.generate(months.length, (i) {
                final isLast = i == months.length - 1;
                return _MonthRow(
                  option: months[i],
                  showDivider: !isLast,
                  onTap: () => onTapMonth(months[i]),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final _MonthOption option;
  final bool showDivider;
  final VoidCallback onTap;

  const _MonthRow({
    required this.option,
    required this.showDivider,
    required this.onTap,
  });

  String _subtitle() {
    final session = option.session;
    if (session == null || !session.hasAnyData) {
      return 'Not submitted yet';
    }
    if (session.status == SessionStatus.submitted) {
      final dt = DateTime.tryParse(session.lastUpdated);
      final dateStr =
          dt != null ? DateFormat('d MMM yyyy').format(dt) : session.lastUpdated;
      return 'Submitted on $dateStr';
    }
    return 'Not submitted yet';
  }

  @override
  Widget build(BuildContext context) {
    final session = option.session;
    final status = session?.status ?? SessionStatus.fresh;
    final isFinalized = status == SessionStatus.submitted;
    final monthOnly = option.label.split(' ').first;
    final yearOnly = option.label.split(' ').last;

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Calendar icon bubble
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFDCEBFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$monthOnly $yearOnly',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (status != SessionStatus.fresh) ...[
              StatusBadgeWidget(status: status),
              const SizedBox(width: 8),
            ],
            Icon(
              isFinalized ? Icons.lock_outline : Icons.edit_outlined,
              size: 18,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );

    if (!showDivider) return row;

    return Column(
      children: [
        row,
        const Divider(height: 1, indent: 68, endIndent: 0),
      ],
    );
  }
}
