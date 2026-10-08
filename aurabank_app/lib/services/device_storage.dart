import 'dart:io' show Directory, File, Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent Device Storage using SharedPreferences and OS persistent storage.
/// Persists unique hardware device ID and authentication tokens across app restarts.
class DeviceStorage {
  static SharedPreferences? _prefs;
  static final Map<String, String> _memoryCache = {};

  static const String _deviceIdKey = 'bank_device_id';
  static const String _tokenKey = 'auth_access_token';
  static const String _userIdKey = 'auth_user_id';

  /// Initializes SharedPreferences instance. Called in main() before runApp().
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[DeviceStorage] SharedPreferences init exception: $e');
    }
  }

  /// Persistent Hardware / Unique Device ID across restarts, app updates, and reboots.
  static String getOrCreateDeviceId(String prefix) {
    // 1. Try SharedPreferences (Persistent across app restarts)
    if (_prefs != null) {
      final existing = _prefs!.getString(_deviceIdKey);
      if (existing != null && existing.isNotEmpty) {
        _memoryCache[prefix] = existing;
        return existing;
      }
    }

    // 2. Try Memory Cache
    if (_memoryCache.containsKey(prefix)) {
      return _memoryCache[prefix]!;
    }

    // 3. Try Persistent Local Storage File (Desktop / Native fallback)
    if (!kIsWeb) {
      try {
        final dir = _resolvePersistentDir();
        final file = File('$dir/.aura_bank_device_id.dat');
        if (file.existsSync()) {
          final content = file.readAsStringSync().trim();
          if (content.isNotEmpty) {
            _memoryCache[prefix] = content;
            _prefs?.setString(_deviceIdKey, content);
            return content;
          }
        }
      } catch (_) {}
    }

    // 4. Generate a stable device ID
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final newId = '$prefix-$rand';

    _memoryCache[prefix] = newId;
    _prefs?.setString(_deviceIdKey, newId);

    if (!kIsWeb) {
      try {
        final dir = _resolvePersistentDir();
        final file = File('$dir/.aura_bank_device_id.dat');
        file.writeAsStringSync(newId);
      } catch (_) {}
    }

    return newId;
  }

  static String _resolvePersistentDir() {
    try {
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'];
        if (appData != null && Directory(appData).existsSync()) return appData;
      } else if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && Directory(home).existsSync()) return home;
      }
    } catch (_) {}
    return Directory.systemTemp.path;
  }

  /// Persists authentication JWT token
  static Future<void> saveAccessToken(String token) async {
    _memoryCache[_tokenKey] = token;
    await _prefs?.setString(_tokenKey, token);
  }

  /// Retrieves persisted authentication JWT token
  static String? getAccessToken() {
    return _prefs?.getString(_tokenKey) ?? _memoryCache[_tokenKey];
  }

  /// Persists user identifier
  static Future<void> saveUserId(String userId) async {
    _memoryCache[_userIdKey] = userId;
    await _prefs?.setString(_userIdKey, userId);
  }

  /// Retrieves persisted user identifier
  static String? getUserId() {
    return _prefs?.getString(_userIdKey) ?? _memoryCache[_userIdKey];
  }

  /// Clears user tokens upon logout while preserving the hardware device ID
  static Future<void> clearSession() async {
    _memoryCache.remove(_tokenKey);
    _memoryCache.remove(_userIdKey);
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_userIdKey);
  }
}
