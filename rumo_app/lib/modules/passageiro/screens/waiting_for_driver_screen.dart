import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/modules/backoffice/screens/backoffice_home_screen.dart';

/// Tela exibida após solicitar a corrida: "Procurando motorista parceiro".
class WaitingForDriverScreen extends StatelessWidget {
  final Ride ride;
  final String? formattedPrice;

  const WaitingForDriverScreen({
    super.key,
    required this.ride,
    this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    final price = formattedPrice ?? ride.formattedPrice ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Solicitação enviada'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Ícone animado / ilustração de espera
              SizedBox(
                height: 120,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF00D95F).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.directions_car,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Procurando motorista parceiro',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Assim que um motorista aceitar, você será avisado.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Resumo da corrida
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ride.pickupAddress != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.radio_button_checked, size: 18, color: Colors.green[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.pickupAddress!,
                              style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (ride.destinationAddress != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.place, size: 18, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.destinationAddress!,
                              style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Valor estimado',
                          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                        ),
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D95F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Ações
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const BackofficeHomeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('Ver no backoffice'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D95F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Voltar ao início',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
