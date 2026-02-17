import 'package:flutter/material.dart';

import 'core/services/auth_service.dart';
import 'screens/login_screen.dart';
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
      home: const AuthWrapper(),
    );
  }
}

/// Exibe login ou seletor de módulo conforme autenticação (base local; depois Firebase/Google/Microsoft).
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    AuthService.onUnauthorized = _onAuthChange;
    _init();
  }

  @override
  void dispose() {
    AuthService.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _init() async {
    await AuthService().loadFromStorage();
    if (AuthService().isLoggedIn) {
      final valid = await AuthService().validateToken();
      if (!valid) await AuthService().logout();
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _loggedIn = AuthService().isLoggedIn;
      });
    }
  }

  void _onAuthChange() {
    setState(() => _loggedIn = AuthService().isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_loggedIn) {
      return LoginScreen(onSuccess: _onAuthChange);
    }
    return ModuleSelectorScreen(onLogout: _onAuthChange);
  }
}
