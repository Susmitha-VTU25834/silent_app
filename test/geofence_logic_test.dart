import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_silent_map/core/geofence_logic.dart';

void main() {
  group('GeofenceLogic PIP Tests', () {
    final List<LatLng> squarePolygon = [
      LatLng(0, 0),
      LatLng(0, 1),
      LatLng(1, 1),
      LatLng(1, 0),
    ];

    test('Point strictly inside should return true', () {
      final point = LatLng(0.5, 0.5);
      expect(GeofenceLogic.isPointInPolygon(point, squarePolygon), isTrue);
    });

    test('Point outside should return false', () {
      final point = LatLng(2, 2);
      expect(GeofenceLogic.isPointInPolygon(point, squarePolygon), isFalse);
    });

    test('Point on edge should return false (standard ray casting)', () {
      final point = LatLng(0, 0.5);
      expect(GeofenceLogic.isPointInPolygon(point, squarePolygon), isFalse);
    });

    test('Complex concave polygon test', () {
      final List<LatLng> concavePolygon = [
        LatLng(0, 0),
        LatLng(2, 0),
        LatLng(2, 2),
        LatLng(1, 1), // "Dent"
        LatLng(0, 2),
      ];
      
      expect(GeofenceLogic.isPointInPolygon(LatLng(1, 0.5), concavePolygon), isTrue);
      expect(GeofenceLogic.isPointInPolygon(LatLng(1, 1.5), concavePolygon), isFalse); // Inside the dent
    });
  });
}
