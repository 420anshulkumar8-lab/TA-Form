// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import 'profile_screen.dart';
import 'month_selection_screen.dart';
import 'old_records_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<String> _languages = [
    'Hindi', 'English', 'Hinglish', 'Punjabi', 'Bengali',
    'Marathi', 'Tamil', 'Telugu', 'Gujarati', 'Kannada', 'Urdu',
  ];

  // ── Language picker — ChoiceChips (Claude_Original style — better UX)
  void _showLanguagePicker(BuildContext context) {
    final provider = context.read<AppProvider>();
    final customController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('App Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // ChoiceChips — quick and clear
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _languages.map((lang) {
                  final selected = provider.appLanguage == lang;
                  return ChoiceChip(
                    label: Text(lang),
                    selected: selected,
                    onSelected: (_) {
                      provider.setAppLanguage(lang);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Custom language field
              TextField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: 'Other language (type here)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      if (customController.text.trim().isNotEmpty) {
                        provider.setAppLanguage(customController.text.trim());
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Side drawer (Claude_Copy base + working links)
  Widget _buildDrawer(BuildContext context, AppProvider provider) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1565C0)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 60, height: 60,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.train, size: 60, color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Railway TA Form',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Us'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Railway TA Form',
                applicationVersion: provider.appVersion,
                children: const [
                  Text('AI-powered Travel Allowance form assistant for '
                      'Railway employees. Fill GA-31 forms conversationally '
                      'and generate official PDFs.'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Us'),
            onTap: () {
              Navigator.pop(context);
              launchUrl(Uri.parse('mailto:support@example.com'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate Us'),
            onTap: () {
              Navigator.pop(context);
              launchUrl(Uri.parse('https://play.google.com/store/apps'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share App'),
            onTap: () {
              Navigator.pop(context);
              Share.share('Railway TA Form — AI se TA form asaani se bharo!');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('Version ${provider.appVersion}'),
            enabled: false,
          ),
          ListTile(
            leading: Icon(
              provider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            title: Text(provider.isDarkMode ? 'Dark Theme' : 'Light Theme'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Railway TA Form'),
        actions: [
          TextButton(
            onPressed: () => _showLanguagePicker(context),
            child: Text(provider.appLanguage,
                style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.sunny : Icons.nightlight_round,
            ),
            tooltip: provider.isDarkMode ? 'Light Mode' : 'Dark Mode',
            onPressed: () => provider.toggleDarkMode(),
          ),
        ],
      ),
      drawer: _buildDrawer(context, provider),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // API warning banner (from Claude_Copy)
            if (provider.configError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(provider.configError!,
                          style: const TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              ),

            // Home buttons — Claude_Original style (colored + subtitle)
            _HomeButton(
              icon: Icons.person,
              label: 'Update Profile',
              subtitle: 'Employee details & grade',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            const SizedBox(height: 16),
            _HomeButton(
              icon: Icons.description,
              label: 'Fill TA Form',
              subtitle: 'Fill monthly travel allowance',
              color: const Color(0xFF2E7D32),
              onTap: () {
                if (!provider.profile.isComplete) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pehle profile fill karein'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  return;
                }
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MonthSelectionScreen()));
              },
            ),
            const SizedBox(height: 16),
            _HomeButton(
              icon: Icons.folder_open,
              label: 'My Old TA Records',
              subtitle: 'View, print & share past forms',
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OldRecordsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(subtitle,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
