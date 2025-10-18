import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'usage_service.dart';

final StreamController<String?> notificationClickStream = StreamController<String?>.broadcast();
String? _launchPayload;

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await _flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    // Broadcast payload when user taps notification
    notificationClickStream.add(response.payload);
  });

  // capture launch payload if app was started via notification
  final details = await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  _launchPayload = details?.notificationResponse?.payload;

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'your_channel_id',
    'Usage Notifications',
    description: 'Notifications for most used apps',
    importance: Importance.high,
  );

  await _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

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

  await _flutterLocalNotificationsPlugin.show(
    0,
    'Most Used App',
    'App: ${app.packageName}, Time: ${_formatDuration(app.totalTimeInForeground)}',
    platformChannelSpecifics,
    payload: app.packageName,
  );
}

Future<void> showSimpleDebugNotification(String body, {String? payload}) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'your_channel_id',
    'Usage Notifications',
    channelDescription: 'Notifications for most used apps',
    importance: Importance.low,
    priority: Priority.low,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await _flutterLocalNotificationsPlugin.show(
    0,
    'AppSage (debug)',
    body,
    platformChannelSpecifics,
    payload: payload ?? body,
  );
}

/// Returns the payload if the app was launched via notification tap.
Future<String?> getLaunchPayload() async => _launchPayload;

String _formatDuration(double seconds) {
  final int totalSeconds = seconds.round();

  if (totalSeconds < 60) return '$totalSeconds sec';
  final int minutes = (totalSeconds / 60).floor();
  if (minutes < 60) return '$minutes min';

  final int hours = (minutes / 60).floor();
  final int remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
