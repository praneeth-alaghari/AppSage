import 'package:flutter/material.dart';
import '../services/usage_service.dart';

class NotificationDetailScreen extends StatelessWidget {
  final String payload;
  final List<AppUsageModel> usage;

  const NotificationDetailScreen({
    super.key,
    required this.payload,
    required this.usage,
  });

  @override
  Widget build(BuildContext context) {
    final top5 = usage.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payload, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'Top 5 apps:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...top5.map((u) => ListTile(
                  title: Text(u.packageName.split('.').last),
                  trailing: Text('${u.totalTimeInForeground.round()}s'),
                )),
            const SizedBox(height: 12),
            const Text(
              'All app usage (descending):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: usage.length,
                itemBuilder: (context, index) {
                  final u = usage[index];
                  return ListTile(
                    title: Text(u.packageName),
                    trailing: Text('${u.totalTimeInForeground.round()}s'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
