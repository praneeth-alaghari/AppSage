import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'openai_key.dart';
import 'usage_service.dart';

/// Converts seconds to human-readable format (e.g., "2h 30m", "45m", "30s")
String _formatDuration(double seconds) {
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

/// Generates a more varied random seed using multiple factors
/// This ensures different responses even when called at similar times
int _generateVariedSeed() {
  final now = DateTime.now();
  // Combine multiple time components and add some randomness
  return now.millisecondsSinceEpoch + 
         now.microsecond + 
         (now.second * 1000) + 
         (now.minute * 60000) +
         (now.hour * 3600000) +
         (now.day * 86400000) + // Add day for more variation
         (now.weekday * 1000000); // Add weekday for weekly variation
}

/// Summarize the last 24h usage into a single sentence using OpenAI.
/// This function chooses from a variety of prompt templates to ensure
/// different responses even in background monitoring scenarios.
Future<String> summarizeUsageFunny(List<AppUsageModel> usage) async {
  if (usage.isEmpty) return 'No apps used in the last 24 hours.';

  final top = usage.first;
  final humanReadableTime = _formatDuration(top.totalTimeInForeground);
  final appName = top.packageName.split('.').last;

  // Expanded set of prompt templates with more variation and personal touch
  final templates = [
    'You spent $humanReadableTime on $appName today! Write a funny, personal comment about this addiction.',
    'Your phone usage report: $appName got $humanReadableTime of your precious time. Make a witty, self-aware joke about this.',
    'You and $appName had a $humanReadableTime date today. Write a humorous, personal observation about this relationship.',
    'Congratulations! You gave $appName $humanReadableTime of your life today. Make a funny, slightly judgmental comment.',
    'Your digital confession: $appName consumed $humanReadableTime today. Write a playful, self-deprecating joke.',
    'You basically lived inside $appName for $humanReadableTime today. Make a funny, personal comment about this obsession.',
    'Your screen time shows $appName got $humanReadableTime of attention today. Write a humorous, slightly concerned observation.',
    'You and $appName are basically in a $humanReadableTime relationship now. Make a funny, personal comment about this.',
    'Your phone says you spent $humanReadableTime on $appName today. Write a witty, self-aware joke about this habit.',
    'You gave $appName $humanReadableTime of your day. Make a funny, slightly sarcastic comment about this dedication.',
    'Your usage report: $appName was your $humanReadableTime companion today. Write a humorous, personal observation.',
    'You basically married $appName for $humanReadableTime today. Make a funny, self-deprecating joke about this.',
  ];

  // Use a more varied random seed to ensure different selections
  final rng = Random(_generateVariedSeed());
  final prompt = templates[rng.nextInt(templates.length)];

  final apiKey = OpenAIKey.apiKey;
  if (apiKey.isEmpty) return 'OpenAI API key not set.';

  try {
    final resp = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': 'You are a concise, witty assistant that returns a single sentence. Be creative and vary your responses.'},
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 80,
        'temperature': 0.9, // Increased temperature for more variation
      }),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      return 'LLM error: ${resp.statusCode}';
    }

    final j = jsonDecode(resp.body);
    final text = j['choices']?[0]?['message']?['content'] as String?;
    return text?.trim() ?? 'No summary returned.';
  } catch (e) {
    // Bubble up a clear message so callers can provide a fallback.
    return 'LLM-unavailable: ${e.toString()}';
  }
}
