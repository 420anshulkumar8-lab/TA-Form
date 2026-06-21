// lib/screens/month_selection_screen.dart
// Shows the last 12 months (newest first) for the current employee, each
// with its Draft/Submitted status and total amount. Tapping a month opens
// the TA Form screen for that month (fresh, draft, or read-only submitted).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ta_session.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../widgets/status_badge_widget.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill TA Form'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _months.length,
        itemBuilder: (_, i) => _MonthCard(
          option: _months[i],
          onTap: () => _openMonth(_months[i]),
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

class _MonthCard extends StatelessWidget {
  final _MonthOption option;
  final VoidCallback onTap;

  const _MonthCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final session = option.session;
    final hasData = session != null && session.hasAnyData;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (session != null)
                    StatusBadgeWidget(status: session.status),
                ],
              ),
              if (hasData) ...[
                const SizedBox(height: 10),
                Text(
                  'Total: Rs. ${session.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
