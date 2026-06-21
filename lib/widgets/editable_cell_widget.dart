// lib/widgets/editable_cell_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable tap-to-edit cells used inside the TA / Contingent tables on
// ta_form_screen.dart. Each cell shows its current value (or a placeholder)
// and opens the appropriate picker/input when tapped — only when the table
// is in editable mode.
//
// Cells that received an auto-suggested value (From/To/Date chained from a
// previous leg) render in a lighter, dashed-border style until the user
// taps and confirms/edits them — see `isSuggested`.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Dashed border painter for "suggested, not yet confirmed" cells.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;

    // bottom edge only — enough to signal "unconfirmed" without being noisy
    double x = 0;
    final y = size.height - 1;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A plain rectangular tappable cell shell with a fixed width. When
/// [isSuggested] is true, the cell renders with muted grey text and a
/// dashed bottom border to signal "this is a guess — tap to confirm".
class _CellShell extends StatelessWidget {
  final double width;
  final bool enabled;
  final bool isSuggested;
  final VoidCallback? onTap;
  final Widget child;

  const _CellShell({
    required this.width,
    required this.enabled,
    required this.onTap,
    required this.child,
    this.isSuggested = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.25)),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: isSuggested
              ? CustomPaint(
                  painter: _DashedBorderPainter(
                      theme.colorScheme.onSurface.withOpacity(0.35)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: child,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}

/// Text style helper — muted/grey when the value is an unconfirmed suggestion.
TextStyle _valueStyle(BuildContext context, {required bool isSuggested, required bool isEmpty}) {
  final theme = Theme.of(context);
  if (isSuggested) {
    return TextStyle(
      color: theme.colorScheme.onSurface.withOpacity(0.45),
      fontStyle: FontStyle.italic,
    );
  }
  return TextStyle(color: isEmpty ? Colors.grey : null);
}

/// Free-text cell. Tapping opens a small dialog with a TextField.
class EditableTextCell extends StatelessWidget {
  final double width;
  final String value;
  final String label;
  final bool enabled;
  final bool isSuggested;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  const EditableTextCell({
    super.key,
    required this.width,
    required this.value,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.isSuggested = false,
    this.keyboardType,
  });

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    // Any explicit save (even re-confirming the same suggested text)
    // counts as the user confirming the value.
    if (result != null) onChanged(result.trim());
  }

  @override
  Widget build(BuildContext context) {
    return _CellShell(
      width: width,
      enabled: enabled,
      isSuggested: isSuggested && value.isNotEmpty,
      onTap: () => _edit(context),
      child: Text(
        value.isEmpty ? '—' : value,
        overflow: TextOverflow.ellipsis,
        style: _valueStyle(context,
            isSuggested: isSuggested && value.isNotEmpty, isEmpty: value.isEmpty),
      ),
    );
  }
}

/// Date cell — opens a calendar restricted to the given month/year only.
class EditableDateCell extends StatelessWidget {
  final double width;
  final String value; // DD/MM/YYYY
  final int month; // 1-12
  final int year;
  final bool enabled;
  final bool isSuggested;
  final ValueChanged<String> onChanged;

  const EditableDateCell({
    super.key,
    required this.width,
    required this.value,
    required this.month,
    required this.year,
    required this.enabled,
    required this.onChanged,
    this.isSuggested = false,
  });

  Future<void> _pick(BuildContext context) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    DateTime initial = firstDay;
    if (value.isNotEmpty) {
      try {
        initial = DateFormat('dd/MM/yyyy').parseStrict(value);
        if (initial.isBefore(firstDay) || initial.isAfter(lastDay)) {
          initial = firstDay;
        }
      } catch (_) {
        initial = firstDay;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDay,
      lastDate: lastDay,
    );
    if (picked != null) {
      onChanged(DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CellShell(
      width: width,
      enabled: enabled,
      isSuggested: isSuggested && value.isNotEmpty,
      onTap: () => _pick(context),
      child: Text(
        value.isEmpty ? '—' : value,
        style: _valueStyle(context,
            isSuggested: isSuggested && value.isNotEmpty, isEmpty: value.isEmpty),
      ),
    );
  }
}

/// 24-hour digital time cell.
class EditableTimeCell extends StatelessWidget {
  final double width;
  final String value; // HH:MM (24h)
  final bool enabled;
  final ValueChanged<String> onChanged;

  const EditableTimeCell({
    super.key,
    required this.width,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    TimeOfDay initial = TimeOfDay.now();
    if (value.isNotEmpty) {
      final parts = value.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      onChanged('$h:$m');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CellShell(
      width: width,
      enabled: enabled,
      onTap: () => _pick(context),
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(color: value.isEmpty ? Colors.grey : null),
      ),
    );
  }
}

/// Vehicle / Train No. cell — tap shows Train vs Other choice, then the
/// appropriate input (5-digit train number, or free text).
class EditableVehicleCell extends StatelessWidget {
  final double width;
  final String value;
  final bool isTrainType; // true = Train, false = Other
  final bool enabled;
  final void Function(String value, bool isTrain) onChanged;

  const EditableVehicleCell({
    super.key,
    required this.width,
    required this.value,
    required this.isTrainType,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Vehicle / Train No.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.train),
              title: const Text('Train'),
              onTap: () => Navigator.pop(ctx, 'train'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Other'),
              onTap: () => Navigator.pop(ctx, 'other'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'train') {
      final ctrl = TextEditingController(text: isTrainType ? value : '');
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Train No. (5 digits)'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              counterText: '',
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
        onChanged(result.trim(), true);
      }
    } else {
      final ctrl = TextEditingController(text: !isTrainType ? value : '');
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mode (e.g. By Road, By Taxi)'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
        onChanged(result.trim(), false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CellShell(
      width: width,
      enabled: enabled,
      onTap: () => _pick(context),
      child: Text(
        value.isEmpty ? '—' : value,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: value.isEmpty ? Colors.grey : null),
      ),
    );
  }
}

/// Day / Night — 2-option selector.
class EditableDayNightCell extends StatelessWidget {
  final double width;
  final String value; // "Day" | "Night" | ""
  final bool enabled;
  final ValueChanged<String> onChanged;

  const EditableDayNightCell({
    super.key,
    required this.width,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Day'),
              onTap: () => Navigator.pop(ctx, 'Day'),
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_round),
              title: const Text('Night'),
              onTap: () => Navigator.pop(ctx, 'Night'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return _CellShell(
      width: width,
      enabled: enabled,
      onTap: () => _pick(context),
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(color: value.isEmpty ? Colors.grey : null),
      ),
    );
  }
}

/// Read-only display cell (e.g. auto-calculated amount).
class ReadOnlyCell extends StatelessWidget {
  final double width;
  final String value;
  final bool bold;

  const ReadOnlyCell({
    super.key,
    required this.width,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right:
              BorderSide(color: theme.colorScheme.outline.withOpacity(0.25)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
      ),
    );
  }
}
