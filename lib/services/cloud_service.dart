import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../domain/models/geofence_zone.dart';

class CloudService {
  static const bool isProduction = true;
  static const String prodUrl = "https://silent-app.onrender.com/api";
  static const String localUrl = "http://10.0.2.2:3000/api";

  static String get baseUrl {
    if (isProduction) {
      return prodUrl;
    }
    if (kIsWeb) {
      return "http://localhost:3000/api";
    } else {
      return localUrl;
    }
  }

  Future<bool> syncZoneToCloud(GeofenceZone zone, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/zones/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': zone.id,
          'name': zone.name,
          'type': zone.type.toString().split('.').last,
          'points': zone.points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
          'radius': zone.radius,
        }),
      );
      if (response.statusCode != 200) {
        print("Backend sync failed: ${response.statusCode} - ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      print("Sync to backend error: $e");
      return false;
    }
  }

  Future<List<GeofenceZone>> fetchZonesFromCloud(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/zones'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> zonesData = data['data'] ?? [];
        return zonesData.map((z) {
          final List<dynamic> pointsData = z['points'] ?? [];
          final points = pointsData.map((p) => LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          )).toList();
          return GeofenceZone.fromMap(z, points);
        }).toList();
      } else {
        print("Backend fetch failed: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Fetch from backend error: $e");
      return [];
    }
  }

  Future<bool> deleteZoneFromCloud(String id, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/zones/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        print("Backend delete failed: ${response.statusCode} - ${response.body}");
      }
      return response.statusCode == 200;
    } catch (e) {
      print("Delete from backend error: $e");
      return false;
    }
  }
}

