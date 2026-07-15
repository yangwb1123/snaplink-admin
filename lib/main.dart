import 'package:flutter/material.dart';
import 'app_router.dart';

void main() {
  runApp(const SSOConsoleApp());
}

class SSOConsoleApp extends StatelessWidget {
  const SSOConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF6366F1);
    return MaterialApp(
      title: 'SSO Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E293B), elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: resolveInitialScreen(),
    );
  }
}
