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
import '../models/trip_model.dart';

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

  /// Shown (very lightly) in place of the value when empty, e.g. "Train No."
  /// — a format example, never mistakable for real filled-in data.
  final String? hintText;

  /// Maximum total characters allowed (enforced live via maxLength on the
  /// edit dialog's TextField). Null = no limit.
  final int? maxLength;

  /// Extra input formatters (e.g. digits-only) applied to the edit dialog's
  /// TextField, in addition to the maxLength cap above.
  final List<TextInputFormatter>? inputFormatters;

  /// When true, the edit dialog offers a "—" (no value) button that fills
  /// the cell with a dash in one tap (used for From / To).
  final bool allowDash;

  const EditableTextCell({
    super.key,
    required this.width,
    required this.value,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.isSuggested = false,
    this.keyboardType,
    this.hintText,
    this.maxLength,
    this.inputFormatters,
    this.allowDash = false,
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
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            counterText: maxLength == null ? '' : null,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          if (allowDash)
            TextButton(
                onPressed: () => Navigator.pop(ctx, '—'),
                child: const Text('No entry  —')),
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
    final showHint = value.isEmpty && hintText != null;
    return _CellShell(
      width: width,
      enabled: enabled,
      isSuggested: isSuggested && value.isNotEmpty,
      onTap: () => _edit(context),
      child: Text(
        showHint ? hintText! : (value.isEmpty ? '—' : value),
        overflow: TextOverflow.ellipsis,
        style: showHint
            ? TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.28),
                fontStyle: FontStyle.italic,
                fontSize: 11.5,
              )
            : _valueStyle(context,
                isSuggested: isSuggested && value.isNotEmpty,
                isEmpty: value.isEmpty),
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
      // Calendar-only (tap a day). Hides the keyboard-entry toggle, which
      // confuses non-technical users.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select Date',
      confirmText: 'OK',
      cancelText: 'Cancel',
    );
    if (picked != null) {
      onChanged(DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHint = value.isEmpty;
    return _CellShell(
      width: width,
      enabled: enabled,
      isSuggested: isSuggested && value.isNotEmpty,
      onTap: () => _pick(context),
      child: Text(
        showHint ? 'Date' : value,
        style: showHint
            ? TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.28),
                fontStyle: FontStyle.italic,
                fontSize: 11.5,
              )
            : _valueStyle(context,
                isSuggested: isSuggested && value.isNotEmpty, isEmpty: value.isEmpty),
      ),
    );
  }
}

/// Simple time dialog: type hour and minute (24h) in two large boxes.
/// Returns "HH:MM", or "—" if the user taps "No Time".
class _SimpleTimeDialog extends StatefulWidget {
  final TimeOfDay initial;
  const _SimpleTimeDialog({required this.initial});

  @override
  State<_SimpleTimeDialog> createState() => _SimpleTimeDialogState();
}

class _SimpleTimeDialogState extends State<_SimpleTimeDialog> {
  late final TextEditingController _h;
  late final TextEditingController _m;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _h = TextEditingController(
        text: widget.initial.hour.toString().padLeft(2, '0'));
    _m = TextEditingController(
        text: widget.initial.minute.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _h.dispose();
    _m.dispose();
    super.dispose();
  }

  void _submit() {
    final h = int.tryParse(_h.text);
    final m = int.tryParse(_m.text);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      setState(() => _error = 'Enter a valid time (00:00 \u2013 23:59).');
      return;
    }
    Navigator.pop(context,
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
  }

  Widget _box(TextEditingController c, String label) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: c,
        autofocus: label == 'Hour',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: () => c.selection =
            TextSelection(baseOffset: 0, extentOffset: c.text.length),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time (24 hour)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _box(_h, 'Hour'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              _box(_m, 'Minute'),
            ],
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, '—'),
            icon: const Icon(Icons.remove),
            label: const Text('No Time  —'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('OK')),
      ],
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
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (value.isNotEmpty && value != '—') {
      final parts = value.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
      }
    }

    // Simple typing-based 24-hour picker (big hour/minute boxes, no dial to
    // drag), plus a one-tap "No Time" button that stores a dash.
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SimpleTimeDialog(initial: initial),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final showHint = value.isEmpty;
    return _CellShell(
      width: width,
      enabled: enabled,
      onTap: () => _pick(context),
      child: Text(
        showHint ? 'HH:MM' : value,
        style: showHint
            ? TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.28),
                fontStyle: FontStyle.italic,
                fontSize: 11.5,
              )
            : const TextStyle(),
      ),
    );
  }
}

/// Vehicle / Train No. cell — tap shows Train / Other / Halt choice.
/// For Halt, a location dialog is shown and the merged row is handled
/// by the parent screen (ta_form_screen.dart).
class EditableVehicleCell extends StatelessWidget {
  final double width;
  final String value;
  final VehicleEntryType vehicleType;
  final bool enabled;
  final void Function(String value, VehicleEntryType type) onChanged;

  const EditableVehicleCell({
    super.key,
    required this.width,
    required this.value,
    required this.vehicleType,
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
              trailing: vehicleType == VehicleEntryType.train
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(ctx, 'train'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Other (Road / Taxi)'),
              trailing: vehicleType == VehicleEntryType.other
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(ctx, 'other'),
            ),
            ListTile(
              leading: const Icon(Icons.hotel, color: Color(0xFF3949AB)),
              title: const Text('Halt / Stay'),
              subtitle: const Text('No journey — stayed at outstation'),
              trailing: vehicleType == VehicleEntryType.halt
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(ctx, 'halt'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'train') {
      final ctrl = TextEditingController(
          text: vehicleType == VehicleEntryType.train ? value : '');
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
        onChanged(result.trim(), VehicleEntryType.train);
      }
    } else if (choice == 'other') {
      final ctrl = TextEditingController(
          text: vehicleType == VehicleEntryType.other ? value : '');
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mode (e.g. By Road, By Taxi)'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
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
        onChanged(result.trim(), VehicleEntryType.other);
      }
    } else {
      // Halt — ask for stay location
      final ctrl = TextEditingController(
          text: vehicleType == VehicleEntryType.halt ? value : '');
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.hotel, color: Color(0xFF3949AB)),
              SizedBox(width: 8),
              Text('Halt Location'),
            ],
          ),
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
        onChanged(result.trim(), VehicleEntryType.halt);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For halt type, this cell is never rendered directly (parent shows
    // the merged "Halt at X" cell instead). But keep a safe fallback.
    if (vehicleType == VehicleEntryType.halt) {
      return _CellShell(
        width: width,
        enabled: enabled,
        onTap: () => _pick(context),
        child: Row(
          children: [
            const Icon(Icons.hotel, size: 14, color: Color(0xFF3949AB)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value.isEmpty ? 'Halt' : 'Halt at $value',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF3949AB),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _CellShell(
      width: width,
      enabled: enabled,
      onTap: () => _pick(context),
      child: Text(
        value.isEmpty ? 'Train/Veh No.' : value,
        overflow: TextOverflow.ellipsis,
        style: value.isEmpty
            ? TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.28),
                fontStyle: FontStyle.italic,
                fontSize: 11.5,
              )
            : const TextStyle(),
      ),
    );
  }
}

/// Day / Night — 2-option selector.
/// Day/Night is auto-calculated from the Dep/Arr times (see
/// TaCalculationService.dayNightFor) and is locked — the user cannot edit
/// it. Kept under the old class name so existing call sites keep working.
class EditableDayNightCell extends StatelessWidget {
  final double width;
  final String value; // "Day" | "Night" | ""
  final bool enabled;
  final ValueChanged<String> onChanged; // unused — cell is locked

  const EditableDayNightCell({
    super.key,
    required this.width,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showHint = value.isEmpty;
    return _CellShell(
      width: width,
      enabled: false, // locked: no tap, no picker
      onTap: () {},
      child: Text(
        showHint ? 'Auto' : value,
        style: showHint
            ? TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.28),
                fontStyle: FontStyle.italic,
                fontSize: 11.5,
              )
            : const TextStyle(fontWeight: FontWeight.w600),
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
