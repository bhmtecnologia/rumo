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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ModuleSelectorScreen(),
    );
  }
}
