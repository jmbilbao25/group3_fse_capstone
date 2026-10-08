import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import '../services/device_storage.dart';

class UserPersona {
  final String name;
  final String role;
  final String email;
  final String password;
  final String accountId;
  final double balance;

  const UserPersona({
    required this.name,
    required this.role,
    required this.email,
    required this.password,
    required this.accountId,
    required this.balance,
  });

  static const List<UserPersona> demoPersonas = [
    UserPersona(
      name: 'Juan Dela Cruz',
      role: 'Customer',
      email: 'juan.dc@email.com',
      password: 'password123',
      accountId: '1000-2000-3001',
      balance: 15000000.00,
    ),
    UserPersona(
      name: 'Maria Clara Reyes',
      role: 'Customer',
      email: 'maria.reyes@email.com',
      password: 'password123',
      accountId: '1000-2000-3002',
      balance: 5000000.00,
    ),
    UserPersona(
      name: 'Diana Vance',
      role: 'Admin / Teller',
      email: 'diana.admin@bank.com',
      password: 'password123',
      accountId: '1000-8800-9902',
      balance: 450000.00,
    ),
  ];
}

class DevicePreset {
  final String id;
  final String name;
  final String label;
  final String platform;
  final String deviceType;

  const DevicePreset({
    required this.id,
    required this.name,
    required this.label,
    this.platform = 'Generic',
    this.deviceType = 'MOBILE',
  });

  static const List<DevicePreset> presets = [
    DevicePreset(
      id: 'dev-laptop-web',
      name: 'MacBook Pro (Chrome)',
      label: 'Desktop Session (Web)',
      platform: 'Web / Desktop',
      deviceType: 'WEB',
    ),
    DevicePreset(
      id: 'dev-iphone-primary',
      name: 'iPhone 15 Pro',
      label: 'Device 1 (Primary - iPhone)',
      platform: 'iOS',
      deviceType: 'MOBILE',
    ),
    DevicePreset(
      id: 'dev-ipad-secondary',
      name: 'iPad Air',
      label: 'Device 2 (Secondary - iPad)',
      platform: 'iPadOS',
      deviceType: 'MOBILE',
    ),
    DevicePreset(
      id: 'dev-galaxy-third',
      name: 'Samsung Galaxy Tab S9',
      label: 'Device 3 (3rd Device - Galaxy)',
      platform: 'Android',
      deviceType: 'MOBILE',
    ),
  ];

  static DevicePreset get defaultPreset => presets.first;
}

class DeviceIdentity {
  static final DeviceIdentity _instance = DeviceIdentity._internal();
  factory DeviceIdentity() => _instance;
  DeviceIdentity._internal() {
    _id = _defaultId();
    _name = _defaultName(_id);
    _type = _defaultType();
  }

  static String _defaultType() {
    if (kIsWeb) return 'WEB';
    return 'MOBILE';
  }

  static String _defaultId() {
    if (kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return DeviceStorage.getOrCreateDeviceId('android-phone');
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return DeviceStorage.getOrCreateDeviceId('iphone');
      }
      return DeviceStorage.getOrCreateDeviceId('laptop-chrome');
    }
    try {
      if (Platform.isAndroid) return DeviceStorage.getOrCreateDeviceId('android-apk');
      if (Platform.isIOS) return DeviceStorage.getOrCreateDeviceId('ios-app');
    } catch (_) {}
    return DeviceStorage.getOrCreateDeviceId('client-device');
  }

  static String _defaultName(String deviceId) {
    final parts = deviceId.split('-');
    final suffix = parts.length > 1 ? parts.last.toUpperCase() : '';
    final code = suffix.isNotEmpty ? ' (#$suffix)' : '';

    if (kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) return 'Android Phone$code';
      if (defaultTargetPlatform == TargetPlatform.iOS) return 'iPhone (Safari)$code';
      return 'Windows Laptop (Chrome)$code';
    }
    try {
      if (Platform.isAndroid) return 'Android Device$code';
      if (Platform.isIOS) return 'Apple iPhone$code';
    } catch (_) {}
    return 'Windows PC$code';
  }

  late String _id;
  late String _name;
  late String _type;

  String get id => _id;
  String get name => _name;
  String get type => _type;

  void setDevice(String newId, String newName, {String newType = 'MOBILE'}) {
    _id = newId;
    _name = newName;
    _type = newType;
  }
}

