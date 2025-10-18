import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
// notifications are initialized in services/notification_service.dart
import 'services/usage_service.dart';
import 'services/llm_service.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart' as scheduler;
import 'ui/notification_detail_screen.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

// --------------------------------------------------
// CONFIG FLAG
// --------------------------------------------------
const bool useForegroundService = true; // 🔁 switch to false for WorkManager
const Duration foregroundInterval = Duration(minutes: 2);
const Duration workManagerInterval = Duration(hours: 1);
const String fetchUsageTask = 'fetchUsageTask';

// --------------------------------------------------
// SHARED BACKGROUND LOGIC
// --------------------------------------------------
Future<void> performUsageLogic() async {
  try {
    // Ensure notifications are initialized in whichever isolate calls this.
    await initializeNotifications();

    // Fetch real usage data
    final usage = await UsageService.getLast24Hours();

    // Prepare LLM summary using provided OpenAI key
    final summary = await summarizeUsageFunny(usage);

    // Show the summary in a notification
    await showSimpleDebugNotification(summary);

    // Debug log
    print("[UsageLogic] Notification sent at ${DateTime.now()}");
  } catch (e) {
    // Fallback: show simple message
    await showSimpleDebugNotification('Error generating summary: ${e.toString()}');
    print("[UsageLogic] Error: $e");
  }
}

// --------------------------------------------------
// WORKMANAGER CALLBACK
// --------------------------------------------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("[WorkManager] Task executed at ${DateTime.now()}");
    await performUsageLogic();
    return Future.value(true);
  });
}

// --------------------------------------------------
// ANDROID ALARM CALLBACK (runs even when app is closed)
// --------------------------------------------------
@pragma('vm:entry-point')
void alarmCallback() {
  print("[AlarmManager] Alarm triggered at ${DateTime.now()}");
  performUsageLogic();
}

// --------------------------------------------------
// MAIN APP
// --------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications (centralized implementation)
  await initializeNotifications();

  // Initialize WorkManager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  await Workmanager().registerPeriodicTask(
    '1',
    fetchUsageTask,
    frequency: workManagerInterval,
  );

  runApp(const MyApp());
}

// --------------------------------------------------
// UI
// --------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Sage',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _serviceRunning = false;
  bool _useAlarm = true; // toggle between Alarm (1 min test) and WorkManager (1 hr)
  StreamSubscription<String?>? _clickSub;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();

    // If the app launched from a notification, get the payload and navigate.
    () async {
      final payload = await getLaunchPayload();
      if (payload != null && mounted) {
        final usage = await UsageService.getLast24Hours();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationDetailScreen(payload: payload, usage: usage)));
        });
      }
    }();

    _clickSub = notificationClickStream.stream.listen((payload) async {
      if (payload != null && mounted) {
        final usage = await UsageService.getLast24Hours();
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => NotificationDetailScreen(payload: payload, usage: usage)));
      }
    });

    // Heartbeat timer (debug)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_serviceRunning) {
        print("[Heartbeat] Service running 0. Current time: ${DateTime.now()}");
      }
    });
  }

  @override
  void dispose() {
    _clickSub?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Sage Background Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              useForegroundService
                  ? 'ForegroundService mode 🧠'
                  : 'WorkManager mode 🕓',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _useAlarm,
                  onChanged: (v) => setState(() => _useAlarm = v),
                ),
                const SizedBox(width: 8),
                Text(_useAlarm ? 'Alarm (1m test)' : 'WorkManager (1h)')
              ],
            ),

            ElevatedButton.icon(
              onPressed: _serviceRunning ? _stopService : _startService,
              icon: Icon(_serviceRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_serviceRunning ? 'Stop Background Monitoring' : 'Start Background Monitoring'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: performUsageLogic,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.notifications_active),
                  SizedBox(width: 8),
                  Text('Send Test Summary Notification')
                ],
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                // request permission on Android 13+
                if (Platform.isAndroid) {
                  try {
                    final res = await MethodChannel('app_sage/native_alarm').invokeMethod('showNativeNotification', {
                      'title': 'AppSage Test',
                      'body': 'This is a native notification test'
                    });
                    print('showNativeNotification result: $res');
                  } catch (e) {
                    print('Native notification error: $e');
                  }
                } else {
                  await performUsageLogic();
                }
              },
              child: const Text('Request Permission + Show Native Notification'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startService() async {
    setState(() => _serviceRunning = true);
    if (_useAlarm) {
      await scheduler.startAlarmManager(minutes: 1);
    } else {
      await scheduler.registerWorkManager(frequency: const Duration(hours: 1));
    }
  }

  Future<void> _stopService() async {
    if (_useAlarm) {
      await scheduler.stopAlarmManager();
    } else {
      await scheduler.cancelWorkManager();
    }
    setState(() => _serviceRunning = false);
  }
}

// --------------------------------------------------
// FOREGROUND START CALLBACK
// --------------------------------------------------
// no-op: foreground task removed in favor of WorkManager/alarm-based scheduling
