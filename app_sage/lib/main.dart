import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/usage_service.dart';
import 'ui/usage_list_screen.dart';
import 'dart:io';
import 'package:workmanager/workmanager.dart';


// --- Step 1: Define a unique task name ---
const String fetchUsageTask = "fetchUsageTask";

// Initialize notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Step 2: Initialize WorkManager ---
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, // Set true to see logs in debug
  );

  // --- Step 3: Register periodic task (every 3 hours) ---
  await Workmanager().registerPeriodicTask(
    "1",
    fetchUsageTask,
    frequency: const Duration(hours: 1),
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
  );

  // --- Step 4: Initialize notifications ---
  await initializeNotifications();

  runApp(const MyApp());
}

// --- Step 5: WorkManager callback ---
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == fetchUsageTask) {
      try {
        final usageData = await UsageService.getLast24Hours();

        if (usageData.isNotEmpty) {
          // Pick most used app
          final mostUsedApp = usageData.reduce((a, b) =>
              a.totalTimeInForeground > b.totalTimeInForeground ? a : b);

          // Show notification
          await showNotification(mostUsedApp);
        }
      } catch (e) {
        print("Background task error: $e");
      }
    }
    return Future.value(true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Usage Stats',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usage Stats Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Preload usage data
              final usageData = await UsageService.getLast24Hours();

              if (usageData.isNotEmpty) {
                final mostUsedApp = usageData.reduce((a, b) =>
                    a.totalTimeInForeground > b.totalTimeInForeground ? a : b);

                await showNotification(mostUsedApp);
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UsageListScreen()),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: const Text('Show Last 24 Hours Usage'),
        ),
      ),
    );
  }
}

// --- Step 6: Notifications setup ---
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Persistent channel setup
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'your_channel_id',
    'Usage Notifications',
    description: 'Notifications for most used apps',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// --- Step 7: Show notification ---
Future<void> showNotification(AppUsageModel app) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'your_channel_id',
    'Usage Notifications',
    channelDescription: 'Notifications for most used apps',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Most Used App',
    'App: ${app.packageName}, Time: ${_formatDuration(app.totalTimeInForeground)}',
    platformChannelSpecifics,
    payload: 'item x',
  );

  print(
      'Notification displayed for app: ${app.packageName}, Time: ${_formatDuration(app.totalTimeInForeground)}');
}

String _formatDuration(double seconds) {
  final int totalSeconds = seconds.round();

  if (totalSeconds < 60) return '$totalSeconds sec';
  final int minutes = (totalSeconds / 60).floor();
  if (minutes < 60) return '$minutes min';

  final int hours = (minutes / 60).floor();
  final int remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
