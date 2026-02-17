import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/modules/passageiro/screens/passageiro_home_screen.dart';
import 'package:rumo_app/modules/passageiro/screens/ride_rating_screen.dart';

/// Tela de acompanhamento após solicitar a corrida: polling e ações (cancelar, avaliar).
class WaitingForDriverScreen extends StatefulWidget {
  final Ride ride;
  final String? formattedPrice;

  const WaitingForDriverScreen({
    super.key,
    required this.ride,
    this.formattedPrice,
  });

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> {
  final ApiService _api = ApiService();
  late Ride _ride;
  Timer? _pollTimer;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || _ride.isFinished) return;
    try {
      final updated = await _api.getRide(_ride.id);
      if (!mounted) return;
      setState(() => _ride = updated);
      if (updated.status == 'completed') {
        _pollTimer?.cancel();
        final priceStr = updated.actualPriceCents != null
            ? 'R\$ ${(updated.actualPriceCents! / 100).toStringAsFixed(2).replaceFirst('.', ',')}'
            : (widget.formattedPrice ?? updated.formattedPrice ?? '—');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RideRatingScreen(rideId: updated.id, formattedPrice: priceStr),
          ),
        );
        return;
      }
      if (updated.status == 'cancelled') {
        _pollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updated.cancelReason?.isNotEmpty == true ? updated.cancelReason! : 'Corrida cancelada.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PassageiroHomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelRide() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação?'),
        content: const Text('Deseja cancelar esta corrida?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() { _cancelling = true; _error = null; });
    try {
      await _api.cancelRide(_ride.id);
      if (!mounted) return;
      _pollTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida cancelada.')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PassageiroHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() {
        _cancelling = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _statusMessage {
    switch (_ride.status) {
      case 'requested':
        return 'Procurando motorista parceiro';
      case 'accepted':
        return 'Motorista a caminho${_ride.driverName != null ? ': ${_ride.driverName}' : ''}${_ride.vehiclePlate != null ? ' • ${_ride.vehiclePlate}' : ''}';
      case 'driver_arrived':
        return 'Motorista chegou na origem';
      case 'in_progress':
        return 'Viagem em andamento';
      case 'completed':
        return 'Corrida finalizada';
      case 'cancelled':
        return 'Corrida cancelada';
      default:
        return _ride.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.formattedPrice ?? _ride.formattedPrice ?? (_ride.actualPriceCents != null ? 'R\$ ${(_ride.actualPriceCents! / 100).toStringAsFixed(2)}' : '—');

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
              SizedBox(
                height: 120,
                child: Center(
                  child: _ride.isRequested || _ride.isAccepted
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF00D95F).withValues(alpha: 0.6)),
                              ),
                            ),
                            Icon(Icons.directions_car, size: 40, color: Colors.grey[400]),
                          ],
                        )
                      : Icon(
                          _ride.isDriverArrived ? Icons.location_on : Icons.directions_car,
                          size: 64,
                          color: const Color(0xFF00D95F),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _ride.isRequested ? 'Assim que um motorista aceitar, você será avisado.' : 'Acompanhe o status da sua viagem.',
                style: TextStyle(fontSize: 15, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
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
                    if (_ride.pickupAddress != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.radio_button_checked, size: 18, color: Colors.green[400]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_ride.pickupAddress!, style: TextStyle(fontSize: 14, color: Colors.grey[300]), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    if (_ride.pickupAddress != null) const SizedBox(height: 8),
                    if (_ride.destinationAddress != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.place, size: 18, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_ride.destinationAddress!, style: TextStyle(fontSize: 14, color: Colors.grey[300]), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    if (_ride.destinationAddress != null) const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Valor ${_ride.actualPriceCents != null ? 'final' : 'estimado'}', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00D95F))),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
              ],
              const Spacer(),
              if (!_ride.isFinished) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancelar corrida'),
                  onPressed: _cancelling ? null : _cancelRide,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size(double.infinity, 48)),
                ),
                const SizedBox(height: 12),
              ],
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PassageiroHomeScreen()),
                  (route) => false,
                ),
                child: Text('Voltar ao início', style: TextStyle(color: Colors.grey[400])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
