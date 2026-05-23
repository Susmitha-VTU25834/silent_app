import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

enum ZoneType { polygon, circle }

class GeofenceZone {
  final String id;
  final String name;
  final List<LatLng> points; // For circles, points[0] is the center
  final double? radius;      // Only for circles
  final ZoneType type;
  final bool isActive;
  final String? startTime;
  final String? endTime;

  GeofenceZone({
    String? id,
    required this.name,
    required this.points,
    this.radius,
    this.type = ZoneType.polygon,
    this.isActive = true,
    this.startTime,
    this.endTime,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'start_time': startTime,
      'end_time': endTime,
      'type': type.index,
      'radius': radius,
    };
  }

  factory GeofenceZone.fromMap(Map<String, dynamic> map, List<LatLng> points) {
    ZoneType zoneType;
    if (map['type'] is String) {
      zoneType = ZoneType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ZoneType.polygon,
      );
    } else {
      zoneType = ZoneType.values[map['type'] ?? 0];
    }

    return GeofenceZone(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      startTime: map['start_time'],
      endTime: map['end_time'],
      type: zoneType,
      radius: (map['radius'] as num?)?.toDouble(),
      points: points,
    );
  }
}
