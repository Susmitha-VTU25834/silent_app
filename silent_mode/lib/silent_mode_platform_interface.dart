import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'silent_mode_method_channel.dart';

abstract class SilentModePlatform extends PlatformInterface {
  /// Constructs a SilentModePlatform.
  SilentModePlatform() : super(token: _token);

  static final Object _token = Object();

  static SilentModePlatform _instance = MethodChannelSilentMode();

  /// The default instance of [SilentModePlatform] to use.
  ///
  /// Defaults to [MethodChannelSilentMode].
  static SilentModePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SilentModePlatform] when
  /// they register themselves.
  static set instance(SilentModePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
