import 'package:app_usage/app_usage.dart';

/// Lightweight local model to represent app usage info.
class AppUsageModel {
  final String packageName;
  final double totalTimeInForeground;

  AppUsageModel({
    required this.packageName,
    required this.totalTimeInForeground,
  });

  @override
  String toString() =>
      'AppUsageModel($packageName: ${totalTimeInForeground.toStringAsFixed(2)}s)';
}

class UsageService {
  /// Fetch app usage stats for the last 24 hours.
  /// Returns a list of [AppUsageModel] sorted by descending foreground time.
  static Future<List<AppUsageModel>> getLast24Hours() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 24));
    final end = now;

    print('Fetching app usage data from $start to $end'); // Logging start time

    try {
      // Fetch app usage data
      final List<AppUsageInfo> infoList = await AppUsage().getAppUsage(start, end);
      print('Retrieved ${infoList.length} app usage records'); // Logging number of apps retrieved

      // Map AppUsageInfo to our local AppUsageModel.
      final results = infoList
          .map((info) => AppUsageModel(
                packageName: info.packageName ?? info.appName ?? 'Unknown',
                totalTimeInForeground: info.usage.inSeconds.toDouble(),
              ))
          .toList();

      // Print usage statistics in terminal
      for (var appUsage in results) {
        print(appUsage);  // Print each app's usage information
      }

      // Sort by descending foreground time.
      results.sort(
        (a, b) => b.totalTimeInForeground.compareTo(a.totalTimeInForeground),
      );

      return results;
    } catch (e) {
      print('Error fetching app usage data: ${e.toString()}'); // Logging error
      throw Exception('Failed to fetch app usage: ${e.toString()}');
    }
  }
}