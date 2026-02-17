import 'dart:convert';

import 'package:http/http.dart' as http;

const _searchUrl = 'https://nominatim.openstreetmap.org/search';
const _reverseUrl = 'https://nominatim.openstreetmap.org/reverse';

class NominatimResult {
  final String displayName;
  final double lat;
  final double lon;

  NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

class NominatimService {
  static final NominatimService _instance = NominatimService._();
  factory NominatimService() => _instance;

  NominatimService._();

  Future<List<NominatimResult>> search(String query) async {
    if (query.trim().length < 3) return [];
    final params = {
      'q': query.trim(),
      'format': 'json',
      'addressdetails': '1',
      'limit': '6',
    };
    final uri = Uri.parse(_searchUrl).replace(queryParameters: params);
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data
        .map((e) => NominatimResult(
              displayName: e['display_name'] as String? ?? '',
              lat: double.tryParse('${e['lat']}') ?? 0,
              lon: double.tryParse('${e['lon']}') ?? 0,
            ))
        .toList();
  }

  Future<String?> reverseGeocode(double lat, double lon) async {
    final params = {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'format': 'json',
    };
    final uri = Uri.parse(_reverseUrl).replace(queryParameters: params);
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    return data?['display_name'] as String?;
  }
}
