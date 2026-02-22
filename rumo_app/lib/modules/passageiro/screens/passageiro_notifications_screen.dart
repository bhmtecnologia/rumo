import 'package:flutter/material.dart';

import 'package:rumo_app/core/services/passenger_preferences_service.dart';

/// Configurações de notificações do passageiro.
class PassageiroNotificationsScreen extends StatefulWidget {
  const PassageiroNotificationsScreen({super.key});

  @override
  State<PassageiroNotificationsScreen> createState() => _PassageiroNotificationsScreenState();
}

class _PassageiroNotificationsScreenState extends State<PassageiroNotificationsScreen> {
  final _prefs = PassengerPreferencesService();
  bool _pushDriverAccepted = true;
  bool _pushDriverArrived = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accepted = await _prefs.getPushDriverAccepted();
    final arrived = await _prefs.getPushDriverArrived();
    if (mounted) {
      setState(() {
        _pushDriverAccepted = accepted;
        _pushDriverArrived = arrived;
        _loading = false;
      });
    }
  }

  Future<void> _setPushDriverAccepted(bool v) async {
    await _prefs.setPushDriverAccepted(v);
    if (mounted) setState(() => _pushDriverAccepted = v);
  }

  Future<void> _setPushDriverArrived(bool v) async {
    await _prefs.setPushDriverArrived(v);
    if (mounted) setState(() => _pushDriverArrived = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Notificações'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Push notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Receba alertas sobre sua corrida.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 16),
                _SwitchTile(
                  title: 'Motorista aceitou',
                  subtitle: 'Aviso quando um motorista aceitar sua corrida',
                  value: _pushDriverAccepted,
                  onChanged: _setPushDriverAccepted,
                ),
                const SizedBox(height: 12),
                _SwitchTile(
                  title: 'Motorista chegou',
                  subtitle: 'Aviso quando o motorista chegar na origem',
                  value: _pushDriverArrived,
                  onChanged: _setPushDriverArrived,
                ),
              ],
            ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00D95F),
            ),
          ],
        ),
      ),
    );
  }
}
