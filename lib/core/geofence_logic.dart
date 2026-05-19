import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../domain/models/geofence_zone.dart';

class GeofenceLogic {
  static bool isPointInZone(LatLng point, GeofenceZone zone) {
    if (zone.type == ZoneType.circle) {
      return isPointInCircle(point, zone.points[0], zone.radius!);
    } else {
      return isPointInPolygon(point, zone.points);
    }
  }

  static bool isPointInCircle(LatLng point, LatLng center, double radiusInMeters) {
    const double earthRadius = 6371000;
    
    double dLat = _toRadians(point.latitude - center.latitude);
    double dLon = _toRadians(point.longitude - center.longitude);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(_toRadians(center.latitude)) * cos(_toRadians(point.latitude)) *
               sin(dLon / 2) * sin(dLon / 2);
               
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    
    return distance <= radiusInMeters;
  }

  static double _toRadians(double degree) => degree * pi / 180;

  /// Ray Casting Algorithm to determine if a point is inside a polygon.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool isInside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].longitude < point.longitude &&
              polygon[j].longitude >= point.longitude ||
          polygon[j].longitude < point.longitude &&
              polygon[i].longitude >= point.longitude)) {
        if (polygon[i].latitude +
                (point.longitude - polygon[i].longitude) /
                    (polygon[j].longitude - polygon[i].longitude) *
                    (polygon[j].latitude - polygon[i].latitude) <
            point.latitude) {
          isInside = !isInside;
        }
      }
      j = i;
    }
    return isInside;
  }
}
