// lib/screens/form_preview_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shown after the user taps "Preview" on the fill screen, BEFORE the session
// is actually finalized. Renders the same scanned-GA31-with-overlay PDF that
// PdfService produces (so the user sees an exact original-form preview,
// including their profile header) but the session itself is still a draft —
// nothing is locked yet.
//
// Bottom bar: [Edit] pops back to the fill screen (still editable).
//             [Final] runs the real confirm/lock flow via onConfirmFinal,
//                     then pops back to the fill screen (which will now show
//                     the submitted, read-only state + its own Generate PDF
//                     button).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class FormPreviewScreen extends StatefulWidget {
  final String pdfPath;
  final String title;

  /// Runs the actual "finalize" logic (confirmation dialog + session lock).
  /// Returns true if the user went through with it.
  final Future<bool> Function() onConfirmFinal;

  const FormPreviewScreen({
    super.key,
    required this.pdfPath,
    required this.onConfirmFinal,
    this.title = 'Form Preview',
  });

  @override
  State<FormPreviewScreen> createState() => _FormPreviewScreenState();
}

class _FormPreviewScreenState extends State<FormPreviewScreen> {
  bool _isFinalizing = false;

  Future<void> _handleFinal() async {
    setState(() => _isFinalizing = true);
    final confirmed = await widget.onConfirmFinal();
    if (!mounted) return;
    setState(() => _isFinalizing = false);
    if (confirmed) {
      // Session is now submitted — return to the fill screen, which will
      // rebuild in its read-only "submitted" state.
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.pdfPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF8E1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.pinch_outlined, size: 16, color: Color(0xFF8D6E00)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pinch to zoom in and check every entry carefully before finalizing.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF8D6E00)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) => file.readAsBytes(),
              allowPrinting: false,
              allowSharing: false,
              canChangeOrientation: false,
              canDebug: false,
              maxScale: 5.0,
              minScale: 0.5,
              scrollViewDecoration: const BoxDecoration(color: Color(0xFFE9EDF2)),
              pdfFileName: 'ta_form_preview.pdf',
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isFinalizing ? null : () => Navigator.pop(context, false),
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
                    onPressed: _isFinalizing ? null : _handleFinal,
                    icon: _isFinalizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isFinalizing ? 'Finalizing...' : 'Final'),
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
      ),
    );
  }
}
