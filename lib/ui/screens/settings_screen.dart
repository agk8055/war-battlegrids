import 'package:flutter/material.dart';
import '../../constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: kMainThemeColor,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_suggest_rounded,
              size: 80,
              color: kMainThemeColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'COMMAND CENTER UNDER CONSTRUCTION',
              style: TextStyle(
                color: kMainThemeColor.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configuration options will be available soon.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
