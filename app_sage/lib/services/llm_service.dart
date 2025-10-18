import 'dart:convert';
import 'package:http/http.dart' as http;
import 'openai_key.dart';
import 'usage_service.dart';

/// Summarize the last 24h usage into a single funny sentence using OpenAI.
Future<String> summarizeUsageFunny(List<AppUsageModel> usage) async {
  if (usage.isEmpty) return 'No apps used in the last 24 hours.';

  final top = usage.first;
  final prompt =
      'In one funny sentence, tell me which app was used the most in the last 24 hours.\nTop app: ${top.packageName} with ${top.totalTimeInForeground} seconds.';

  final apiKey = OpenAIKey.apiKey;
  if (apiKey == null || apiKey.isEmpty) return 'OpenAI API key not set.';

  final resp = await http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': 'You are a witty assistant.'},
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 60,
    }),
  );

  if (resp.statusCode != 200) {
    return 'LLM error: ${resp.statusCode} ${resp.body}';
  }

  final j = jsonDecode(resp.body);
  final text = j['choices']?[0]?['message']?['content'] as String?;
  return text?.trim() ?? 'No summary returned.';
}
