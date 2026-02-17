import 'package:flutter/material.dart';

import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/modules/passageiro/screens/passageiro_home_screen.dart';

/// Tela de avaliação (1-5 estrelas) após corrida concluída.
class RideRatingScreen extends StatefulWidget {
  final String rideId;
  final String? formattedPrice;

  const RideRatingScreen({super.key, required this.rideId, this.formattedPrice});

  @override
  State<RideRatingScreen> createState() => _RideRatingScreenState();
}

class _RideRatingScreenState extends State<RideRatingScreen> {
  final ApiService _api = ApiService();
  int _rating = 0;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await _api.rateRide(widget.rideId, _rating);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obrigado pela avaliação!')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PassageiroHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Avaliar corrida'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                'Como foi sua viagem?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (widget.formattedPrice != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Valor: ${widget.formattedPrice}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    icon: Icon(
                      _rating >= star ? Icons.star : Icons.star_border,
                      size: 48,
                      color: _rating >= star ? const Color(0xFF00D95F) : Colors.grey[600],
                    ),
                    onPressed: () => setState(() => _rating = star),
                  );
                }),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: (_rating >= 1 && !_submitting) ? _submit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFF00D95F),
                  foregroundColor: Colors.black,
                ),
                child: _submitting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enviar avaliação'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
