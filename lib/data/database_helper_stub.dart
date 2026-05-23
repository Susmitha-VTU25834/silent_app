import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/geofence_zone.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  Future<dynamic> get database async => null;

  Future<void> insertZone(GeofenceZone zone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final zonesJson = prefs.getStringList('local_zones') ?? [];
      
      // Remove if existing
      zonesJson.removeWhere((item) {
        try {
          final decoded = json.decode(item);
          return decoded['id'] == zone.id;
        } catch (e) {
          return false;
        }
      });

      // Serialize points as well since toMap() doesn't serialize them
      final map = zone.toMap();
      map['points'] = zone.points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

      zonesJson.add(json.encode(map));
      await prefs.setStringList('local_zones', zonesJson);
    } catch (e) {
      print("Error inserting zone into local web storage: $e");
    }
  }

  Future<List<GeofenceZone>> getAllZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final zonesJson = prefs.getStringList('local_zones') ?? [];
      
      List<GeofenceZone> zones = [];
      for (var item in zonesJson) {
        try {
          final decoded = json.decode(item);
          final List<dynamic> pointsData = decoded['points'] ?? [];
          final points = pointsData.map((p) => LatLng(
            (p['lat'] as num).toDouble(), 
            (p['lng'] as num).toDouble()
          )).toList();
          
          zones.add(GeofenceZone.fromMap(decoded, points));
        } catch (e) {
          print("Error parsing local zone JSON: $e");
        }
      }
      return zones;
    } catch (e) {
      print("Error fetching zones from local web storage: $e");
      return [];
    }
  }

  Future<void> deleteZone(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final zonesJson = prefs.getStringList('local_zones') ?? [];
      
      zonesJson.removeWhere((item) {
        try {
          final decoded = json.decode(item);
          return decoded['id'] == id;
        } catch (e) {
          return false;
        }
      });
      
      await prefs.setStringList('local_zones', zonesJson);
    } catch (e) {
      print("Error deleting zone from local web storage: $e");
    }
  }
}
