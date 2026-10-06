// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math';

/// Web implementation using browser localStorage to persist unique device ID per physical phone/browser.
class DeviceStorage {
  static const String _storageKey = 'bank_device_id';

  static String getOrCreateDeviceId(String prefix) {
    try {
      final existing = html.window.localStorage[_storageKey];
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
      final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final newId = '$prefix-$rand';
      html.window.localStorage[_storageKey] = newId;
      return newId;
    } catch (_) {
      final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      return '$prefix-$rand';
    }
  }
}
