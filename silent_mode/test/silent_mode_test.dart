import 'package:flutter_test/flutter_test.dart';
import 'package:silent_mode/silent_mode.dart';
import 'package:silent_mode/silent_mode_platform_interface.dart';
import 'package:silent_mode/silent_mode_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSilentModePlatform
    with MockPlatformInterfaceMixin
    implements SilentModePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SilentModePlatform initialPlatform = SilentModePlatform.instance;

  test('$MethodChannelSilentMode is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSilentMode>());
  });

  test('getPlatformVersion', () async {
    SilentMode silentModePlugin = SilentMode();
    MockSilentModePlatform fakePlatform = MockSilentModePlatform();
    SilentModePlatform.instance = fakePlatform;

    expect(await silentModePlugin.getPlatformVersion(), '42');
  });
}
