// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/app_drawer_widget.dart';
import '../widgets/profile_photo_widget.dart';
import '../widgets/stats_strip_widget.dart';
import 'profile_screen.dart';
import 'month_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.profile;
    final hasProfile = profile.isComplete;

    return Scaffold(
      drawer: const AppDrawerWidget(),
      appBar: AppBar(
        title: const Text('Railway TA Form'),
        actions: [
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.sunny : Icons.nightlight_round,
            ),
            tooltip: provider.isDarkMode ? 'Light Mode' : 'Dark Mode',
            onPressed: () => provider.toggleDarkMode(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Greeting + photo ────────────────────────────────────────────
          Row(
            children: [
              const ProfilePhotoWidget(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasProfile ? profile.name : 'Welcome',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!hasProfile) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Please complete your profile to get started',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Stats strip (only meaningful once profile exists) ──────────
          if (hasProfile) ...[
            StatsStripWidget(employeeNo: profile.employeeNo),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 12),

          // ── Main actions ─────────────────────────────────────────────
          _HomeButton(
            icon: Icons.person,
            label: 'Update Profile',
            subtitle: 'Employee details & level',
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
              if (!hasProfile) {
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
        ],
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
