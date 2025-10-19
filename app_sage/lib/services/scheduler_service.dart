import 'dart:async';
import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'usage_service.dart';
import 'llm_service.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Stream controller that broadcasts the DateTime of the next scheduled notification.
final StreamController<DateTime?> _nextNotificationController = StreamController<DateTime?>.broadcast();
Stream<DateTime?> get nextNotificationStream => _nextNotificationController.stream;

int _alarmMinutes = 5; // current alarm interval in minutes
final _secureStorage = const FlutterSecureStorage();

const MethodChannel _nativeAlarmChannel = MethodChannel('app_sage/native_alarm');

// Listen to native events from MainActivity (e.g., native notification fired)
void _initNativeEventHandler() {
  _nativeAlarmChannel.setMethodCallHandler((call) async {
    if (call.method == 'nativeNotificationFired') {
      final args = Map<String, dynamic>.from(call.arguments ?? {});
      final next = args['next_time'] as String?;
      final summary = args['summary'] as String?;
      if (next != null && next.isNotEmpty) {
        try {
          final dt = DateTime.parse(next);
          _nextNotificationController.add(dt);
          await _secureStorage.write(key: 'next_notification', value: dt.toIso8601String());
        } catch (_) {}
      }
      // If native notification carried a summary (e.g., user tapped a native notification), broadcast it
      if (summary != null && summary.isNotEmpty) {
        try {
          notificationClickStream.add(summary);
        } catch (_) {}
      }
    }
  });
}

/// Initialize scheduler service (set up native event handler and restore persisted next notification)
Future<void> initScheduler() async {
  _initNativeEventHandler();
  final persisted = await persistedNextNotification();
  if (persisted != null) {
    _nextNotificationController.add(persisted);
  }
}

// Native alarm is handled via MethodChannel to Android (AlarmReceiver)

// Keep track of the last alarm for debugging heartbeat
DateTime? _lastAlarmTime;

/// Start a periodic Android alarm that triggers [_alarmHandler] in the background.
Future<void> startAlarmManager({int minutes = 5}) async {
  try {
    print('[Scheduler] Initializing AndroidAlarmManager...');
  _alarmMinutes = minutes;
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
    // Broadcast next notification time to UI listeners
    _nextNotificationController.add(_lastAlarmTime);
      // Persist monitoring state and next notification timestamp for app restarts
      await _secureStorage.write(key: 'monitoring_running', value: 'true');
      await _secureStorage.write(key: 'alarm_minutes', value: minutes.toString());
      await _secureStorage.write(key: 'next_notification', value: _lastAlarmTime!.toIso8601String());
    await showSimpleDebugNotification('Background monitoring started (every ${_humanInterval(minutes)})');
  } catch (e, st) {
    print('[Scheduler] Failed to start AlarmManager: $e');
    print('[Scheduler] StackTrace:\n$st');
    await showSimpleDebugNotification('AlarmManager start failed: $e');
  }
}

String _humanInterval(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = (minutes / 60).round();
  return '${hours} hr${hours > 1 ? 's' : ''}';
}

/// Read the persisted alarm minutes (if any)
Future<int> persistedAlarmMinutes() async {
  final s = await _secureStorage.read(key: 'alarm_minutes');
  if (s == null) return _alarmMinutes;
  try {
    return int.parse(s);
  } catch (_) {
    return _alarmMinutes;
  }
}

/// Append a notification text with timestamp to the last-5 history (keeps newest first)
Future<void> _appendNotificationHistory(String text) async {
  try {
    final raw = await _secureStorage.read(key: 'notif_history');
    final list = raw == null ? <Map<String, dynamic>>[] : 
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    
    // Add new notification with timestamp
    list.insert(0, {
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Keep only last 5 notifications
    while (list.length > 5) {
      list.removeLast();
    }
    
    await _secureStorage.write(key: 'notif_history', value: jsonEncode(list));
  } catch (_) {}
}

/// Gets notification history with timestamps
Future<List<Map<String, dynamic>>> getNotificationHistory() async {
  try {
    final raw = await _secureStorage.read(key: 'notif_history');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (_) {
    return [];
  }
}

/// Clears all notification history
Future<void> clearNotificationHistory() async {
  try {
    await _secureStorage.delete(key: 'notif_history');
  } catch (_) {}
}

/// Converts seconds to human-readable format (e.g., "2h 30m", "45m", "30s")
String _formatTime(double seconds) {
  final int totalSeconds = seconds.round();
  
  if (totalSeconds < 60) {
    return '$totalSeconds sec';
  }
  
  final int minutes = (totalSeconds / 60).floor();
  if (minutes < 60) {
    return '$minutes min';
  }
  
  final int hours = (minutes / 60).floor();
  final int remainingMinutes = minutes % 60;
  
  if (remainingMinutes == 0) {
    return '${hours}h';
  } else {
    return '${hours}h ${remainingMinutes}m';
  }
}

/// Cancel the Android Alarm
Future<void> stopAlarmManager() async {
  try {
    await _nativeAlarmChannel.invokeMethod('stopNativeAlarm');
    print('[Scheduler] AlarmManager cancelled');
    await showSimpleDebugNotification('AlarmManager cancelled');
    await _secureStorage.write(key: 'monitoring_running', value: 'false');
    await _secureStorage.delete(key: 'next_notification');
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

/// Trigger LLM-based usage summary immediately (UI test)
Future<void> performUsageNow() async {
  try {
    await initializeNotifications();
    final usage = await UsageService.getLast24Hours();
    var summary = await summarizeUsageFunny(usage);
    // If LLM unavailable, provide a graceful fallback summary text
    if (summary.startsWith('LLM-unavailable') || summary.startsWith('LLM error') || summary.startsWith('OpenAI API key not set')) {
      // Build a simple fallback: top app + time + note about no LLM
      final top = usage.isNotEmpty ? usage.first : null;
      final topText = top != null ? '${top.packageName} (${_formatTime(top.totalTimeInForeground)})' : 'No usage data';
      summary = 'Top: $topText. No internet / LLM unavailable, so no AI summary.';
    }
    // Show only one notification (prefer native for better reliability)
    try {
      await _nativeAlarmChannel.invokeMethod('showNativeNotification', {'title': 'AppSage', 'body': summary});
    } catch (e) {
      developer.log('showNativeNotification failed: $e');
      // Fallback to Flutter notification if native fails
      await showSimpleDebugNotification(summary);
    }

    // Note: Removed caching to ensure fresh LLM responses every time

    // Save into recent notification history
    try {
      await _appendNotificationHistory(summary);
    } catch (_) {}

    // Compute and broadcast next notification time
  _lastAlarmTime = DateTime.now().add(Duration(minutes: _alarmMinutes));
    _nextNotificationController.add(_lastAlarmTime);
    // Persist next notification for UI restoration
    await _secureStorage.write(key: 'next_notification', value: _lastAlarmTime!.toIso8601String());
  } catch (e, st) {
    print('[Scheduler] performUsageNow error: $e\n$st');
    await showSimpleDebugNotification('Error: ${e.toString()}');
  }
}

/// Returns whether background monitoring was running (persisted) — used by UI to restore state on launch.
Future<bool> wasMonitoringRunning() async {
  final v = await _secureStorage.read(key: 'monitoring_running');
  return v == 'true';
}

/// Returns the persisted next notification time if available.
Future<DateTime?> persistedNextNotification() async {
  final s = await _secureStorage.read(key: 'next_notification');
  if (s == null) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

// Foreground service helpers were removed from this release to avoid unstable API usage.
// We keep performUsageNow() and native AlarmManager for reliable background summaries.

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
  try {
    await initializeNotifications();

    final usage = await UsageService.getLast24Hours();
    var summary = await summarizeUsageFunny(usage);
    if (summary.startsWith('LLM-unavailable') || summary.startsWith('LLM error') || summary.startsWith('OpenAI API key not set')) {
      final top = usage.isNotEmpty ? usage.first : null;
      final topText = top != null ? '${top.packageName} (${_formatTime(top.totalTimeInForeground)})' : 'No usage data';
      summary = 'Top: $topText. No internet / LLM unavailable, so no AI summary.';
    }

    // Broadcast the next notification time to UI listeners so countdown updates.
    try {
      final next = DateTime.now().add(Duration(minutes: _alarmMinutes));
      _nextNotificationController.add(next);
      await _secureStorage.write(key: 'next_notification', value: next.toIso8601String());
    } catch (_) {}
    // Send notification and append to history
    try {
      await showSimpleDebugNotification(summary);
      try { await _appendNotificationHistory(summary); } catch (_) {}
    } catch (e) {
      developer.log('[AlarmHandler] Notification error: $e');
    }
  } catch (e, st) {
    print('[AlarmManager] Error in alarm handler: $e');
    print('[AlarmManager] StackTrace:\n$st');
    await showSimpleDebugNotification('Alarm error: ${e.toString()}');
  }
}
