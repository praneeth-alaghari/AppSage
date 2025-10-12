import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../services/usage_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // Open Android Usage Access Settings
  void _openUsageSettings() {
    final intent = AndroidIntent(
      action: 'android.settings.USAGE_ACCESS_SETTINGS',
    );
    intent.launch();
  }

  // Fetch last 24h app usage and print top 5 apps in terminal
  Future<void> _showUsage() async {
    try {
      final usageList = await UsageService.getLast24Hours();

      if (usageList.isEmpty) {
        print('No usage data found.');
        return;
      }

      final topApps = usageList.take(5).toList();

      print('=== Top 5 Apps in Last 24 Hours ===');
      for (var app in topApps) {
        print(
            '${app.packageName}: ${(app.totalTimeInForeground / 1000).toStringAsFixed(0)} seconds');
      }
      print('==================================');
    } catch (e) {
      print('Error fetching usage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AppSage Welcome')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to AppSage!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openUsageSettings,
              child: const Text('Grant Usage Access'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showUsage,
              child: const Text('Fetch Last 24h Usage (Print in Terminal)'),
            ),
          ],
        ),
      ),
    );
  }
}
