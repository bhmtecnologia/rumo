import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/nominatim_service.dart';
import 'package:rumo_app/core/widgets/rumo_map.dart';

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
  LatLng? _userLocation;
  bool _locationLoading = true;
  String? _locationError;
  String? _error;
  bool _loading = false;
  final _destinationController = TextEditingController();
  final _nominatim = NominatimService();
  final _api = ApiService();
  List<NominatimResult> _searchResults = [];
  bool _showSearchResults = false;

  static const _suggestions = [
    _Suggestion('Sqs 303 - Bloco H', 'SHCS SQS 303 - Asa Sul, Brasília - DF'),
    _Suggestion('Aeroporto Internacional de Brasília', 'Lago Sul, Brasília - DF'),
    _Suggestion('Ed. The Union office', 'Brasília - DF'),
    _Suggestion('Pizza à Bessa', 'Brasília - DF'),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
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
          _userLocation = latLng;
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

  Future<void> _searchDestination(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    final results = await _nominatim.search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _showSearchResults = true;
      });
    }
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
    try {
      final estimate = await _api.getEstimate(
        pickupAddress: pickup,
        destinationAddress: dest,
        pickupLat: _pickupCoords?.latitude,
        pickupLng: _pickupCoords?.longitude,
        destinationLat: _destinationCoords?.latitude,
        destinationLng: _destinationCoords?.longitude,
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
    final results = await _nominatim.search(s.address);
    if (results.isEmpty) {
      setState(() => _error = 'Endereço não encontrado.');
      return;
    }
    _selectDestination(s.name, LatLng(results.first.lat, results.first.lon));
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
                  if (!_loading)
                    RumoMap(
                      pickup: _pickupCoords,
                      destination: _destinationCoords,
                      userLocation: _userLocation,
                      height: 220,
                      fitBounds: _destinationCoords != null,
                    ),
                  const SizedBox(height: 16),
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
  const _Suggestion(this.name, this.address);
}
