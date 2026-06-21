// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'profile_screen.dart';
import 'month_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
