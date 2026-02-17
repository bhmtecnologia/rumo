import 'package:flutter/material.dart';

/// Home do módulo Motorista: corridas disponíveis, status, etc.
/// Funcionalidades a implementar: aceitar corridas, ver rota, iniciar/finalizar.
class MotoristaHomeScreen extends StatelessWidget {
  const MotoristaHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rumo – Motorista'),
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
                Icon(Icons.directions_car, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Módulo Motorista',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Em breve: corridas disponíveis, aceitar viagem, navegação.',
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
