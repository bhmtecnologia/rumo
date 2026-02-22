import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/services/nominatim_service.dart';

class DefineLocationScreen extends StatefulWidget {
  final LatLng initialPosition;

  const DefineLocationScreen({
    super.key,
    required this.initialPosition,
  });

  @override
  State<DefineLocationScreen> createState() => _DefineLocationScreenState();
}

class _DefineLocationScreenState extends State<DefineLocationScreen> {
  final MapController _mapController = MapController();
  LatLng? _marker;
  bool _loading = false;
  final _nominatim = NominatimService();
  String? _hint;

  @override
  void initState() {
    super.initState();
    _marker = widget.initialPosition;
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (position.center != null) {
      setState(() {
        _marker = position.center;
      });
    }
  }

  Future<void> _confirm() async {
    if (_marker == null) return;
    setState(() {
      _loading = true;
      _hint = null;
    });
    try {
      final address = await _nominatim.reverseGeocode(_marker!.latitude, _marker!.longitude);
      Navigator.of(context).pop(DefineLocationResult(
        coords: _marker!,
        address: address?.trim(),
      ));
    } catch (_) {
      setState(() => _hint = 'Não foi possível obter o endereço. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _marker ?? widget.initialPosition;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defina a localização no mapa'),
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: center,
              zoom: 16,
              onPositionChanged: _onPositionChanged,
              interactiveFlags: InteractiveFlag.all,
            ),
            children: [
              TileLayer(
                urlTemplate: kIsWeb
                    ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rumo.rumo_app',
                subdomains: kIsWeb ? ['a', 'b', 'c', 'd'] : ['a', 'b', 'c'],
              ),
            ],
          ),
          Center(
            child: IgnorePointer(
              ignoring: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.place, size: 48, color: Colors.redAccent),
                  Icon(Icons.circle, size: 16, color: Colors.black26),
                ],
              ),
            ),
          ),
          if (_hint != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _hint!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _confirm,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
            label: const Text('Confirmar destino'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ),
    );
  }
}

class DefineLocationResult {
  final LatLng coords;
  final String? address;

  DefineLocationResult({
    required this.coords,
    this.address,
  });
}
