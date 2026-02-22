import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/widgets/rumo_map.dart';
import 'package:rumo_app/modules/passageiro/screens/passageiro_home_screen.dart';
import 'package:rumo_app/modules/passageiro/screens/ride_chat_screen.dart';
import 'package:rumo_app/modules/passageiro/screens/ride_rating_screen.dart';

/// Tela de acompanhamento estilo Uber: mapa, posição do motorista, card, ETA.
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

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  late Ride _ride;
  Timer? _pollTimer;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ride = widget.ride;
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_ride.isFinished) {
      _poll(); // Atualiza imediatamente ao voltar ao app
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Intervalo mais curto quando aguardando aceite
    final interval = _ride.isRequested ? const Duration(seconds: 2) : const Duration(seconds: 3);
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || _ride.isFinished) return;
    try {
      final updated = await _api.getRide(_ride.id);
      if (!mounted) return;
      final wasRequested = _ride.isRequested;
      setState(() => _ride = updated);
      if (wasRequested && !updated.isRequested) {
        _startPolling(); // Ajusta intervalo quando motorista aceita
      }
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

  void _onMessageTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideChatScreen(rideId: _ride.id),
      ),
    );
  }

  String get _statusMessage {
    switch (_ride.status) {
      case 'requested':
        return 'Procurando motorista parceiro';
      case 'accepted':
        return 'Motorista a caminho';
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

  LatLng? get _pickupLatLng {
    if (_ride.pickupLat != null && _ride.pickupLng != null) {
      return LatLng(_ride.pickupLat!, _ride.pickupLng!);
    }
    return null;
  }

  LatLng? get _destinationLatLng {
    if (_ride.destinationLat != null && _ride.destinationLng != null) {
      return LatLng(_ride.destinationLat!, _ride.destinationLng!);
    }
    return null;
  }

  LatLng? get _driverLatLng {
    if (_ride.driverLat != null && _ride.driverLng != null) {
      return LatLng(_ride.driverLat!, _ride.driverLng!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.formattedPrice ?? _ride.formattedPrice ?? (_ride.actualPriceCents != null ? 'R\$ ${(_ride.actualPriceCents! / 100).toStringAsFixed(2)}' : '—');
    final showMap = _pickupLatLng != null && _destinationLatLng != null;
    final showDriverCard = _ride.driverUserId != null && (_ride.isAccepted || _ride.isDriverArrived || _ride.isInProgress);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Sua corrida'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (showMap)
              RumoMap(
                pickup: _pickupLatLng,
                destination: _destinationLatLng,
                driverPosition: _driverLatLng,
                height: 200,
                fitBounds: true,
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                child: _ride.isRequested
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _poll(),
                color: const Color(0xFF00D95F),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ride.isRequested
                          ? 'Assim que um motorista aceitar, você será avisado.'
                          : _ride.isDriverArrived
                              ? 'O motorista está te esperando. Pode embarcar!'
                              : 'Acompanhe o status da sua viagem.',
                      style: TextStyle(fontSize: 15, color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    if (showDriverCard) ...[
                      const SizedBox(height: 20),
                      _DriverCard(
                        driverName: _ride.driverName ?? 'Motorista',
                        vehiclePlate: _ride.vehiclePlate,
                        etaMin: _ride.etaMin,
                        driverArrived: _ride.isDriverArrived,
                        onMessageTap: _onMessageTap,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
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
                                Expanded(
                                  child: Text(
                                    _ride.pickupAddress!,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (_ride.pickupAddress != null) const SizedBox(height: 8),
                          if (_ride.destinationAddress != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.place, size: 18, color: Colors.red[400]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _ride.destinationAddress!,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (_ride.destinationAddress != null) const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Valor ${_ride.actualPriceCents != null ? 'final' : 'estimado'}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                              ),
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
                    const SizedBox(height: 24),
                    if (!_ride.isFinished)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancelar corrida'),
                        onPressed: _cancelling ? null : _cancelRide,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    const SizedBox(height: 12),
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
          ),  // Expanded
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String driverName;
  final String? vehiclePlate;
  final int? etaMin;
  final bool driverArrived;
  final VoidCallback onMessageTap;

  const _DriverCard({
    required this.driverName,
    this.vehiclePlate,
    this.etaMin,
    this.driverArrived = false,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D95F).withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00D95F).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person, color: Color(0xFF00D95F), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                if (vehiclePlate != null && vehiclePlate!.isNotEmpty)
                  Text(vehiclePlate!, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                if (driverArrived)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Motorista na origem',
                          style: TextStyle(fontSize: 13, color: Colors.green[400], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                else if (etaMin != null && etaMin! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.green[400]),
                        const SizedBox(width: 4),
                        Text(
                          etaMin == 1 ? 'Chega em 1 min' : 'Chega em $etaMin min',
                          style: TextStyle(fontSize: 13, color: Colors.green[400], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMessageTap,
            icon: const Icon(Icons.chat_bubble_outline),
            color: const Color(0xFF00D95F),
            tooltip: 'Mensagem',
          ),
        ],
      ),
    );
  }
}
