import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'openai_key.dart';
import 'usage_service.dart';

/// Summarize the last 24h usage into a single sentence using OpenAI.
/// This function chooses from a few lightweight prompt templates to avoid
/// producing identical outputs every time.
Future<String> summarizeUsageFunny(List<AppUsageModel> usage) async {
  if (usage.isEmpty) return 'No apps used in the last 24 hours.';

  final top = usage.first;

  // A small set of prompt templates to add variation to results.
  final templates = [
    'In one witty sentence, say which app was used the most in the last 24 hours. Top app: ${top.packageName} (${top.totalTimeInForeground.round()}s).',
    'Summarize in a single playful line the most-used app in the past day: ${top.packageName} — ${top.totalTimeInForeground.round()} seconds.',
    'Give a concise, slightly humorous one-liner announcing the top app: ${top.packageName} used for ${top.totalTimeInForeground.round()}s in the last 24 hours.',
    'One short, creative sentence that highlights the top app (${top.packageName}) and its total foreground time (${top.totalTimeInForeground.round()} seconds).'
  ];

  final rng = Random(DateTime.now().millisecondsSinceEpoch);
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
          {'role': 'system', 'content': 'You are a concise, witty assistant that returns a single sentence.'},
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 60,
        'temperature': 0.8,
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
