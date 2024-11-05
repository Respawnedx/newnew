// zone_storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class ZoneStorageService {
  static const String homeLocationKey = 'homeLocation';
  static const String workLocationKey = 'workLocation';
  static const String homeRadiusKey = 'homeRadius';
  static const String workRadiusKey = 'workRadius';

  Future<void> saveLocation(String locationKey, LatLng location) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(locationKey, jsonEncode({'lat': location.latitude, 'lon': location.longitude}));
  }

  Future<void> saveRadius(String radiusKey, double radius) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(radiusKey, radius);
  }

  Future<LatLng?> loadLocation(String locationKey) async {
    final prefs = await SharedPreferences.getInstance();
    final locationString = prefs.getString(locationKey);

    if (locationString != null) {
      final data = jsonDecode(locationString);
      return LatLng(data['lat'], data['lon']);
    }
    return null;
  }

  Future<double> loadRadius(String radiusKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(radiusKey) ?? 150.0; // Default radius if not set
  }
}
