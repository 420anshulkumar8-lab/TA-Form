// lib/screens/month_selection_screen.dart
// Steps 1–4 of the Fill TA Form entry flow (Section 7)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ta_session.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../widgets/status_badge_widget.dart';
import 'draft_preview_screen.dart';
import 'pdf_preview_screen.dart';

class MonthSelectionScreen extends StatefulWidget {
  const MonthSelectionScreen({super.key});

  @override
  State<MonthSelectionScreen> createState() =>
      _MonthSelectionScreenState();
}

class _MonthSelectionScreenState
    extends State<MonthSelectionScreen> {
  // ── Step 1: month ─────────────────────────────────────────────────────────
  late List<_MonthOption> _months;
  _MonthOption? _selectedMonth;

  // ── Step 3: what to fill ──────────────────────────────────────────────────
  bool _fillTa = true;
  bool _fillContingent = true;

  // ── Step 4: AI language ───────────────────────────────────────────────────
  String _aiLanguage = 'Hinglish';
  final TextEditingController _customLangCtrl =
      TextEditingController();
  static const List<String> _aiLanguages = [
    'Hinglish',
    'Hindi',
    'English',
    'Punjabi',
    'Bengali',
    'Marathi',
    'Tamil',
    'Telugu',
    'Gujarati',
    'Kannada',
    'Urdu',
    'Other',
  ];

  int _step = 1; // 1 = month, 2 = blocked, 3 = what, 4 = language

  @override
  void initState() {
    super.initState();
    _buildMonthList();
  }

  @override
  void dispose() {
    _customLangCtrl.dispose();
    super.dispose();
  }

  void _buildMonthList() {
    final profile = context.read<AppProvider>().profile;
    final now = DateTime.now();
    _months = [];

    for (int i = 0; i <= 12; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      final monthName =
          DateFormat('MMMM').format(dt).toLowerCase();
      final year = dt.year.toString();
      final key = TaSession.buildKey(
          monthName, year, profile.employeeId);
      final session = HiveService.getSession(key);
      _months.add(_MonthOption(
        dt: dt,
        label: DateFormat('MMMM yyyy').format(dt),
        monthKey: monthName,
        year: year,
        session: session,
      ));
    }
  }

  // ── Step transitions ──────────────────────────────────────────────────────
  void _onMonthSelected(_MonthOption opt) {
    setState(() => _selectedMonth = opt);

    if (opt.session?.status == SessionStatus.submitted) {
      setState(() => _step = 2); // blocked
    } else {
      setState(() => _step = 3); // what to fill
    }
  }

  void _goToLanguageStep() {
    if (!_fillTa && !_fillContingent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kam se kam ek option select karein.'),
        ),
      );
      return;
    }
    setState(() => _step = 4);
  }

  void _startFilling() {
    final opt = _selectedMonth!;
    final profile = context.read<AppProvider>().profile;
    final lang =
        _aiLanguage == 'Other' ? _customLangCtrl.text.trim() : _aiLanguage;

    // Get or create session
    TaSession session = HiveService.getSession(
            TaSession.buildKey(opt.monthKey, opt.year, profile.employeeId)) ??
        TaSession(
          month: opt.monthKey,
          year: opt.year,
          employeeId: profile.employeeId,
          selectTa: _fillTa,
          selectContingent: _fillContingent,
          aiLanguage: lang,
        );

    session
      ..selectTa = _fillTa
      ..selectContingent = _fillContingent
      ..aiLanguage = lang.isEmpty ? 'Hinglish' : lang;

    HiveService.saveSession(session);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DraftPreviewScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill TA Form'),
        leading: BackButton(
          onPressed: () {
            if (_step > 1) {
              setState(() => _step = _step == 2 ? 1 : _step - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _StepMonth(
          months: _months,
          selected: _selectedMonth,
          onSelect: _onMonthSelected,
        );
      case 2:
        return _StepBlocked(
          option: _selectedMonth!,
          onViewPdf: () {
            final session = _selectedMonth!.session!;
            if (session.pdfPath != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfPreviewScreen(
                    pdfPath: session.pdfPath!,
                    title: '${_selectedMonth!.label} PDF',
                  ),
                ),
              );
            }
          },
          onBack: () => setState(() => _step = 1),
        );
      case 3:
        return _StepWhatToFill(
          fillTa: _fillTa,
          fillContingent: _fillContingent,
          onTaChanged: (v) => setState(() => _fillTa = v),
          onContingentChanged: (v) =>
              setState(() => _fillContingent = v),
          onNext: _goToLanguageStep,
        );
      case 4:
        return _StepAiLanguage(
          languages: _aiLanguages,
          selected: _aiLanguage,
          customCtrl: _customLangCtrl,
          onChanged: (v) => setState(() => _aiLanguage = v!),
          onStart: _startFilling,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _MonthOption {
  final DateTime dt;
  final String label;
  final String monthKey;
  final String year;
  final TaSession? session;
  const _MonthOption({
    required this.dt,
    required this.label,
    required this.monthKey,
    required this.year,
    this.session,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Step widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepMonth extends StatelessWidget {
  final List<_MonthOption> months;
  final _MonthOption? selected;
  final ValueChanged<_MonthOption> onSelect;

  const _StepMonth({
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kaun se mahine ka form bharna hai?',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: months.length,
              itemBuilder: (_, i) {
                final opt = months[i];
                final isSelected = selected?.label == opt.label;
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  tileColor: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1)
                      : null,
                  title: Text(
                    opt.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600),
                  ),
                  trailing: opt.session != null
                      ? StatusBadgeWidget(
                          status: opt.session!.status)
                      : null,
                  onTap: () => onSelect(opt),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBlocked extends StatelessWidget {
  final _MonthOption option;
  final VoidCallback onViewPdf;
  final VoidCallback onBack;

  const _StepBlocked({
    required this.option,
    required this.onViewPdf,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '${option.label} ka TA form already submit ho chuka hai.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF Dekhein'),
              onPressed: option.session?.pdfPath != null
                  ? onViewPdf
                  : null,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text('Wapas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepWhatToFill extends StatelessWidget {
  final bool fillTa;
  final bool fillContingent;
  final ValueChanged<bool> onTaChanged;
  final ValueChanged<bool> onContingentChanged;
  final VoidCallback onNext;

  const _StepWhatToFill({
    required this.fillTa,
    required this.fillContingent,
    required this.onTaChanged,
    required this.onContingentChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kya bharna hai?',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            title: const Text('Travel Allowance (TA)'),
            value: fillTa,
            onChanged: (v) => onTaChanged(v ?? true),
          ),
          CheckboxListTile(
            title: const Text('Contingent Bill'),
            value: fillContingent,
            onChanged: (v) => onContingentChanged(v ?? true),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dono checked hain. Jo nahi bharna wo uncheck karein.',
            style:
                TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                  'Aage Badho',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepAiLanguage extends StatelessWidget {
  final List<String> languages;
  final String selected;
  final TextEditingController customCtrl;
  final ValueChanged<String?> onChanged;
  final VoidCallback onStart;

  const _StepAiLanguage({
    required this.languages,
    required this.selected,
    required this.customCtrl,
    required this.onChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI se kis bhasha mein baat karenge?',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: selected,
            decoration: const InputDecoration(
              labelText: 'AI Language',
              border: OutlineInputBorder(),
            ),
            items: languages
                .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
          if (selected == 'Other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: customCtrl,
              decoration: const InputDecoration(
                labelText: 'Apni bhasha likhein',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Form Bharna Shuru Karein',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
