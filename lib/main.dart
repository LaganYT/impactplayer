// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'providers/video_queue_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/download_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => VideoQueueProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ImpactPlayerApp(),
    ),
  );
}

class ImpactPlayerApp extends StatelessWidget {
  const ImpactPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VideoQueueProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'ImpactPlayer',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

