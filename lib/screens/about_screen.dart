// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final version = context.watch<AppProvider>().appVersion;

    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.train, size: 44, color: Color(0xFF1565C0)),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Railway TA Form',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              'Version $version',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Railway TA Form helps railway employees fill their monthly '
            'Travel Allowance (GA-31) and Contingent Bill quickly and '
            'accurately, then generate a ready-to-submit PDF — all stored '
            'safely on your own device.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'This app is not an official Indian Railways product. It is an '
            'independent tool built to make TA form filling easier.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }
}
