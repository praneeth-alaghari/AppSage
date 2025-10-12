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

    try {
      // Fetch app usage data
      final List<AppUsageInfo> infoList = await AppUsage().getAppUsage(start, end);

      // Map AppUsageInfo to our local AppUsageModel.
      final results = infoList
          .map((info) => AppUsageModel(
                packageName: info.packageName ?? info.appName ?? 'Unknown',
                totalTimeInForeground: info.usage.inSeconds.toDouble(),
              ))
          .toList();

      // Sort by descending foreground time.
      results.sort(
        (a, b) => b.totalTimeInForeground.compareTo(a.totalTimeInForeground),
      );

      return results;
    } catch (e) {
      throw Exception('Failed to fetch app usage: ${e.toString()}');
    }
  }
}