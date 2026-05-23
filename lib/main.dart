import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/geofence_provider.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/zone_list_screen.dart';
import 'presentation/theme/design_system.dart';
import 'services/background_location_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'presentation/widgets/fast_page_route.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProxyProvider<AuthProvider, GeofenceProvider>(
          create: (_) => GeofenceProvider(),
          update: (_, auth, geofence) => geofence!..updateToken(auth.token),
        ),
      ],
      child: MyApp(),
    ),
  );

  // Initialize Firebase and background services asynchronously to prevent blocking startup
  _initializeAsyncServices();
}

Future<void> startBackgroundServiceIfPermitted() async {
  if (kIsWeb) return;
  try {
    var locationStatus = await Permission.locationAlways.status;
    bool hasDnd = false;
    try {
      hasDnd = await const MethodChannel('com.antigravity.smart_silent_map/silent_mode')
          .invokeMethod('checkDndPermission');
    } catch (e) {
      print('Native DND check error: $e');
    }
    if (locationStatus.isGranted && hasDnd) {
      await initializeBackgroundService();
      print("✅ Background location service started successfully.");
    } else {
      print("⚠️ Background location service not started: Permissions not fully granted yet.");
    }
  } catch (e) {
    print("Background service startup check error: $e");
  }
}

Future<void> _initializeAsyncServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization error (did you run flutterfire configure?): $e");
  }
  
  await startBackgroundServiceIfPermitted();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Smart Silent Map',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: theme.isDarkMode ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: theme.isDarkMode ? Brightness.dark : Brightness.light,
              surface: AppColors.surface,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isAuthenticated) {
                return PermissionWrapper();
              }
              return AuthScreen();
            },
          ),
          onGenerateRoute: (settings) {
            if (settings.name == '/zones') {
              return FastPageRoute(
                child: ZoneListScreen(),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  @override
  _PermissionWrapperState createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> with WidgetsBindingObserver {
  static const MethodChannel _nativeChannel = MethodChannel('com.antigravity.smart_silent_map/silent_mode');
  bool _isLoading = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when user returns to app from settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    if (kIsWeb) {
      setState(() {
        _hasPermissions = true;
        _isLoading = false;
      });
      return;
    }

    // Request Foreground Location first (required on Android 10+ before background location)
    var foregroundStatus = await Permission.location.status;
    if (!foregroundStatus.isGranted) {
      foregroundStatus = await Permission.location.request();
      if (!foregroundStatus.isGranted) {
        setState(() {
          _hasPermissions = false;
          _isLoading = false;
        });
        return;
      }
    }

    // Request Background Location (Always allow)
    var locationStatus = await Permission.locationAlways.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.locationAlways.request();
    }

    // Check DND Access (Native)
    bool hasDnd = false;
    try {
      hasDnd = await _nativeChannel.invokeMethod('checkDndPermission');
    } catch (e) {
      print('Native error: $e');
    }
    
    if (!hasDnd) {
      try {
        await _nativeChannel.invokeMethod('openDndSettings');
      } catch (e) {
         print('Native error: $e');
      }
    }

    final bool isGranted = locationStatus.isGranted && hasDnd;
    if (isGranted) {
      await startBackgroundServiceIfPermitted();
    }

    setState(() {
      _hasPermissions = isGranted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          color: AppColors.background,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (!_hasPermissions) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          color: AppColors.background,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppDesign.surfaceContainer(
                padding: EdgeInsets.all(40),
                child: Icon(Icons.security_outlined, size: 80, color: AppColors.secondary),
              ),
              SizedBox(height: 40),
              Text(
                'Setup Permissions',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              SizedBox(height: 16),
              Text(
                'We need "Always Allow" location and "Do Not Disturb" access to automate your silent mode.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 48),
              ElevatedButton(
                onPressed: _checkPermissions,
                child: Text('Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return MapScreen();
  }
}
