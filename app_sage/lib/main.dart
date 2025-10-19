import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart';
// notifications are initialized in services/notification_service.dart
import 'services/usage_service.dart';
import 'services/llm_service.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart' as scheduler;
import 'services/theme_service.dart';
import 'services/platform_service.dart';
import 'ui/usage_list_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'ui/usage_monitor_screen.dart';
import 'ui/usage_analytics_screen.dart';

// --------------------------------------------------
// CONFIG FLAG
// --------------------------------------------------
const bool useForegroundService = true; // 🔁 switch to false for WorkManager
const Duration foregroundInterval = Duration(minutes: 2);
const Duration workManagerInterval = Duration(hours: 1);
const String fetchUsageTask = 'fetchUsageTask';

// --------------------------------------------------
// SHARED BACKGROUND LOGIC
// --------------------------------------------------
Future<void> performUsageLogic() async {
  try {
    // Ensure notifications are initialized in whichever isolate calls this.
    await initializeNotifications();

    // Fetch real usage data
    final usage = await UsageService.getLast24Hours();

    // Prepare LLM summary using provided OpenAI key
    final summary = await summarizeUsageFunny(usage);

    // Show the summary in a notification
    await showSimpleDebugNotification(summary);

    // Debug log
    print("[UsageLogic] Notification sent at ${DateTime.now()}");
  } catch (e) {
    // Fallback: show simple message
    await showSimpleDebugNotification('Error generating summary: ${e.toString()}');
    print("[UsageLogic] Error: $e");
  }
}

// --------------------------------------------------
// WORKMANAGER CALLBACK
// --------------------------------------------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("[WorkManager] Task executed at ${DateTime.now()}");
    await performUsageLogic();
    return Future.value(true);
  });
}

// --------------------------------------------------
// ANDROID ALARM CALLBACK (runs even when app is closed)
// --------------------------------------------------
@pragma('vm:entry-point')
void alarmCallback() {
  print("[AlarmManager] Alarm triggered at ${DateTime.now()}");
  performUsageLogic();
}

// --------------------------------------------------
// MAIN APP
// --------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications (centralized implementation)
  // Initialize scheduler (native event handler)
  await scheduler.initScheduler();
  await initializeNotifications();

  // Initialize WorkManager (Android only)
  if (PlatformService.isAndroid) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    await Workmanager().registerPeriodicTask(
      '1',
      fetchUsageTask,
      frequency: workManagerInterval,
    );
  }

  runApp(const MyApp());
}

// --------------------------------------------------
// UI
// --------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService()..loadTheme(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: PlatformService.getAppName(),
            theme: themeService.themeData,
            home: const HomePage(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // monitoring is managed by UsageMonitorScreen
  StreamSubscription<String?>? _clickSub;
  final _storage = const FlutterSecureStorage();
  String? _userName;
  String? _profileId;
  bool _showLogo = true;

  @override
  void initState() {
    super.initState();

    // If the app launched from a notification, get the payload and navigate.
    () async {
      final payload = await getLaunchPayload();
      if (payload != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageListScreen()));
        });
      }
    }();

    _clickSub = notificationClickStream.stream.listen((payload) async {
      if (payload != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageListScreen()));
      }
    });

    // Removed debug heartbeat logging

    // Load user profile and show brief logo animation
    _loadProfileAndAnimate();
  }

  Future<void> _loadProfileAndAnimate() async {
    // small logo animation duration
    final name = await _storage.read(key: 'user_name');
    final id = await _storage.read(key: 'profile_id');
    setState(() {
      _userName = name;
      _profileId = id;
    });

    // show animated logo for 1.2 seconds
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _showLogo = false);

    // If no name set, ask for it
    if (_userName == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _askForName();
    }
  }

  Future<void> _askForName() async {
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Welcome! What should we call you?'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Your name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Skip')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      final generatedId = 'profile_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000)}';
      await _storage.write(key: 'user_name', value: res);
      await _storage.write(key: 'profile_id', value: generatedId);
      setState(() {
        _userName = res;
        _profileId = generatedId;
      });
    }
  }

  @override
  void dispose() {
    _clickSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(PlatformService.getAppName()),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeService.toggleTheme(),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey.shade900,
                  Colors.grey.shade800,
                ],
              )
            : null,
        ),
        child: SafeArea(
          child: _showLogo
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: _showLogo ? 1.0 : 0.9,
                      duration: const Duration(milliseconds: 900),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const FlutterLogo(size: 100),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _userName != null ? 'Welcome back, $_userName!' : 'Welcome to App Sage',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      PlatformService.getAppDescription(),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName != null ? 'Hello, $_userName!' : 'Hello!',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage your digital life with AI-powered insights',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark 
                                ? Colors.white.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              color: isDark ? Colors.white : Colors.blue,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Application Usage Section
                      Text(
                        'Application Usage',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildFeatureCard(
                            'Notifications',
                            Icons.notifications_active,
                            Colors.green,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UsageMonitorScreen()),
                            ),
                            isDark,
                          ),
                          _buildFeatureCard(
                            'Analytics\n(Last 24h)',
                            Icons.analytics,
                            Colors.purple,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UsageAnalyticsScreen()),
                            ),
                            isDark,
                          ),
                          _buildFeatureCard(
                            'History',
                            Icons.history,
                            Colors.orange,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UsageListScreen()),
                            ),
                            isDark,
                          ),
                          _buildFeatureCard(
                            'Mail\nSummarizer',
                            Icons.mail_outline,
                            Colors.blue,
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('Mail Summarizer')),
                                  body: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.construction, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'Coming Soon!',
                                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'AI-powered email summarization',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Feedback Card
                      _buildFeedbackCard(isDark),
                      const SizedBox(height: 24),
                      
                      // Profile Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person, 
                              color: isDark ? Colors.white70 : Colors.black54, 
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Profile ID: ${_profileId ?? "(not set)"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Builds a modern feature card with animations and theme support
  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 32, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the feedback card with theme support
  Widget _buildFeedbackCard(bool isDark) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [Colors.amber.shade800.withOpacity(0.3), Colors.orange.shade800.withOpacity(0.3)]
              : [Colors.amber.shade50, Colors.orange.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.feedback_outlined,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback & Suggestions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Start/stop handled in UsageMonitorScreen
}

// --------------------------------------------------
// FOREGROUND START CALLBACK
// --------------------------------------------------
// no-op: foreground task removed in favor of WorkManager/alarm-based scheduling
