import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
// notifications are initialized in services/notification_service.dart
import 'services/usage_service.dart';
import 'services/llm_service.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart' as scheduler;
import 'ui/usage_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ui/usage_monitor_screen.dart';

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
  // Initialize scheduler (native event handler)
  await scheduler.initScheduler();
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
  // monitoring is managed by UsageMonitorScreen
  StreamSubscription<String?>? _clickSub;
  final _storage = const FlutterSecureStorage();
  String? _userName;
  String? _profileId;
  bool _showLogo = true;

  @override
  void initState() {
    super.initState();

    // If the app launched from a notification, get the payload and navigate.
    () async {
      final payload = await getLaunchPayload();
      if (payload != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageListScreen()));
        });
      }
    }();

    _clickSub = notificationClickStream.stream.listen((payload) async {
      if (payload != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageListScreen()));
      }
    });

    // Removed debug heartbeat logging

    // Load user profile and show brief logo animation
    _loadProfileAndAnimate();
  }

  Future<void> _loadProfileAndAnimate() async {
    // small logo animation duration
    final name = await _storage.read(key: 'user_name');
    final id = await _storage.read(key: 'profile_id');
    setState(() {
      _userName = name;
      _profileId = id;
    });

    // show animated logo for 1.2 seconds
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _showLogo = false);

    // If no name set, ask for it
    if (_userName == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _askForName();
    }
  }

  Future<void> _askForName() async {
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Welcome! What should we call you?'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Your name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Skip')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      final generatedId = 'profile_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000)}';
      await _storage.write(key: 'user_name', value: res);
      await _storage.write(key: 'profile_id', value: generatedId);
      setState(() {
        _userName = res;
        _profileId = generatedId;
      });
    }
  }

  @override
  void dispose() {
    _clickSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Sage')),
      body: Center(
        child: _showLogo
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: _showLogo ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 900),
                    child: const FlutterLogo(size: 120),
                  ),
                  const SizedBox(height: 12),
                  Text(_userName != null ? 'Welcome, $_userName' : 'Welcome to App Sage', style: const TextStyle(fontSize: 18)),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(_userName != null ? 'Hello, $_userName' : 'Hello', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 16),
                    // Cards grid
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageMonitorScreen())),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.notifications_active, size: 36),
                                SizedBox(height: 8),
                                Text('App Usage\nNotifications', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Mail summarizer - coming soon'))))),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.mail_outline, size: 36),
                                SizedBox(height: 8),
                                Text('Mail\nSummarizer', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Profile ID: ${_profileId ?? "(not set)"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
      ),
    );
  }

  // Start/stop handled in UsageMonitorScreen
}

// --------------------------------------------------
// FOREGROUND START CALLBACK
// --------------------------------------------------
// no-op: foreground task removed in favor of WorkManager/alarm-based scheduling
