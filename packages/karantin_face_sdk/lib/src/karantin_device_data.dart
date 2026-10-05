import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Native equivalent of the web `device-id` module.
///
/// The karantin-id backend expects the same set of fields the web client used
/// to append to the face verification multipart request (device_id,
/// fingerprint, device/browser/network strings and geo coordinates). This
/// collector produces those fields from native device APIs and caches the
/// stable identifiers in secure storage so the same device keeps the same id
/// across sessions.
class KarantinDeviceData {
  const KarantinDeviceData({
    required this.deviceId,
    required this.fingerprint,
    required this.deviceType,
    required this.device,
    required this.browser,
    required this.network,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final String deviceId;
  final String fingerprint;
  final String deviceType;
  final String device;
  final String browser;
  final String network;
  final String location;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final int timestamp;

  /// Mirrors `getDeviceDataForBackend()` + `getBackendDeviceFields()`:
  /// only non-empty values are sent, geo is split into latitude/longitude.
  Map<String, String> toBackendFields() {
    final fields = <String, String>{};

    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) fields[key] = value;
    }

    put('device_id', deviceId);
    put('finger_print', fingerprint);
    put('device', device);
    put('browser', browser);
    put('network', network);
    if (latitude != null) fields['latitude'] = latitude!.toString();
    if (longitude != null) fields['longitude'] = longitude!.toString();

    return fields;
  }
}

class KarantinDeviceDataCollector {
  KarantinDeviceDataCollector({
    FlutterSecureStorage? storage,
    DeviceInfoPlugin? deviceInfo,
    Connectivity? connectivity,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _connectivity = connectivity ?? Connectivity();

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;
  final Connectivity _connectivity;

  static const _deviceIdKey = 'karantin_device_id';
  static const _fingerprintKey = 'karantin_device_fingerprint';

  /// Collects the full device payload. Location is only read when permission is
  /// already granted (matching the web client, which never prompts here and
  /// silently resolves to null when geolocation is unavailable).
  Future<KarantinDeviceData> collect() async {
    final identity = await _getOrCreateIdentity();
    final position = await _tryGetPosition();

    return KarantinDeviceData(
      deviceId: identity.deviceId,
      fingerprint: identity.fingerprint,
      deviceType: 'mobile',
      device: await _deviceString(),
      browser: await _appString(),
      network: await _networkString(),
      location: position == null
          ? "Noma'lum"
          : '${position.latitude.toStringAsFixed(6)}°, '
                '${position.longitude.toStringAsFixed(6)}°',
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<_DeviceIdentity> _getOrCreateIdentity() async {
    final fingerprint = await _computeFingerprint();

    String? storedId;
    String? storedFingerprint;
    try {
      storedId = await _storage.read(key: _deviceIdKey);
      storedFingerprint = await _storage.read(key: _fingerprintKey);
    } catch (_) {
      // Secure storage can throw on some devices; fall through to recreate.
    }

    if (storedId != null &&
        storedId.isNotEmpty &&
        (storedFingerprint == null || storedFingerprint == fingerprint)) {
      return _DeviceIdentity(storedId, fingerprint);
    }

    final deviceId =
        'device_${fingerprint.substring(0, 12)}_'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
      await _storage.write(key: _fingerprintKey, value: fingerprint);
    } catch (_) {
      // Non-fatal: a non-persisted id still works for a single session.
    }

    return _DeviceIdentity(deviceId, fingerprint);
  }

  Future<String> _computeFingerprint() async {
    final parts = <String>[];
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        parts.addAll([
          info.id,
          info.fingerprint,
          info.model,
          info.manufacturer,
          info.brand,
          info.device,
          info.hardware,
          info.bootloader,
          '${info.version.sdkInt}',
          info.version.release,
          info.supportedAbis.join(','),
        ]);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        parts.addAll([
          info.identifierForVendor ?? '',
          info.model,
          info.name,
          info.systemName,
          info.systemVersion,
          info.utsname.machine,
          info.utsname.sysname,
        ]);
      }
    } catch (_) {
      // Fall back to whatever we gathered.
    }

    final raw = parts.where((p) => p.isNotEmpty).join('||');
    return sha256.convert(utf8.encode(raw.isEmpty ? 'native' : raw)).toString();
  }

  Future<String> _deviceString() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        final model = '${info.manufacturer} ${info.model}'.trim();
        return 'Telefon, $model, Android ${info.version.release}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        return 'Telefon, ${info.name}, iOS ${info.systemVersion}';
      }
    } catch (_) {}
    return "Telefon, Noma'lum";
  }

  Future<String> _appString() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'iOS'
          : 'Android';
      return 'Nazorat AAT ${info.version}+${info.buildNumber}, Native $platform';
    } catch (_) {
      return 'Nazorat AAT, Native';
    }
  }

  Future<String> _networkString() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      switch (result) {
        case ConnectivityResult.wifi:
          return 'WIFI';
        case ConnectivityResult.mobile:
          return 'CELLULAR';
        case ConnectivityResult.ethernet:
          return 'ETHERNET';
        case ConnectivityResult.vpn:
          return 'VPN';
        case ConnectivityResult.bluetooth:
          return 'BLUETOOTH';
        case ConnectivityResult.other:
          return 'OTHER';
        case ConnectivityResult.none:
          return "Noma'lum";
        default:
          return 'OTHER';
      }
    } catch (_) {
      return "Noma'lum";
    }
  }

  /// Reads the current position only when permission is already granted, so the
  /// face flow is never blocked waiting on a location prompt.
  Future<Position?> _tryGetPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class _DeviceIdentity {
  const _DeviceIdentity(this.deviceId, this.fingerprint);

  final String deviceId;
  final String fingerprint;
}
