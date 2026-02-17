import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/models/estimate.dart';
import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/widgets/rumo_map.dart';
import 'package:rumo_app/modules/passageiro/screens/waiting_for_driver_screen.dart';

class TripChoiceScreen extends StatefulWidget {
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

  @override
  State<TripChoiceScreen> createState() => _TripChoiceScreenState();
}

class _TripChoiceScreenState extends State<TripChoiceScreen> {
  bool _requesting = false;

  Future<void> _requestRide(BuildContext context) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final api = ApiService();
    try {
      final ride = await api.createRide(
        pickupAddress: widget.pickupAddress,
        destinationAddress: widget.destinationAddress,
        estimatedPriceCents: widget.estimate.estimatedPriceCents,
        estimatedDistanceKm: widget.estimate.distanceKm,
        estimatedDurationMin: widget.estimate.durationMin,
        pickupLat: widget.pickupCoords?.latitude,
        pickupLng: widget.pickupCoords?.longitude,
        destinationLat: widget.destinationCoords?.latitude,
        destinationLng: widget.destinationCoords?.longitude,
      );
      if (!context.mounted) return;
      setState(() => _requesting = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            ride: ride,
            formattedPrice: widget.estimate.formattedPrice,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      pickup: widget.pickupCoords,
                      destination: widget.destinationCoords,
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
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.radio_button_checked, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.pickupAddress,
                          style: TextStyle(fontSize: 13, color: Colors.grey[300]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.destinationAddress,
                          style: TextStyle(fontSize: 13, color: Colors.grey[300]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
                            '${widget.estimate.durationMin} min',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            widget.estimate.formattedPrice,
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
                    onPressed: _requesting ? null : () => _requestRide(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _requesting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Escolha Rumo'),
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
