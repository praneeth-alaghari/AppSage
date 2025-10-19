import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/usage_service.dart';

class UsageListScreen extends StatefulWidget {
  final String? initialSummary;
  const UsageListScreen({super.key, this.initialSummary});

  @override
  State<UsageListScreen> createState() => _UsageListScreenState();
}

class _UsageListScreenState extends State<UsageListScreen> {
  static const MethodChannel _packageChannel = MethodChannel('app_sage/package_info');
  List<AppUsageModel> _usageData = [];
  bool _isLoading = false;
  String? _errorMessage;

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

  /// Fetches the last 24 hours of app usage data
  Future<void> _fetchUsageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usage = await UsageService.getLast24Hours();
      setState(() {
        _usageData = usage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Opens Android Usage Access Settings
  Future<void> _openUsageAccessSettings() async {
    try {
      await _packageChannel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchUsageData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Last 24h Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsageData,
            tooltip: 'Refresh usage data',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.initialSummary != null) ...[
              const Text(
                'Notification Summary:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  widget.initialSummary!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'App Usage Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _openUsageAccessSettings,
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoading) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading usage data...'),
                  ],
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error loading usage data:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _openUsageAccessSettings,
                      child: const Text('Open Usage Access Settings'),
                    ),
                  ],
                ),
              ),
            ] else if (_usageData.isEmpty) ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No usage data available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Make sure Usage Access is enabled',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Found ${_usageData.length} apps with usage data',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _usageData.length,
                  itemBuilder: (context, index) {
                    final app = _usageData[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            app.packageName.split('.').last.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        title: Text(
                          app.packageName.split('.').last,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          app.packageName,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDuration(app.totalTimeInForeground),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${app.totalTimeInForeground.round()}s',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}