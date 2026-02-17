import 'package:flutter/material.dart';

/// Home do módulo Backoffice: gestão de corridas, tarifas, relatórios.
/// Funcionalidades a implementar: listar corridas, configurar tarifas, dashboard.
class BackofficeHomeScreen extends StatelessWidget {
  const BackofficeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rumo – Backoffice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Módulo Backoffice',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Em breve: corridas, tarifas, relatórios e configurações.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
