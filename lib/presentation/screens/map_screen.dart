import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import '../providers/geofence_provider.dart';
import '../theme/design_system.dart';
import '../../domain/models/geofence_zone.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLocation;
  
  String _mapUrl = '';
  bool _isSatellite = false;
  int _maxNativeZoom = 19;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    bool hasPermission = await _handleLocationPermission();
    if (hasPermission) {
      _startLocationStream();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerMapOnUser();
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable them in your device settings.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permissions are denied. The app cannot center on your location.'),
              behavior: SnackBarBehavior.floating,
            ));
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in app settings.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Error checking permissions: $e");
      return false;
    }
  }

  void _startLocationStream() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  void _toggleMapStyle() {
    setState(() {
      _isSatellite = !_isSatellite;
      if (_isSatellite) {
        // Use Google Hybrid (Satellite + Labels) which is universally reliable
        _mapUrl = 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
        _maxNativeZoom = 19; 
      } else {
        _mapUrl = AppThemeMode.isDark 
          ? 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'
          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
        _maxNativeZoom = 19;
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _centerMapOnUser() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint("Error centering map: $e");
    }
  }

  void _showSaveDialog() {
    final TextEditingController _nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Name your zone', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Work, Home, etc.',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                Provider.of<GeofenceProvider>(context, listen: false)
                    .saveZone(_nameController.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: Size(100, 45)),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    // Derive map URL and zoom directly in build to ensure state is always correct, 
    // even after hot reloads or theme changes.
    if (_isSatellite) {
      _mapUrl = 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';
      _maxNativeZoom = 18; // Use pure satellite which has deeper coverage
    } else {
      _mapUrl = AppThemeMode.isDark 
          ? 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'
          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      _maxNativeZoom = 19;
    }

    return Scaffold(
      body: Consumer<GeofenceProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(37.7749, -122.4194),
                  initialZoom: 13.0,
                  maxZoom: 22.0, // Increased to allow extreme close-up zoom
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag | 
                           InteractiveFlag.pinchZoom | 
                           InteractiveFlag.doubleTapZoom | 
                           InteractiveFlag.scrollWheelZoom,
                  ),
                  onTap: (tapPosition, point) {
                    if (provider.isDrawing) {
                      provider.addPoint(point);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _mapUrl,
                    userAgentPackageName: 'com.antigravity.smart_silent_map',
                    subdomains: const ['a', 'b', 'c'],
                    maxZoom: 22.0,
                    maxNativeZoom: _maxNativeZoom,
                  ),
                  CircleLayer(
                    circles: [
                      ...provider.zones
                          .where((z) => z.type == ZoneType.circle && z.points.isNotEmpty)
                          .map((z) => CircleMarker(
                                point: z.points[0],
                                radius: z.radius ?? 200.0,
                                useRadiusInMeter: true,
                                color: AppColors.primary.withOpacity(0.3),
                                borderColor: AppColors.primary,
                                borderStrokeWidth: 3,
                              )),
                      if (provider.isDrawing && provider.drawingMode == ZoneType.circle && provider.currentDrawingPoints.isNotEmpty)
                        CircleMarker(
                          point: provider.currentDrawingPoints[0],
                          radius: provider.currentRadius,
                          useRadiusInMeter: true,
                          color: AppColors.secondary.withOpacity(0.3),
                          borderColor: AppColors.secondary,
                          borderStrokeWidth: 3,
                        ),
                    ],
                  ),
                  PolygonLayer(
                    polygons: [
                      ...provider.zones
                          .where((z) => z.type == ZoneType.polygon && z.points.length >= 3)
                          .map((zone) => Polygon(
                                points: zone.points,
                                color: AppColors.primary.withOpacity(0.3),
                                borderColor: AppColors.primary,
                                borderStrokeWidth: 3,
                                isFilled: true,
                              )),
                      if (provider.isDrawing && provider.drawingMode == ZoneType.polygon && provider.currentDrawingPoints.isNotEmpty)
                        Polygon(
                          points: provider.currentDrawingPoints,
                          color: AppColors.secondary.withOpacity(0.3),
                          borderColor: AppColors.secondary,
                          borderStrokeWidth: 3,
                          isFilled: true,
                        ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (provider.isDrawing && provider.drawingMode == ZoneType.polygon)
                        Polyline(
                          points: provider.currentDrawingPoints,
                          color: AppColors.secondary,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // User Location Pointer
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 40,
                          height: 40,
                          child: _buildUserLocationMarker(),
                        ),
                      // Drawing Points Markers
                      ...provider.currentDrawingPoints.map((p) => Marker(
                            point: p,
                            width: 8,
                            height: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
              if (provider.isDrawing)
                GestureDetector(
                  onPanStart: (details) => provider.clearDrawing(),
                  onPanUpdate: (details) {
                    final point = _mapController.camera.pointToLatLng(
                      Point(details.localPosition.dx, details.localPosition.dy),
                    );
                    provider.addPoint(point);
                  },
                  onPanEnd: (details) {
                    if (provider.drawingMode == ZoneType.circle) _showSaveDialog();
                  },
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              // Top Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _buildTopHeader(context),
                  ),
                ),
              ),
              // Right Action Buttons
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildZoomButton(
                        _isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded, 
                        _toggleMapStyle
                      ),
                      SizedBox(height: 12),
                      _buildZoomButton(Icons.person_outline_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
                      }),
                      SizedBox(height: 12),
                      _buildZoomButton(Icons.my_location_rounded, _centerMapOnUser),
                      SizedBox(height: 12),
                      _buildZoomButton(Icons.add, () {
                        final zoom = _mapController.camera.zoom + 1;
                        _mapController.move(_mapController.camera.center, zoom);
                      }),
                      SizedBox(height: 12),
                      _buildZoomButton(Icons.remove, () {
                        final zoom = _mapController.camera.zoom - 1;
                        _mapController.move(_mapController.camera.center, zoom);
                      }),
                    ],
                  ),
                ),
              ),
              // Bottom Controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 450),
                        child: _buildControls(provider),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Smart Silent Map',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.list_rounded, color: AppColors.secondary, size: 28),
                onPressed: () => Navigator.pushNamed(context, '/zones'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(GeofenceProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.isDrawing && provider.drawingMode == ZoneType.circle)
          _buildRadiusSlider(provider),
        _buildEmergencyToggle(),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !provider.isDrawing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => provider.startDrawing(ZoneType.polygon),
                              icon: Icon(Icons.polyline_rounded, color: AppColors.primary),
                              label: Text('Polygon', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 30, color: AppColors.border.withOpacity(0.3)),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => provider.startDrawing(ZoneType.circle),
                              icon: Icon(Icons.circle_outlined, color: AppColors.secondary),
                              label: Text('Circle', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('drawing_controls'),
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => provider.stopDrawing(),
                              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                              label: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: (provider.drawingMode == ZoneType.polygon 
                                    ? provider.currentDrawingPoints.length >= 3 
                                    : provider.currentDrawingPoints.isNotEmpty) 
                                    ? _showSaveDialog 
                                    : null,
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                                label: const Text('Save Zone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusSlider(GeofenceProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Text("Radius: ${provider.currentRadius.toInt()}m", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                Slider(
                  value: provider.currentRadius,
                  min: 50,
                  max: 1000,
                  activeColor: AppColors.secondary,
                  inactiveColor: AppColors.secondary.withOpacity(0.3),
                  onChanged: (val) => provider.setRadius(val),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyToggle() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final prefs = snapshot.data!;
        bool isOverride = prefs.getBool('emergency_override') ?? false;

        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOverride ? Icons.warning_amber_rounded : Icons.shield_rounded,
                    color: isOverride ? Colors.redAccent : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency Override',
                    style: TextStyle(
                      color: isOverride ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24, // Compact switch
                    child: Switch(
                      value: isOverride,
                      onChanged: (val) async {
                        await prefs.setBool('emergency_override', val);
                        setState(() {});
                      },
                      activeTrackColor: Colors.redAccent.withOpacity(0.3),
                      activeColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: AppColors.primary, size: 22), 
            onPressed: onPressed,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            const BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)
          ],
        ),
      ),
    );
  }
}
