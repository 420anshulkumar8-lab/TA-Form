// lib/screens/pdf_preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String pdfPath;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.pdfPath,
    this.title = 'TA Form PDF',
  });

  @override
  Widget build(BuildContext context) {
    final file = File(pdfPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Share
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: () =>
                Share.shareXFiles([XFile(pdfPath)],
                    text: 'Railway TA Form PDF'),
          ),
          // Print
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print PDF',
            onPressed: () async {
              final bytes = await file.readAsBytes();
              await Printing.layoutPdf(
                  onLayout: (_) async => bytes);
            },
          ),
          // Save to Downloads
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save to Downloads',
            onPressed: () => _saveToDownloads(context, file),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => file.readAsBytes(),
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'railway_ta_form.pdf',
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.share),
        label: const Text('Share'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        onPressed: () =>
            Share.shareXFiles([XFile(pdfPath)],
                text: 'Railway TA Form PDF'),
      ),
    );
  }

  Future<void> _saveToDownloads(
      BuildContext context, File file) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Storage not available');
      final dest = File('${dir.path}/${file.uri.pathSegments.last}');
      await file.copy(dest.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Saved to ${dest.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
