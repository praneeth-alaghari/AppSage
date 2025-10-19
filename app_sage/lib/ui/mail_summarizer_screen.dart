import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/notification_service.dart';

/// MailSummarizerScreen
///
/// Provides a simple UI to enable/disable periodic mail summarizer notifications
/// and select the frequency. When enabled this screen starts a foreground Timer
/// that simulates fetching a summary (returns the string 'Dummy output') and
/// posts a local notification using the app's central notification service.
class MailSummarizerScreen extends StatefulWidget {
  const MailSummarizerScreen({super.key});

  @override
  State<MailSummarizerScreen> createState() => _MailSummarizerScreenState();
}

class _MailSummarizerScreenState extends State<MailSummarizerScreen> {
  bool _enabled = false;
  int _minutes = 5; // default 5 min
  Timer? _timer;

  final List<int> _options = const [1, 5, 15, 60, 360, 720, 1440];

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  String _labelFor(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = (minutes / 60).round();
    return '$h hr${h > 1 ? 's' : ''}';
  }

  void _startTimer() {
    _stopTimer();
    // Start periodic timer in foreground. First trigger after selected interval.
    _timer = Timer.periodic(Duration(minutes: _minutes), (_) async {
      final summary = await _fetchDummySummary();
      // Post a notification with the dummy output
      await showSimpleDebugNotification(summary, payload: 'mail_summarizer');
    });
    // Inform user that scheduling started
    if (mounted) {
      showSimpleDebugNotification('Mail Summarizer scheduled every ${_labelFor(_minutes)}');
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    // Inform user that scheduling stopped
    if (mounted) showSimpleDebugNotification('Mail Summarizer stopped');
  }

  /// Simulates a network request to a remote LLM service for summarizing mail.
  /// For now this function simply returns the fixed string 'Dummy output' after
  /// a short artificial delay to mimic network latency.
  Future<String> _fetchDummySummary() async {
    // Simulate a request to a dummy external URL. We don't rely on the
    // response for now — the service will return a fixed "Dummy output".
    try {
      final uri = Uri.parse('http://52.66.142.248:5000/run-mail-summarizer');
      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Assuming the response body has the summary directly, or parse as needed
        return response.body; // or decode it if it's JSON
      } else {
        // Handle different status codes as needed
        return 'Error: ${response.statusCode}';
      }

    } catch (_) {
      // ignore network errors — we always fallback to dummy output
    }
    // Artificial small delay to mimic processing
    await Future.delayed(const Duration(milliseconds: 2000));
    return 'Dummy output';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mail Summarizer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Mail Summarizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Enable notifications'),
              value: _enabled,
              onChanged: (v) {
                setState(() => _enabled = v);
                if (v) {
                  _startTimer();
                } else {
                  _stopTimer();
                }
              },
            ),
            const SizedBox(height: 8),
            if (_enabled)
              Row(
                children: [
                  const Text('Frequency:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _minutes,
                    items: _options.map((m) => DropdownMenuItem(value: m, child: Text(_labelFor(m)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _minutes = v);
                      // Restart timer with new frequency
                      if (_enabled) {
                        _startTimer();
                      }
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Manual trigger for testing
                final summary = await _fetchDummySummary();
                await showSimpleDebugNotification(summary, payload: 'mail_summarizer_manual');
              },
              child: const Text('Send Test Summary Now'),
            ),
            const SizedBox(height: 12),
            const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('• This is a foreground-only simulator. When enabled the app will periodically request a summary (simulated) and show a notification.'),
          ],
        ),
      ),
    );
  }
}
