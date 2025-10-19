import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/scheduler_service.dart' as scheduler;
import '../services/usage_service.dart';
import '../services/notification_service.dart';
import '../services/platform_service.dart';
import 'usage_list_screen.dart';
import 'notification_history_screen.dart';
import 'usage_analytics_screen.dart';

class UsageMonitorScreen extends StatefulWidget {
  const UsageMonitorScreen({super.key});

  @override
  State<UsageMonitorScreen> createState() => _UsageMonitorScreenState();
}

class _UsageMonitorScreenState extends State<UsageMonitorScreen> {
  bool _running = false;
  int _minutes = 5;
  StreamSubscription<DateTime?>? _nextSub;
  StreamSubscription<String?>? _notifClickSub;
  String? _activeFrequencyLabel;

  String _humanInterval(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = (minutes / 60).round();
    return '${hours} hr${hours > 1 ? 's' : ''}';
  }

  @override
  void initState() {
    super.initState();
    _ensurePermissions();
    // Listen for scheduler broadcast about next notification time
    // Restore persisted monitoring state and selected frequency
    () async {
      final wasRunning = await scheduler.wasMonitoringRunning();
      final pm = await scheduler.persistedAlarmMinutes();
      setState(() => _minutes = pm);
      if (wasRunning) {
        setState(() => _running = true);
        setState(() => _activeFrequencyLabel = _humanInterval(pm));
      }
    }();

    // Listen for notification clicks to navigate to usage list
    _notifClickSub = notificationClickStream.stream.listen((payload) {
      if (payload != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => UsageListScreen(initialSummary: payload)));
      }
    });
  }

  @override
  void dispose() {
    _nextSub?.cancel();
    _notifClickSub?.cancel();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    // Request notification permission
    try {
      await Permission.notification.request();
    } catch (_) {}

    // For usage access permission - Android only
    if (PlatformService.isAndroid) {
      try {
        final available = await _checkUsageAccess();
        if (!available) {
          await _openUsageAccessSettings();
        }
      } catch (_) {}
    } else {
      // Show iOS limitations dialog
      PlatformService.showIOSLimitationsDialog(context);
    }
  }

  Future<bool> _checkUsageAccess() async {
    if (!PlatformService.isAndroid) return false;
    
    try {
      // Platform channel could be used for more precise check; for now just attempt to fetch usage
      final usage = await UsageService.getLast24Hours();
      return usage.isNotEmpty || true; // conservative: allow
    } catch (_) {
      return false;
    }
  }

  Future<void> _openUsageAccessSettings() async {
    if (PlatformService.isAndroid) {
      await MethodChannel('app_sage/package_info').invokeMethod('openUsageAccessSettings');
    } else {
      PlatformService.showUnsupportedFeatureDialog(context, 'Usage Access Settings');
    }
  }

  void _start() async {
    setState(() => _running = true);
    await _ensurePermissions();
    // Start native alarm / WorkManager using the scheduler abstraction
    await scheduler.startAlarmManager(minutes: _minutes);
    setState(() => _activeFrequencyLabel = _humanInterval(_minutes));
  }

  void _stop() async {
    setState(() => _running = false);
    await scheduler.stopAlarmManager();
    setState(() => _activeFrequencyLabel = null);
  }

  // Countdown removed — scheduling is handled natively and UI will show active frequency only.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Usage Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Background Monitoring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running ? _stop : _start,
                    icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                    label: Text(_running ? 'Stop Background Monitoring' : 'Start Background Monitoring'),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _minutes,
                  items: const [1, 5, 15, 30, 180, 360, 720, 1440].map((m) {
                    final label = m < 60 ? '$m min' : '${(m / 60).round()} hr';
                    return DropdownMenuItem(value: m, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _minutes = v);
                  },
                )
              ],
            ),
            const SizedBox(height: 12),
            if (_activeFrequencyLabel != null)
              Text('Monitoring: $_activeFrequencyLabel', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const SizedBox(height: 18),
            const SizedBox(height: 8),
            // Modernized cards: Analytics and History moved into Notifications page
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageAnalyticsScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.analytics, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Analytics\n(Last 24h)', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageListScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.history, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('History', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageListScreen())),
              child: const Text('View Last 24h Usage'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
              ),
              child: const Text('View Notification History'),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Notes:\n• The app will request Usage Access permission if not enabled.\n• Notifications are posted natively for reliability when the app is backgrounded or killed.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Trigger LLM-based summary now
                try {
                  await scheduler.performUsageNow();
                  if (mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Send Test Summary Notification'),
            ),
          ],
        ),
      ),
    );
  }
}
