import 'package:flutter/material.dart';

import 'help_screen.dart';
import 'passageiro_cost_center_default_screen.dart';
import 'passageiro_notifications_screen.dart';

/// Aba Opções do passageiro.
class PassageiroOptionsScreen extends StatelessWidget {
  const PassageiroOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Opções',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                _OptionTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notificações',
                  subtitle: 'Push e alertas',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PassageiroNotificationsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _OptionTile(
                  icon: Icons.payment_outlined,
                  title: 'Forma de pagamento',
                  subtitle: 'Centro de custo padrão',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PassageiroCostCenterDefaultScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _OptionTile(
                  icon: Icons.help_outline,
                  title: 'Ajuda',
                  subtitle: 'Perguntas frequentes',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00D95F), size: 24),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[500], size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
