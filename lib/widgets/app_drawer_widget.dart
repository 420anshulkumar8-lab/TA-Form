// lib/widgets/app_drawer_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Side navigation drawer shown on the Home screen. Keeps things simple —
// just informational/utility links, no extra navigation complexity.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_routes.dart';
import '../providers/app_provider.dart';

class AppDrawerWidget extends StatelessWidget {
  const AppDrawerWidget({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rateUs() async {
    // TODO: replace with your actual Play Store package URL once published
    await _openUrl(
        'https://play.google.com/store/apps/details?id=com.railway.taform');
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Railway TA Form app try karein — TA aur Contingent bill aasaani se bharein.\nhttps://play.google.com/store/apps/details?id=com.railway.taform',
    );
  }

  Future<void> _contactUs() async {
    await _openUrl(
        'mailto:support@railwaytaform.app?subject=Railway%20TA%20Form%20-%20Support');
  }

  @override
  Widget build(BuildContext context) {
    final version = context.watch<AppProvider>().appVersion;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1565C0)),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.train,
                        color: Color(0xFF1565C0), size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Railway TA Form',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Rate Us'),
              onTap: _rateUs,
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share App'),
              onTap: _shareApp,
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contact Us'),
              onTap: _contactUs,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Us'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.about),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
            ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Version $version',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
