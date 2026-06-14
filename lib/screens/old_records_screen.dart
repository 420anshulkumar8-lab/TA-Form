// lib/screens/old_records_screen.dart
// Section 6 — Old Records Screen
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ta_session.dart';
import '../providers/app_provider.dart';
import '../services/hive_service.dart';
import '../widgets/status_badge_widget.dart';
import 'draft_preview_screen.dart';
import 'pdf_preview_screen.dart';

class OldRecordsScreen extends StatelessWidget {
  const OldRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    final sessions =
        HiveService.getSessionsForEmployee(profile.employeeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Old TA Records'),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Abhi tak koi TA record nahi hai.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              itemBuilder: (_, i) =>
                  _RecordCard(session: sessions[i]),
            ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final TaSession session;

  const _RecordCard({required this.session});

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitted = session.status == SessionStatus.submitted;
    final totalAmount = session.totalAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isSubmitted && session.pdfPath != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfPreviewScreen(
                  pdfPath: session.pdfPath!,
                  title: '${session.displayLabel} PDF',
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DraftPreviewScreen(session: session),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ───────────────────────────────────────────
              Row(
                children: [
                  Text(
                    session.displayLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  StatusBadgeWidget(status: session.status),
                ],
              ),

              const SizedBox(height: 8),

              // ── TA / Contingent sub-status ────────────────────────────
              Row(
                children: [
                  if (session.selectTa)
                    _SubStatus(
                      label: 'TA',
                      done: session.formDataTa?['status'] ==
                          'submitted',
                    ),
                  if (session.selectTa &&
                      session.selectContingent)
                    const Text('  •  '),
                  if (session.selectContingent)
                    _SubStatus(
                      label: 'Contingent',
                      done: session.formDataContingent?['status'] ==
                          'submitted',
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // ── Amount ────────────────────────────────────────────────
              if (totalAmount > 0)
                Text(
                  'Total: Rs. ${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                  ),
                ),

              const SizedBox(height: 4),

              // ── Last updated ──────────────────────────────────────────
              Text(
                'Updated: ${_formatDateTime(session.lastUpdated)}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),

              // ── Actions for submitted ─────────────────────────────────
              if (isSubmitted && session.pdfPath != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.picture_as_pdf,
                      label: 'View PDF',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewScreen(
                            pdfPath: session.pdfPath!,
                            title: '${session.displayLabel} PDF',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: () => Share.shareXFiles(
                          [XFile(session.pdfPath!)],
                          text: 'TA Form PDF'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubStatus extends StatelessWidget {
  final String label;
  final bool done;

  const _SubStatus({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: done ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${done ? "Done" : "Draft"}',
          style: TextStyle(
            fontSize: 12,
            color: done ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
      ),
    );
  }
}
