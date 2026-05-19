import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/design_system.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;
  bool _batteryOpt = true;
  bool _cloudSync = true;
  bool _darkMode = true;
  bool _emergencyOverride = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool('notifications') ?? true;
      _batteryOpt = prefs.getBool('battery_opt') ?? true;
      _cloudSync = prefs.getBool('cloud_sync') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? true;
      _emergencyOverride = prefs.getBool('emergency_override') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'notifications') _notifications = value;
      if (key == 'battery_opt') _batteryOpt = value;
      if (key == 'cloud_sync') _cloudSync = value;
      if (key == 'dark_mode') {
        _darkMode = value;
        context.read<ThemeProvider>().toggleTheme();
      }
      if (key == 'emergency_override') _emergencyOverride = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          color: AppColors.background,
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  AppColors.background.withOpacity(0.8),
                  AppColors.primary.withOpacity(0.1),
                  AppColors.background,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    _buildAppBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          children: [
                            _buildProfileHeader(
                              (auth.name != null && auth.name!.isNotEmpty) ? auth.name! : "User Account", 
                              (auth.email != null && auth.email!.isNotEmpty) ? auth.email! : "Professional Account"
                            ),
                            const SizedBox(height: 32),
                            _buildSettingsSection(),
                            const SizedBox(height: 40),
                            _buildLogoutButton(context, auth),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Profile & Settings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              _buildSettingTile(Icons.notifications_active_outlined, 'Push Notifications', _notifications, 'notifications'),
              _buildDivider(),
              _buildSettingTile(Icons.battery_saver_outlined, 'Battery Optimization', _batteryOpt, 'battery_opt'),
              _buildDivider(),
              _buildSettingTile(Icons.sync_rounded, 'Auto Cloud Sync', _cloudSync, 'cloud_sync'),
              _buildDivider(),
              _buildSettingTile(Icons.dark_mode_outlined, 'Vibrant Dark Mode', context.watch<ThemeProvider>().isDarkMode, 'dark_mode'),
              _buildDivider(),
              _buildSettingTile(Icons.security_rounded, 'Emergency Override', _emergencyOverride, 'emergency_override', isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: AppColors.border.withOpacity(0.3), height: 1, indent: 64, endIndent: 24);
  }

  Widget _buildSettingTile(IconData icon, String title, bool value, String key, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.redAccent.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.redAccent : AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: (v) => _updateSetting(key, v),
        activeColor: isDestructive ? Colors.redAccent : AppColors.primary,
        activeTrackColor: (isDestructive ? Colors.redAccent : AppColors.primary).withOpacity(0.4),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          auth.logout();
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
        icon: const Icon(Icons.logout_rounded, size: 22),
        label: const Text(
          'LOG OUT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
