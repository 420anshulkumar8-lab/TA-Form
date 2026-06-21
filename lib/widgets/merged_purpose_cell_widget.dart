// lib/widgets/merged_purpose_cell_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Renders the "Purpose" column for one Trip as a single merged cell spanning
// the height of all its legs — matching the GA-31 form's merged-cell look
// (see reference screenshot: one Purpose box vertically centered next to
// several rows, with "—" placeholders beside the other rows).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

class MergedPurposeCellWidget extends StatelessWidget {
  final double width;
  final double rowHeight;
  final int legCount;
  final String purpose;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const MergedPurposeCellWidget({
    super.key,
    required this.width,
    required this.rowHeight,
    required this.legCount,
    required this.purpose,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: purpose);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purpose of Journey'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. Office work at NDLS',
          ),
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
    if (result != null) onChanged(result.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalHeight = rowHeight * legCount;

    return SizedBox(
      width: width,
      height: totalHeight,
      child: InkWell(
        onTap: enabled ? () => _edit(context) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.25)),
              bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            purpose.isEmpty ? 'Purpose' : purpose,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: legCount > 1 ? 3 : 2,
            style: TextStyle(
              color: purpose.isEmpty ? Colors.grey : null,
              fontWeight: purpose.isEmpty ? FontWeight.normal : FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
