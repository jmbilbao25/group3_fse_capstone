import 'dart:io';
import 'dart:math';

/// Fallback / Native implementation of device storage using persistent local file.
class DeviceStorage {
  static final Map<String, String> _memoryCache = {};

  static String getOrCreateDeviceId(String prefix) {
    if (_memoryCache.containsKey(prefix)) {
      return _memoryCache[prefix]!;
    }
    try {
      final file = File('${Directory.systemTemp.path}/bank_device_id_$prefix.txt');
      if (file.existsSync()) {
        final content = file.readAsStringSync().trim();
        if (content.isNotEmpty) {
          _memoryCache[prefix] = content;
          return content;
        }
      }
      final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final id = '$prefix-$rand';
      file.writeAsStringSync(id);
      _memoryCache[prefix] = id;
      return id;
    } catch (_) {
      final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final id = '$prefix-$rand';
      _memoryCache[prefix] = id;
      return id;
    }
  }
}
