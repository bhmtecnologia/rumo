import 'package:flutter/material.dart';

import 'core/services/auth_service.dart';
import 'core/services/push_service.dart';
import 'modules/passageiro/screens/passageiro_home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService().init(forPassenger: true);
  runApp(const RumoPassageiroApp());
}

class RumoPassageiroApp extends StatelessWidget {
  const RumoPassageiroApp({super.key});

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
      home: const _AuthWrapper(),
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
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
    final user = AuthService().currentUser;
    if (user == null || !user.isUsuario) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 64, color: Colors.orange[400]),
                const SizedBox(height: 16),
                Text(
                  'Use o app Rumo Parceiro ou Rumo Central para esta conta.',
                  style: TextStyle(color: Colors.grey[300], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await AuthService().logout();
                    _onAuthChange();
                  },
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const PassageiroHomeScreen();
  }
}
