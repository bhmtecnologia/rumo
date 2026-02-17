import 'package:flutter/material.dart';

import 'package:rumo_app/core/services/auth_service.dart';
import 'package:rumo_app/modules/backoffice/screens/backoffice_home_screen.dart';
import 'package:rumo_app/modules/motorista/screens/motorista_home_screen.dart';
import 'package:rumo_app/modules/passageiro/screens/passageiro_home_screen.dart';
import 'change_password_screen.dart';

/// Tela inicial do app: escolha do módulo (Passageiro, Motorista ou Backoffice).
class ModuleSelectorScreen extends StatelessWidget {
  final VoidCallback? onLogout;

  const ModuleSelectorScreen({super.key, this.onLogout});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Rumo', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChangePasswordScreen()),
              );
            },
            tooltip: 'Alterar senha',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              onLogout?.call();
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user != null) ...[
                Text(
                  'Olá, ${user.name}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Escolha como deseja usar o app',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _ModuleCard(
                icon: Icons.person,
                title: 'Passageiro',
                subtitle: 'Pedir corrida, ver preço e solicitar viagem',
                onTap: () => _openModule(context, const PassageiroHomeScreen()),
              ),
              const SizedBox(height: 16),
              _ModuleCard(
                icon: Icons.directions_car,
                title: 'Motorista',
                subtitle: 'Aceitar corridas e gerenciar viagens',
                onTap: () => _openModule(context, const MotoristaHomeScreen()),
              ),
              const SizedBox(height: 16),
              _ModuleCard(
                icon: Icons.admin_panel_settings,
                title: 'Backoffice',
                subtitle: 'Gestão de corridas, tarifas e relatórios',
                onTap: () => _openModule(context, const BackofficeHomeScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openModule(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C2C),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF00D95F).withValues(alpha: 0.2),
                child: Icon(icon, size: 32, color: const Color(0xFF00D95F)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}
