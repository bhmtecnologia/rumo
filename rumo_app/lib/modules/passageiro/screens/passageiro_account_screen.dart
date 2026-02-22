import 'package:flutter/material.dart';

import 'package:rumo_app/core/services/auth_service.dart';
import 'package:rumo_app/screens/change_password_screen.dart';

/// Aba Conta do passageiro – perfil, alterar senha, sair.
class PassageiroAccountScreen extends StatelessWidget {
  const PassageiroAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Conta',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D95F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF00D95F), size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Usuário',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _AccountTile(
                  icon: Icons.lock_outline,
                  title: 'Alterar senha',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ChangePasswordScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _AccountTile(
                  icon: Icons.logout,
                  title: 'Sair',
                  titleColor: Colors.red[400],
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sair da conta?'),
                        content: const Text('Você precisará entrar novamente para usar o app.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await AuthService().logout();
                    }
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

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = titleColor ?? Colors.white;

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
              Icon(icon, color: titleColor ?? const Color(0xFF00D95F), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
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
