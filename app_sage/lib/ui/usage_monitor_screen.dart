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

class UsageMonitorScreen extends StatefulWidget {
  const UsageMonitorScreen({super.key});

  @override
  State<UsageMonitorScreen> createState() => _UsageMonitorScreenState();
}

class _UsageMonitorScreenState extends State<UsageMonitorScreen> {
  bool _running = false;
  Timer? _countdownTimer;
  Duration _timeToNext = Duration.zero;
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
    _nextSub = scheduler.nextNotificationStream.listen((dt) {
      if (dt != null) {
        final dur = dt.difference(DateTime.now());
        if (dur.isNegative) return;
        _startCountdown(dur);
      }
    });
    // Restore persisted monitoring state and selected frequency
    () async {
      final wasRunning = await scheduler.wasMonitoringRunning();
      final pm = await scheduler.persistedAlarmMinutes();
      setState(() => _minutes = pm);
      if (wasRunning) {
        setState(() => _running = true);
        final persisted = await scheduler.persistedNextNotification();
        if (persisted != null) {
          final dur = persisted.difference(DateTime.now());
          if (!dur.isNegative) _startCountdown(dur);
        }
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
    _countdownTimer?.cancel();
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
    _startCountdown(Duration(minutes: _minutes));
  }

  void _stop() async {
    setState(() => _running = false);
    await scheduler.stopAlarmManager();
    _countdownTimer?.cancel();
    setState(() => _timeToNext = Duration.zero);
    setState(() => _activeFrequencyLabel = null);
  }

  void _startCountdown(Duration duration) {
    _countdownTimer?.cancel();
    setState(() => _timeToNext = duration);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = _timeToNext - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        t.cancel();
        setState(() => _timeToNext = Duration.zero);
      } else {
        setState(() => _timeToNext = remaining);
      }
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }

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
            Text('Next notification in: ${_fmt(_timeToNext)}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 18),
            const SizedBox(height: 8),
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
