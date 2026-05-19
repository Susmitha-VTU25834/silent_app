import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../data/database_helper.dart';
import '../../domain/models/geofence_zone.dart';
import '../../services/cloud_service.dart';

class GeofenceProvider with ChangeNotifier {
  final CloudService _cloudService = CloudService();
  String? _authToken;
  List<GeofenceZone> _zones = [];
  List<LatLng> _currentDrawingPoints = [];
  bool _isDrawing = false;
  ZoneType _drawingMode = ZoneType.polygon;
  double _currentRadius = 200.0; // Default 200m

  List<GeofenceZone> get zones => _zones;
  List<LatLng> get currentDrawingPoints => _currentDrawingPoints;
  bool get isDrawing => _isDrawing;
  ZoneType get drawingMode => _drawingMode;
  double get currentRadius => _currentRadius;

  void updateToken(String? token) {
    _authToken = token;
    if (_authToken != null) {
      loadZones();
    }
  }

  Future<void> loadZones() async {
    // 1. Load from local database (always available)
    final localZones = await DatabaseHelper.instance.getAllZones();

    List<GeofenceZone> cloudZones = [];
    // 2. Fetch from cloud (only if authenticated)
    if (_authToken != null) {
      cloudZones = await _cloudService.fetchZonesFromCloud(_authToken!);
    }

    // 3. Merge results
    final Map<String, GeofenceZone> mergedMap = {};
    for (var z in localZones) {
      mergedMap[z.id] = z;
    }
    for (var z in cloudZones) {
      mergedMap[z.id] = z;
    }

    _zones = mergedMap.values.toList();
    notifyListeners();
  }

  void startDrawing(ZoneType type) {
    _isDrawing = true;
    _drawingMode = type;
    _currentDrawingPoints = [];
    notifyListeners();
  }

  void stopDrawing() {
    _isDrawing = false;
    _currentDrawingPoints = [];
    notifyListeners();
  }

  void setRadius(double value) {
    _currentRadius = value;
    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (_drawingMode == ZoneType.circle) {
      _currentDrawingPoints = [point]; // Circle center
    } else {
      // Optimization: Only add point if it moved > 2 meters from last point
      if (_currentDrawingPoints.isNotEmpty) {
        double distance =
            const Distance().as(LengthUnit.Meter, _currentDrawingPoints.last, point);
        if (distance < 2.0) return;
      }
      _currentDrawingPoints.add(point);
    }
    notifyListeners();
  }
  Future<void> saveZone(String name) async {
    final zone = GeofenceZone(
      name: name,
      points: List.from(_currentDrawingPoints),
      type: _drawingMode,
      radius: _drawingMode == ZoneType.circle ? _currentRadius : null,
    );

    // Save locally
    await DatabaseHelper.instance.insertZone(zone);

    // Sync to cloud (only if authenticated)
    if (_authToken != null) {
      await _cloudService.syncZoneToCloud(zone, _authToken!);
    }

    await loadZones();
    stopDrawing();
  }

  void clearDrawing() {
    _currentDrawingPoints = [];
    notifyListeners();
  }

  Future<void> deleteZone(String id) async {
    // Remove locally
    await DatabaseHelper.instance.deleteZone(id);

    // Remove from cloud (only if authenticated)
    if (_authToken != null) {
      await _cloudService.deleteZoneFromCloud(id, _authToken!);
    }

    await loadZones();
  }
}
