import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';
import 'package:rumo_app/core/services/push_service.dart';

import 'motorista_active_ride_screen.dart';

/// Home do motorista: corridas disponíveis e minha corrida ativa.
class MotoristaHomeScreen extends StatefulWidget {
  const MotoristaHomeScreen({super.key});

  @override
  State<MotoristaHomeScreen> createState() => _MotoristaHomeScreenState();
}

class _MotoristaHomeScreenState extends State<MotoristaHomeScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  List<RideListItem> _available = [];
  List<RideListItem> _myRides = [];
  Ride? _activeRide;
  bool _loading = true;
  String? _error;
  bool _isOnline = false;
  bool _loadingStatus = false;
  Timer? _locationTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _isOnline) {
      _load(silent: true);
    }
  }

  static const _loadTimeout = Duration(seconds: 25);
  static const _driverStatusTimeout = Duration(seconds: 10);

  Future<void> _load({bool silent = false}) async {
    final user = AuthService().currentUser;
    if (user?.isMotorista != true) {
      if (mounted) setState(() {
        _loading = false;
        _error = user == null
            ? 'Sessão não carregada. Volte e tente novamente.'
            : 'Acesso restrito a motoristas. Faça login com um usuário motorista.';
      });
      return;
    }
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      // Carrega corridas com timeout para não travar se o backend demorar/falhar
      final List<RideListItem> available;
      final List<RideListItem> myRides;
      try {
        final results = await Future.wait([
          _api.listRides(available: true),
          _api.listRides(available: false),
        ]).timeout(_loadTimeout);
        available = results[0];
        myRides = results[1];
      } on TimeoutException {
        if (mounted && !silent) setState(() {
          _loading = false;
          _error = 'Demorou demais. Verifique a conexão e tente novamente.';
        });
        return;
      }

      Ride? active;
      for (final r in myRides) {
        if (r.status != 'completed' && r.status != 'cancelled') {
          try {
            final detail = await _api.getRide(r.id).timeout(_loadTimeout);
            active = detail;
          } catch (_) {}
          break;
        }
      }

      // Status online do motorista: não bloqueia a tela; se falhar ou demorar, assume offline
      bool isOnline = false;
      try {
        final status = await _api.getDriverStatus().timeout(_driverStatusTimeout);
        isOnline = status['isOnline'] == true;
      } catch (_) {
        isOnline = false;
      }

      if (mounted) {
        setState(() {
          _available = available;
          _myRides = myRides;
          _activeRide = active;
          _isOnline = isOnline;
          _loading = false;
        });
        if (_isOnline) {
          _startLocationUpdates();
          _startRefreshPolling();
        } else {
          _refreshTimer?.cancel();
          _refreshTimer = null;
        }
        PushService().ensureTokenRegistered();
      }
    } catch (e) {
      if (mounted && !silent) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<Position?> _getPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (_) {
      return null;
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    void sendPosition() async {
      final pos = await _getPosition();
      if (!mounted || !_isOnline) return;
      try {
        await _api.updateDriverStatus(
          isOnline: true,
          lat: pos?.latitude,
          lng: pos?.longitude,
        );
      } catch (_) {}
    }
    sendPosition();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => sendPosition());
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// Polling para novas corridas quando online (atualiza a cada 8s).
  void _startRefreshPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_isOnline) return;
      _load(silent: true);
    });
  }

  Future<void> _toggleOnline(bool value) async {
    if (_loadingStatus) return;
    setState(() => _loadingStatus = true);
    try {
      if (value) {
        final pos = await _getPosition();
        await _api.updateDriverStatus(
          isOnline: true,
          lat: pos?.latitude,
          lng: pos?.longitude,
        );
      if (mounted) {
        setState(() { _isOnline = true; _loadingStatus = false; });
        _startLocationUpdates();
        _startRefreshPolling();
        PushService().ensureTokenRegistered();
      }
      } else {
        _stopLocationUpdates();
        _refreshTimer?.cancel();
        _refreshTimer = null;
        await _api.updateDriverStatus(isOnline: false);
        if (mounted) setState(() { _isOnline = false; _loadingStatus = false; });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Você está online no mapa da central.' : 'Você está offline.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
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
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
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
                        Card(
                          color: _isOnline ? const Color(0xFF1B3D1B) : const Color(0xFF2C2C2C),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  _isOnline ? Icons.location_on : Icons.location_off,
                                  color: _isOnline ? Colors.greenAccent : Colors.grey,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isOnline ? 'Online no mapa da central' : 'Offline',
                                        style: TextStyle(
                                          color: _isOnline ? Colors.greenAccent : Colors.grey[400],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _isOnline ? 'Você aparece no mapa e pode receber corridas' : 'Fique online para receber corridas',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_loadingStatus)
                                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                else
                                  Switch(
                                    value: _isOnline,
                                    onChanged: _toggleOnline,
                                    activeColor: Colors.greenAccent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
