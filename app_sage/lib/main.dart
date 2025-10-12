import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Add this import
import 'services/usage_service.dart';
import 'ui/usage_list_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io'; // add this import


void main() {
  runApp(const MyApp());
}

// Initialize notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
  // Initialize notifications in your app
    initializeNotifications();

    return MaterialApp(
      title: 'App Usage Stats',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }

  // Initialize notifications in your app
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // ---- Persistent channel setup (point 4) ----
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'your_channel_id', // Same ID used in showNotification()
    'Usage Notifications', // Channel name
    description: 'Notifications for most used apps',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
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

              // Find the most used app
              AppUsageModel mostUsedApp;
              if (usageData.isNotEmpty) {
                mostUsedApp = usageData.reduce((a, b) =>
                  a.totalTimeInForeground > b.totalTimeInForeground ? a : b);

                // Trigger a notification with the most used app details
                await showNotification(mostUsedApp);
              }

              // Navigate to UsageListScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UsageListScreen()),
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

// Function to format duration into a readable string
String _formatDuration(double seconds) {
  final int milliseconds = (seconds * 1000).round(); // Convert seconds to milliseconds
  final int totalSeconds = milliseconds ~/ 1000; // Getting the total seconds from milliseconds

  if (totalSeconds < 60) return '$totalSeconds sec';
  final int minutes = (totalSeconds / 60).floor();
  if (minutes < 60) return '$minutes min';

  final int hours = (minutes / 60).floor();
  final int remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}

// Notification function with updated details
Future<void> showNotification(AppUsageModel app) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'your_channel_id', // Channel ID
    'your_channel_name', // Channel Name
    channelDescription: 'your_channel_description', // Channel Description
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

  // Log whether the notification was popped up
  print('Notification displayed for app: ${app.packageName}, Time: ${_formatDuration(app.totalTimeInForeground)}');
}





