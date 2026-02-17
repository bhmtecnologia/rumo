import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';

import 'motorista_active_ride_screen.dart';

/// Home do motorista: corridas disponíveis e minha corrida ativa.
class MotoristaHomeScreen extends StatefulWidget {
  const MotoristaHomeScreen({super.key});

  @override
  State<MotoristaHomeScreen> createState() => _MotoristaHomeScreenState();
}

class _MotoristaHomeScreenState extends State<MotoristaHomeScreen> {
  final ApiService _api = ApiService();
  List<RideListItem> _available = [];
  List<RideListItem> _myRides = [];
  Ride? _activeRide;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (AuthService().currentUser?.isMotorista != true) return;
    setState(() { _loading = true; _error = null; });
    try {
      final available = await _api.listRides(available: true);
      final myRides = await _api.listRides(available: false);
      Ride? active;
      for (final r in myRides) {
        if (r.status != 'completed' && r.status != 'cancelled') {
          final detail = await _api.getRide(r.id);
          active = detail;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _available = available;
          _myRides = myRides;
          _activeRide = active;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openActiveRide(Ride ride) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MotoristaActiveRideScreen(ride: ride, onUpdated: _load),
      ),
    );
  }

  Future<void> _showAcceptDialog(RideListItem item) async {
    final plateController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aceitar corrida?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.pickupAddress, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              Text(item.destinationAddress, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              const SizedBox(height: 12),
              Text(item.formattedPrice, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: plateController,
                decoration: const InputDecoration(
                  labelText: 'Placa do veículo (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Recusar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Aceitar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.acceptRide(item.id, vehiclePlate: plateController.text.trim().isEmpty ? null : plateController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida aceita!')));
        final updated = await _api.getRide(item.id);
        if (mounted) _openActiveRide(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Rumo – Motorista'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_activeRide != null) ...[
                          Card(
                            color: const Color(0xFF2C2C2C),
                            child: InkWell(
                              onTap: () => _openActiveRide(_activeRide!),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.directions_car, color: Colors.green[400]),
                                        const SizedBox(width: 8),
                                        Text(
                                          _statusLabel(_activeRide!.status),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[400]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(_activeRide!.pickupAddress ?? '—', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(_activeRide!.destinationAddress ?? '—', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.open_in_new, size: 18),
                                      label: const Text('Abrir corrida'),
                                      onPressed: () => _openActiveRide(_activeRide!),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          _activeRide != null ? 'Outras corridas disponíveis' : 'Corridas disponíveis',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        if (_available.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Nenhuma corrida disponível no momento.',
                              style: TextStyle(color: Colors.grey[400]),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._available.map((r) => Card(
                                color: const Color(0xFF2C2C2C),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(r.pickupAddress, style: const TextStyle(color: Colors.white)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.destinationAddress, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(r.formattedPrice, style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  trailing: FilledButton(
                                    onPressed: () => _showAcceptDialog(r),
                                    child: const Text('Aceitar'),
                                  ),
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Aceita – a caminho da origem';
      case 'driver_arrived':
        return 'Chegou na origem';
      case 'in_progress':
        return 'Viagem em andamento';
      default:
        return status;
    }
  }
}
