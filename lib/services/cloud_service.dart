import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/models/geofence_zone.dart';

import 'package:latlong2/latlong.dart';

class CloudService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/zones";
    } else {
      return "http://192.168.31.75:3000/api/zones";
    }
  }

  Future<bool> syncZoneToCloud(GeofenceZone zone, String token) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/sync"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "id": zone.id,
          "name": zone.name,
          "type": zone.type.name,
          "points": zone.points
              .map((p) => {"lat": p.latitude, "lng": p.longitude})
              .toList(),
          "radius": zone.radius,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Sync failed with status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Cloud Sync Error: $e");
      return false;
    }
  }

  Future<List<GeofenceZone>> fetchZonesFromCloud(String token) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'];

        return data.map((z) {
          final List<dynamic> pointsData = z['points'];
          final points = pointsData
              .map((p) => LatLng(
                    (p['lat'] as num).toDouble(),
                    (p['lng'] as num).toDouble(),
                  ))
              .toList();
          return GeofenceZone.fromMap(z, points);
        }).toList();
      }
      return [];
    } catch (e) {
      print("Fetch Cloud Error: $e");
      return [];
    }
  }

  Future<bool> deleteZoneFromCloud(String id, String token) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/$id"),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Delete Cloud Error: $e");
      return false;
    }
  }
}
