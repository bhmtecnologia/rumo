import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/services/osrm_service.dart';

class RumoMap extends StatefulWidget {
  final LatLng? pickup;
  final LatLng? destination;
  final LatLng? userLocation;
  final double height;
  final bool fitBounds;

  const RumoMap({
    super.key,
    this.pickup,
    this.destination,
    this.userLocation,
    this.height = 280,
    this.fitBounds = true,
  });

  @override
  State<RumoMap> createState() => _RumoMapState();
}

class _RumoMapState extends State<RumoMap> {
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();
  static const _defaultCenter = LatLng(-23.5505, -46.6333);

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant RumoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.destination != widget.destination) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    final pickup = widget.pickup;
    final destination = widget.destination;
    if (pickup == null || destination == null) {
      setState(() => _routePoints = []);
      return;
    }
    final points = await OSRMService().getRoutePolyline(
      pickup.longitude,
      pickup.latitude,
      destination.longitude,
      destination.latitude,
    );
    if (mounted) {
      setState(() => _routePoints = points);
      if (widget.fitBounds && points.length >= 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitBounds();
        });
      }
    }
  }

  void _fitBounds() {
    if (_routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
        maxZoom: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.pickup ??
        widget.destination ??
        (widget.userLocation != null
            ? widget.userLocation!
            : _defaultCenter);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rumo.rumo_app',
            ),
            if (_routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5,
                    color: Colors.blue,
                  ),
                ],
              ),
            if (widget.pickup != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.pickup!,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.place,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
                ],
              ),
            if (widget.destination != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.destination!,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.place,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
