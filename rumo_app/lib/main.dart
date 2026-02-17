import 'package:flutter/material.dart';

import 'screens/module_selector_screen.dart';

void main() {
  runApp(const RumoApp());
}

class RumoApp extends StatelessWidget {
  const RumoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rumo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00D95F),
          surface: const Color(0xFF1A1A1A),
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white70,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const ModuleSelectorScreen(),
    );
  }
}
