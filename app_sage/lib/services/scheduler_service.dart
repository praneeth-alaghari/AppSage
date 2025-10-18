import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'usage_service.dart';
import 'llm_service.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

const MethodChannel _nativeAlarmChannel = MethodChannel('app_sage/native_alarm');

// Native alarm is handled via MethodChannel to Android (AlarmReceiver)

// Keep track of the last alarm for debugging heartbeat
DateTime? _lastAlarmTime;
Timer? _heartbeatTimer;

/// Start a periodic Android alarm that triggers [_alarmHandler] in the background.
Future<void> startAlarmManager({int minutes = 5}) async {
  try {
    print('[Scheduler] Initializing AndroidAlarmManager...');
    // On Android 13+ we must request POST_NOTIFICATIONS permission at runtime
    if (Platform.isAndroid) {
      try {
        if (await Permission.notification.isDenied) {
          final status = await Permission.notification.request();
          print('[Scheduler] Notification permission status: $status');
        }
      } catch (e) {
        print('[Scheduler] permission_handler error: $e');
      }
    }
    // Use native alarm via MethodChannel for best reliability when app is killed
    final res = await _nativeAlarmChannel.invokeMethod('startNativeAlarm', {'minutes': minutes});
    print('[Scheduler] Native alarm start result: $res');
    _lastAlarmTime = DateTime.now().add(Duration(minutes: minutes));
    await showSimpleDebugNotification('Native Alarm scheduled every $minutes minutes');
  } catch (e, st) {
    print('[Scheduler] Failed to start AlarmManager: $e');
    print('[Scheduler] StackTrace:\n$st');
    await showSimpleDebugNotification('AlarmManager start failed: $e');
  }
}

/// Cancel the Android Alarm
Future<void> stopAlarmManager() async {
  try {
    await _nativeAlarmChannel.invokeMethod('stopNativeAlarm');
    _heartbeatTimer?.cancel();
    print('[Scheduler] AlarmManager cancelled');
    await showSimpleDebugNotification('AlarmManager cancelled');
  } catch (e, st) {
    print('[Scheduler] Failed to cancel AlarmManager: $e');
    print('[Scheduler] StackTrace:\n$st');
  }
}

/// WorkManager periodic registration (hourly as requested)
Future<void> registerWorkManager({Duration frequency = const Duration(hours: 1)}) async {
  await Workmanager().initialize((task, inputData) async {
    print('[WorkManager] executing task $task at ${DateTime.now()}');
    try {
      final usage = await UsageService.getLast24Hours();
      final summary = await summarizeUsageFunny(usage);
      await showSimpleDebugNotification('WorkManager: $summary');
    } catch (e, st) {
      print('[WorkManager] error: $e');
      print('[WorkManager] StackTrace:\n$st');
      await showSimpleDebugNotification('WorkManager error: ${e.toString()}');
    }
    return Future.value(true);
  });

  await Workmanager().registerPeriodicTask(
    'workmanager_periodic',
    'fetchUsageTask',
    frequency: frequency,
  );
  print('[Scheduler] WorkManager registered with frequency $frequency');
}

/// Cancel WorkManager
Future<void> cancelWorkManager() async {
  await Workmanager().cancelByUniqueName('workmanager_periodic');
  print('[Scheduler] WorkManager cancelled');
}

/// The alarm handler triggered by AndroidAlarmManager
@pragma('vm:entry-point')
void _alarmHandler() async {
  final now = DateTime.now();
  _lastAlarmTime = now;
  print('[AlarmManager] Alarm fired at $now');

  // Heartbeat timer to log service status
  try {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_lastAlarmTime == null) return;
      final nextAlarm = _lastAlarmTime!.add(const Duration(minutes: 5));
      final diff = nextAlarm.difference(DateTime.now());
      print('[Heartbeat] Next alarmz in ${diff.inSeconds}s at $nextAlarm');
      print('[Heartbeat] Service running 1. Current time: ${DateTime.now()}');

      if (diff.inSeconds <= -10) {
        timer.cancel();
      }
    });
  } catch (e, st) {
    print('[Heartbeat] Timer error: $e\n$st');
  }

  try {
    await initializeNotifications();

    final usage = await UsageService.getLast24Hours();
    final summary = await summarizeUsageFunny(usage);

    print('[AlarmManager] Showing notification: $summary');
    await showSimpleDebugNotification('Alarm fired: $summary');
  } catch (e, st) {
    print('[AlarmManager] Error in alarm handler: $e');
    print('[AlarmManager] StackTrace:\n$st');
    await showSimpleDebugNotification('Alarm error: ${e.toString()}');
  }
}
