// lib/screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Data Storage',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'All the information you enter — your profile, TA entries, '
            'Contingent entries, and any profile photo you add — is stored '
            'only on your own device. Nothing is uploaded to any server.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 20),
          Text(
            'PDF Generation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'PDFs are generated locally on your device. Sharing or printing '
            'a generated PDF is entirely your choice, using your phone\'s '
            'own share/print options.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 20),
          Text(
            'Permissions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'The app may request storage/photo access only to let you '
            'attach an optional profile photo and save/share generated '
            'PDFs.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 20),
          Text(
            'Contact',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'For any privacy questions, use the Contact Us option from the '
            'side menu.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
