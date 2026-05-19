import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../core/geofence_logic.dart';
import '../data/database_helper.dart';

const notificationChannelId = 'geofence_service_channel';
const notificationId = 888;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'Geofence Service',
    description: 'Monitoring location for silent mode',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Smart Silent Mode',
      initialNotificationContent: 'Monitoring zones...',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  const MethodChannel _nativeChannel = MethodChannel('com.antigravity.smart_silent_map/silent_mode');
  bool lastStateInside = false;

  // Battery Optimization: Only check every 10 meters of movement
  final positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    ),
  );

  await for (final position in positionStream) {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) return;
    }

    // 0. Check Emergency Override
    final prefs = await SharedPreferences.getInstance();
    bool isEmergencyOverride = prefs.getBool('emergency_override') ?? false;

    if (isEmergencyOverride) {
      if (lastStateInside) {
        try {
          await _nativeChannel.invokeMethod('setSilentMode', {'enabled': false});
          lastStateInside = false;
        } catch (e) {
          print('Emergency override native error: $e');
        }
      }
      continue;
    }

    LatLng currentPoint = LatLng(position.latitude, position.longitude);

    // 1. Get all zones
    final zones = await DatabaseHelper.instance.getAllZones();
    bool isCurrentlyInside = false;
    final now = DateTime.now();
    final currentTimeStr = DateFormat('HH:mm').format(now);

    for (var zone in zones) {
      if (zone.isActive) {
        // Time Check
        bool isTimeValid = true;
        if (zone.startTime != null && zone.endTime != null) {
          isTimeValid = currentTimeStr.compareTo(zone.startTime!) >= 0 &&
                        currentTimeStr.compareTo(zone.endTime!) <= 0;
        }

        if (isTimeValid && GeofenceLogic.isPointInZone(currentPoint, zone)) {
          isCurrentlyInside = true;
          break;
        }
      }
    }

    // 2. Toggle Silent Mode if state changed
    if (isCurrentlyInside != lastStateInside) {
      try {
        // Update Native Ringer
        await _nativeChannel.invokeMethod('setSilentMode', {'enabled': isCurrentlyInside});
        lastStateInside = isCurrentlyInside;
        
        // Show notification update to inform user
        final FlutterLocalNotificationsPlugin n = FlutterLocalNotificationsPlugin();
        n.show(
          notificationId,
          'Silent Zone Active',
          isCurrentlyInside ? 'Device Muted' : 'Device Unmuted',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'Geofence Service',
              ongoing: true,
              importance: Importance.low,
              priority: Priority.low,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
        
        if (service is AndroidServiceInstance) {
          service.setAsForegroundService();
        }
        service.invoke('update', {
          "isInside": isCurrentlyInside,
          "timestamp": DateTime.now().toIso8601String(),
        });

      } catch (e) {
        print('Error toggling silent mode: $e');
      }
    }
  }
}
