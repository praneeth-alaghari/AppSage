import 'package:flutter/material.dart';
import 'services/usage_service.dart';
import 'ui/usage_list_screen.dart'; // 👈 fixed import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Usage Stats',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usage Stats Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // Preload usage data (optional)
              await UsageService.getLast24Hours();

              // Navigate to UsageListScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UsageListScreen()),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: const Text('Show Last 24 Hours Usage'),
        ),
      ),
    );
  }
}
