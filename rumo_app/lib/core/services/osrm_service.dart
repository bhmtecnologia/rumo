import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const _osrmUrl = 'https://router.project-osrm.org/route/v1/driving';

class OSRMService {
  static final OSRMService _instance = OSRMService._();
  factory OSRMService() => _instance;

  OSRMService._();

  /// Retorna lista de pontos [lat, lng] da rota entre origem e destino.
  Future<List<LatLng>> getRoutePolyline(
    double fromLng,
    double fromLat,
    double toLng,
    double toLat,
  ) async {
    final url =
        '$_osrmUrl/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      return [
        LatLng(fromLat, fromLng),
        LatLng(toLat, toLng),
      ];
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    final routes = data?['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      return [LatLng(fromLat, fromLng), LatLng(toLat, toLng)];
    }
    final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;
    if (coords == null || coords.isEmpty) {
      return [LatLng(fromLat, fromLng), LatLng(toLat, toLng)];
    }
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }
}
