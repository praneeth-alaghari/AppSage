import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/usage_service.dart';

class UsageListScreen extends StatefulWidget {
  const UsageListScreen({super.key});

  @override
  _UsageListScreenState createState() => _UsageListScreenState();
}

// Top-level helper to query Android for the human-friendly app label for a
// package name. Returns null if not found or on non-Android platforms.
const MethodChannel _packageChannel = MethodChannel('app_sage/package_info');

Future<String?> getAppLabel(String packageName) async {
  try {
    final label = await _packageChannel.invokeMethod<String>('getAppLabel', {'package': packageName});
    return label;
  } catch (_) {
    return null;
  }
}

class _UsageListScreenState extends State<UsageListScreen> {
  bool _loading = true;
  String? _error;
  List<AppUsageModel> _apps = [];
  List<AppUsageModel> _filtered = [];
  String _query = '';
  bool _sortDesc = true;

  static const MethodChannel _packageChannel = MethodChannel('app_sage/package_info');

  Future<String?> _getAppIconBase64(String packageName) async {
    try {
      final base64 = await _packageChannel.invokeMethod<String>('getAppIcon', {'package': packageName});
      return base64;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await _packageChannel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<String?> _getAppLabel(String packageName) async {
    return getAppLabel(packageName);
  }

  Future<void> _loadUsage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final usage = await UsageService.getLast24Hours(); 

      // Logging the fetched usage statistics
      print('Fetched app usage data: ${usage.map((app) => app.toString()).toList()}');

      final List<AppUsageModel> results = [];

      for (final item in usage) {
        try {
          final label = await _getAppLabel(item.packageName);
          results.add(AppUsageModel(
          packageName: item.packageName,
          totalTimeInForeground: item.totalTimeInForeground,
          ));

          if (label == null) {
            print('⚠️ No label found for ${item.packageName}');
          }
        } catch (_) {}
      }

      setState(() {
        _apps = results;
        _applyFilters();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDuration(double seconds) {
    final int milliseconds = (seconds * 1000).round(); // Convert seconds to milliseconds
    final int totalSeconds = milliseconds ~/ 1000; // Getting the total seconds from milliseconds

    if (totalSeconds < 60) return '$totalSeconds sec';
    final int minutes = (totalSeconds / 60).floor();
    if (minutes < 60) return '$minutes min';

    final int hours = (minutes / 60).floor();
    final int remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  void _applyFilters() {
    var list = List<AppUsageModel>.from(_apps);
    // Note: getAppLabel returns Future, so for filtering by label we use packageName fallback in this pass.
    list = list.where((a) {
      final q = _query.toLowerCase();
      return a.packageName.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) => _sortDesc ? b.totalTimeInForeground.compareTo(a.totalTimeInForeground) : a.totalTimeInForeground.compareTo(b.totalTimeInForeground));
    setState(() { _filtered = list; });
  }

  String _niceNameFallback(String packageName) {
    final parts = packageName.split('.');
    if (parts.isEmpty) return packageName;
    final last = parts.last;
    final out = last.replaceAll(RegExp(r'[_\-]'), ' ');
    return out.split(' ').map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Last 24h Usage')),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.settings),
        onPressed: _openUsageAccessSettings,
        tooltip: 'Open Usage Access settings',
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _apps.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No user app usage found'),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _openUsageAccessSettings,
                          child: Text('Open Usage Access settings'),
                        )
                      ],
                    ))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search apps'),
                                  onChanged: (v) {
                                    setState(() { _query = v; _applyFilters(); });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(_sortDesc ? Icons.arrow_downward : Icons.arrow_upward),
                                onPressed: () {
                                  setState(() { _sortDesc = !_sortDesc; _applyFilters(); });
                                },
                              )
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final a = _filtered[index];
                              return ListTile(
                                leading: FutureBuilder<String?>( // Fetching app icons
                                  future: _getAppIconBase64(a.packageName),
                                  builder: (context, snap) {
                                    final base64 = snap.data;
                                    if (base64 != null) {
                                      try {
                                        final bytes = base64Decode(base64);
                                        return Image.memory(bytes, width: 40, height: 40);
                                      } catch (_) {}
                                    }
                                    return CircleAvatar(child: Text(_niceNameFallback(a.packageName)[0].toUpperCase()));
                                  },
                                ),
                                title: FutureBuilder<String?>( // Fetching app labels
                                  future: _getAppLabel(a.packageName),
                                  builder: (context, snap) {
                                    final name = snap.data ?? _niceNameFallback(a.packageName);
                                    return Text(name);
                                  },
                                ),
                                subtitle: Text(a.packageName),
                                trailing: Text(_formatDuration(a.totalTimeInForeground)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}