import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/models/estimate.dart';
import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/widgets/rumo_map.dart';

class TripChoiceScreen extends StatelessWidget {
  final Estimate estimate;
  final String pickupAddress;
  final String destinationAddress;
  final LatLng? pickupCoords;
  final LatLng? destinationCoords;

  const TripChoiceScreen({
    super.key,
    required this.estimate,
    required this.pickupAddress,
    required this.destinationAddress,
    this.pickupCoords,
    this.destinationCoords,
  });

  Future<void> _requestRide(BuildContext context) async {
    final api = ApiService();
    try {
      final ride = await api.createRide(
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        estimatedPriceCents: estimate.estimatedPriceCents,
        estimatedDistanceKm: estimate.distanceKm,
        estimatedDurationMin: estimate.durationMin,
        pickupLat: pickupCoords?.latitude,
        pickupLng: pickupCoords?.longitude,
        destinationLat: destinationCoords?.latitude,
        destinationLng: destinationCoords?.longitude,
      );
      if (!context.mounted) return;
      _showSuccess(context, ride);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(BuildContext context, Ride ride) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Corrida solicitada'),
        content: Text(
          'ID: ${ride.id}\nStatus: ${ride.status}\n\n${ride.formattedPrice ?? estimate.formattedPrice}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Voltar ao início'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    RumoMap(
                      pickup: pickupCoords,
                      destination: destinationCoords,
                      height: constraints.maxHeight,
                      fitBounds: true,
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Escolher uma viagem',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.directions_car, color: Colors.blue),
                      title: const Text('Rumo'),
                      subtitle: const Text('4 passageiros • Mais rápido'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${estimate.durationMin} min',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            estimate.formattedPrice,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _requestRide(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Escolha Rumo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
