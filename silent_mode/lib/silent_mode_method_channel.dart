import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'silent_mode_platform_interface.dart';

/// An implementation of [SilentModePlatform] that uses method channels.
class MethodChannelSilentMode extends SilentModePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('silent_mode');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
