import 'dart:io';
import 'package:flutter/material.dart';

/// Service to handle platform-specific functionality and iOS compatibility
class PlatformService {
  /// Checks if the current platform is iOS
  static bool get isIOS => Platform.isIOS;
  
  /// Checks if the current platform is Android
  static bool get isAndroid => Platform.isAndroid;
  
  /// Shows a platform-specific error dialog for unsupported features
  static void showUnsupportedFeatureDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feature Not Available'),
        content: Text(
          isIOS 
            ? '$feature is currently only available on Android. We\'re working on iOS support!'
            : '$feature is not available on this platform.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Checks if app usage access is available on current platform
  static bool get isAppUsageAccessAvailable => isAndroid;
  
  /// Gets platform-specific notification channel importance
  static String getNotificationChannelImportance() {
    return isIOS ? 'high' : 'high';
  }
  
  /// Shows a dialog explaining iOS limitations
  static void showIOSLimitationsDialog(BuildContext context) {
    if (!isIOS) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('iOS Limitations'),
          ],
        ),
        content: const Text(
          'On iOS, some features have limitations:\n\n'
          '• App usage tracking requires Screen Time API\n'
          '• Background notifications may be restricted\n'
          '• Some features work differently than on Android\n\n'
          'We\'re continuously improving iOS support!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
  
  /// Gets platform-specific app name
  static String getAppName() {
    return 'App Sage';
  }
  
  /// Gets platform-specific app description
  static String getAppDescription() {
    return isIOS 
      ? 'Your digital wellness companion (iOS)'
      : 'Your all-in-one pocket companion for digital wellness';
  }
}
