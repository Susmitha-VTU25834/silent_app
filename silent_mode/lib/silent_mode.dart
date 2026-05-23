
import 'silent_mode_platform_interface.dart';

class SilentMode {
  Future<String?> getPlatformVersion() {
    return SilentModePlatform.instance.getPlatformVersion();
  }
}
