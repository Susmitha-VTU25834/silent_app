import '../../domain/models/geofence_zone.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  Future<dynamic> get database async => null;
  Future<void> insertZone(GeofenceZone zone) async {}
  Future<List<GeofenceZone>> getAllZones() async => [];
  Future<void> deleteZone(String id) async {}
}
