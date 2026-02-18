import 'dart:math' show asin, cos, sqrt;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';
import 'package:rumo_app/core/services/nominatim_service.dart';

import 'trip_choice_screen.dart';

class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({super.key});

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  String _pickupAddress = '';
  String _destinationAddress = '';
  LatLng? _pickupCoords;
  LatLng? _destinationCoords;
  bool _locationLoading = true;
  String? _locationError;
  String? _error;
  bool _loading = false;
  final _destinationController = TextEditingController();
  final _nominatim = NominatimService();
  final _api = ApiService();
  List<NominatimResult> _searchResults = [];
  bool _showSearchResults = false;
  List<CostCenter> _userCostCenters = [];
  String? _selectedCostCenterId;

  /// Sugestões com coordenadas reais quando disponível (lat, lng).
  static const _suggestions = [
    _Suggestion('Sqs 303 - Bloco H', 'SHCS SQS 303 - Asa Sul, Brasília - DF', -15.7939, -47.8822),
    _Suggestion('Aeroporto Internacional de Brasília', 'Lago Sul, Brasília - DF', -15.8711, -47.9186),
    _Suggestion('Ed. The Union office', 'Brasília - DF', null, null),
    _Suggestion('Pizza à Bessa', 'Brasília - DF', null, null),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadUserCostCenters();
  }

  Future<void> _loadUserCostCenters() async {
    final ids = AuthService().currentUser?.costCenterIds ?? [];
    if (ids.isEmpty) return;
    try {
      final list = await _api.listCostCenters();
      if (!mounted) return;
      final filtered = list.where((c) => ids.contains(c.id)).toList();
      setState(() {
        _userCostCenters = filtered;
        if (_selectedCostCenterId == null && filtered.isNotEmpty) {
          _selectedCostCenterId = filtered.first.id;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      if (!kIsWeb) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied ||
              requested == LocationPermission.deniedForever) {
            if (mounted) {
              setState(() {
                _locationLoading = false;
                _locationError = 'Ative a localização para usar sua posição.';
              });
            }
            return;
          }
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      final address =
          await _nominatim.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _pickupCoords = latLng;
          _pickupAddress = address ?? 'Minha localização';
          _locationLoading = false;
          _locationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Não foi possível obter sua localização.';
        });
      }
    }
  }

  /// Distância aproximada em km entre dois pontos (Haversine).
  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R = 12742 km
  }

  Future<void> _searchDestination(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    final results = await _nominatim.search(query);
    if (!mounted) return;
    // Ordena por proximidade da origem (aeroporto/localidade mais perto primeiro).
    final sorted = _pickupCoords != null && results.isNotEmpty
        ? _sortByDistanceFrom(results, _pickupCoords!)
        : results;
    setState(() {
      _searchResults = sorted;
      _showSearchResults = true;
    });
  }

  List<NominatimResult> _sortByDistanceFrom(List<NominatimResult> list, LatLng from) {
    final out = List<NominatimResult>.from(list);
    out.sort((a, b) {
      final da = _distanceKm(from.latitude, from.longitude, a.lat, a.lon);
      final db = _distanceKm(from.latitude, from.longitude, b.lat, b.lon);
      return da.compareTo(db);
    });
    return out;
  }

  String? _resolveCostCenterId() {
    final ids = AuthService().currentUser?.costCenterIds ?? [];
    if (ids.isEmpty) return null;
    if (ids.length == 1) return ids.single;
    return _selectedCostCenterId;
  }

  void _selectDestination(String address, LatLng coords) {
    _destinationController.text = address;
    setState(() {
      _destinationAddress = address;
      _destinationCoords = coords;
      _showSearchResults = false;
      _searchResults = [];
    });
    _openTripChoice();
  }

  Future<void> _openTripChoice() async {
    final pickup = _pickupAddress.trim();
    final dest = _destinationAddress.trim();
    if (pickup.isEmpty || dest.isEmpty) {
      setState(() => _error = 'Preencha origem e destino.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final costCenterId = _resolveCostCenterId();
    try {
      final estimate = await _api.getEstimate(
        pickupAddress: pickup,
        destinationAddress: dest,
        pickupLat: _pickupCoords?.latitude,
        pickupLng: _pickupCoords?.longitude,
        destinationLat: _destinationCoords?.latitude,
        destinationLng: _destinationCoords?.longitude,
        costCenterId: costCenterId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripChoiceScreen(
            estimate: estimate,
            pickupAddress: pickup,
            destinationAddress: dest,
            pickupCoords: _pickupCoords,
            destinationCoords: _destinationCoords,
            costCenterId: costCenterId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openTripChoiceFromSuggestion(_Suggestion s) async {
    if (s.lat != null && s.lng != null) {
      _selectDestination(s.name, LatLng(s.lat!, s.lng!));
      return;
    }
    final results = await _nominatim.search(s.address);
    if (results.isEmpty) {
      setState(() => _error = 'Endereço não encontrado.');
      return;
    }
    _selectDestination(s.name, LatLng(results.first.lat, results.first.lon));
  }

  Future<void> _openMapPicker() async {
    final defaultLocation = LatLng(-15.7939, -47.8822);
    final initial = _destinationCoords ?? _pickupCoords ?? defaultLocation;
    final result = await Navigator.of(context).push<DefineLocationResult>(
      MaterialPageRoute(
        builder: (_) => DefineLocationScreen(initialPosition: initial),
      ),
    );
    if (result != null && mounted) {
      final label = (result.address?.trim().isNotEmpty ?? false) ? result.address! : 'Destino selecionado';
      setState(() {
        _destinationAddress = label;
        _destinationCoords = result.coords;
        _destinationController.text = label;
        _showSearchResults = false;
        _searchResults = [];
      });
      _openTripChoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planeje sua viagem'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Calculando rota...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_locationLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Obtendo sua localização...'),
                        ],
                      ),
                    )
                  else if (_locationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _locationError!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  if (_userCostCenters.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCostCenterId,
                        decoration: const InputDecoration(
                          labelText: 'Centro de custo',
                          border: OutlineInputBorder(),
                        ),
                        items: _userCostCenters
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCostCenterId = v),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.radio_button_checked, size: 20),
                            ),
                            title: Text(
                              _pickupAddress.isEmpty
                                  ? 'Embarque'
                                  : _pickupAddress,
                              style: TextStyle(
                                color: _pickupAddress.isEmpty
                                    ? Colors.grey
                                    : null,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.place, size: 20),
                            ),
                            title: TextField(
                              controller: _destinationController,
                              decoration: const InputDecoration(
                                hintText: 'Para onde?',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setState(() => _destinationAddress = v);
                                _searchDestination(v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(r.displayName),
                            onTap: () => _selectDestination(
                              r.displayName,
                              LatLng(r.lat, r.lon),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('Sugestões',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._suggestions.map((s) => ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(s.name),
                        subtitle: Text(s.address,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        onTap: () => _openTripChoiceFromSuggestion(s),
                      )),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Defina a localização no mapa'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Suggestion {
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  const _Suggestion(this.name, this.address, [this.lat, this.lng]);
}
