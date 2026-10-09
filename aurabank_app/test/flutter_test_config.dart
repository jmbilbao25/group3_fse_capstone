import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Runs every widget test as a device with Reduce Motion on. Ambient loops
/// (the aurora sky) then hold still, so pumpAndSettle can settle, and the
/// reduced-motion paths are exercised by the whole suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  await testMain();
}

class FakeAccessibilityFeatures implements AccessibilityFeatures {
  const FakeAccessibilityFeatures({this.disableAnimations = false});
  @override
  final bool disableAnimations;
  @override
  bool get accessibleNavigation => false;
  @override
  bool get boldText => false;
  @override
  bool get highContrast => false;
  @override
  bool get invertColors => false;
  @override
  bool get onOffSwitchLabels => false;
  @override
  bool get reduceMotion => disableAnimations;
  @override
  bool get supportsAnnounce => true;
  @override
  bool get autoPlayAnimatedImages => !disableAnimations;
  @override
  bool get autoPlayVideos => !disableAnimations;
  @override
  bool get deterministicCursor => false;
}
