import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';

/// Central do backoffice: mapa com corridas solicitadas, usuários por localidade, tempo (SLA), motoristas parceiros.
class BackofficeHomeScreen extends StatefulWidget {
  const BackofficeHomeScreen({super.key});

  @override
  State<BackofficeHomeScreen> createState() => _BackofficeHomeScreenState();
}

class _BackofficeHomeScreenState extends State<BackofficeHomeScreen> {
  final ApiService _api = ApiService();
  List<RideListItem> _rides = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _loadRides();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadRides());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRides() async {
    if (!mounted) return;
    try {
      final list = await _api.listRides();
      if (mounted) {
        setState(() {
          _rides = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Central Rumo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRides,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                _buildMotoristasOverlay(),
              ],
            ),
          ),
          _buildRidesPanel(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final points = <LatLng>[];
    for (final r in _rides) {
      if (r.pickupLat != null && r.pickupLng != null) {
        points.add(LatLng(r.pickupLat!, r.pickupLng!));
      }
      if (r.destinationLat != null && r.destinationLng != null) {
        points.add(LatLng(r.destinationLat!, r.destinationLng!));
      }
    }
    final center = points.isNotEmpty
        ? points.first
        : const LatLng(-15.7942, -47.8822); // Brasília

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rumo.rumo_app',
        ),
        MarkerLayer(
          markers: _rides
              .where((r) => r.pickupLat != null && r.pickupLng != null)
              .map((r) => Marker(
                    point: LatLng(r.pickupLat!, r.pickupLng!),
                    width: 24,
                    height: 24,
                    child: Icon(Icons.trip_origin, color: Colors.green[400], size: 24),
                  ))
              .toList(),
        ),
        MarkerLayer(
          markers: _rides
              .where((r) => r.destinationLat != null && r.destinationLng != null)
              .map((r) => Marker(
                    point: LatLng(r.destinationLat!, r.destinationLng!),
                    width: 24,
                    height: 24,
                    child: const Icon(Icons.place, color: Colors.red, size: 24),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMotoristasOverlay() {
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                'Motoristas: em breve',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRidesPanel() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Corridas solicitadas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${_rides.length} total',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Colors.red[300], fontSize: 12)),
            ),
          Expanded(
            child: _rides.isEmpty && !_loading
                ? Center(
                    child: Text(
                      'Nenhuma corrida ainda.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _rides.length,
                    itemBuilder: (context, i) {
                      final r = _rides[i];
                      return _RideListTile(ride: r);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RideListTile extends StatelessWidget {
  final RideListItem ride;

  const _RideListTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: ride.status == 'requested'
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
          child: Icon(
            ride.status == 'requested' ? Icons.schedule : Icons.check,
            color: ride.status == 'requested' ? Colors.orange : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          ride.pickupAddress,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          ride.destinationAddress,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              ride.formattedPrice,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
            if (ride.estimatedDurationMin != null)
              Text(
                '${ride.estimatedDurationMin} min',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            Text(
              ride.timeAgo,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
