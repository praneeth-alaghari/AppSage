import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UsageListScreen extends StatelessWidget {
  final String? initialSummary;
  const UsageListScreen({super.key, this.initialSummary});

  static const MethodChannel _packageChannel = MethodChannel('app_sage/package_info');

  Future<void> _openUsageAccessSettings() async {
    try {
      await _packageChannel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Last 24h Usage')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (initialSummary != null) ...[
              const Text('Notification Summary:'),
              const SizedBox(height: 8),
              Text(initialSummary!),
              const SizedBox(height: 16),
            ],
            const Text('Usage list (minimal view)'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _openUsageAccessSettings(),
              child: const Text('Open Usage Access settings'),
            ),
          ],
        ),
      ),
    );
  }
}