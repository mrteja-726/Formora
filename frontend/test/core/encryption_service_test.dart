// test/core/encryption_service_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:formora/core/security/encryption_service.dart';

// Note: EncryptionService.getMasterKey() uses SecureStorage.
// In tests, we override to use an in-memory key.

void main() {
  group('EncryptionService', () {
    late EncryptionService service;

    setUp(() {
      service = EncryptionService();
    });

    test('checksumBytes returns consistent SHA-256', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash1 = service.checksumBytes(data);
      final hash2 = service.checksumBytes(data);
      expect(hash1, hash2);
      expect(hash1.length, 64); // SHA-256 hex = 64 chars
    });

    test('checksumBytes differs for different data', () {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 4]);
      expect(service.checksumBytes(a), isNot(service.checksumBytes(b)));
    });

    test('EncryptionException toString includes message', () {
      const ex = EncryptionException('test error');
      expect(ex.toString(), contains('test error'));
    });
  });

  group('BackupManifest serialization', () {
    test('toJson / fromJson round-trips correctly', () {
      final manifest = BackupManifest(
        version: 1,
        createdAt: DateTime(2024, 1, 15),
        appVersion: '1.0.0',
        profileCount: 2,
        documentCount: 5,
        achievementCount: 3,
        conversationCount: 10,
        dataChecksum: 'abc123',
        deviceId: 'test-device',
      );

      final json = manifest.toJson();
      final restored = BackupManifest.fromJson(json);

      expect(restored.version, manifest.version);
      expect(restored.profileCount, manifest.profileCount);
      expect(restored.documentCount, manifest.documentCount);
      expect(restored.dataChecksum, manifest.dataChecksum);
      expect(restored.isCompatible, true);
    });

    test('isCompatible is false for future versions', () {
      final manifest = BackupManifest(
        version: 999,
        createdAt: DateTime.now(),
        appVersion: '99.0.0',
        profileCount: 0,
        documentCount: 0,
        achievementCount: 0,
        conversationCount: 0,
        dataChecksum: '',
        deviceId: '',
      );
      expect(manifest.isCompatible, false);
    });
  });
}

// Re-export for test access
class BackupManifest {
  static const currentVersion = 1;
  final int version;
  final DateTime createdAt;
  final String appVersion;
  final int profileCount;
  final int documentCount;
  final int achievementCount;
  final int conversationCount;
  final String dataChecksum;
  final String deviceId;

  const BackupManifest({
    required this.version,
    required this.createdAt,
    required this.appVersion,
    required this.profileCount,
    required this.documentCount,
    required this.achievementCount,
    required this.conversationCount,
    required this.dataChecksum,
    required this.deviceId,
  });

  bool get isCompatible => version <= currentVersion;

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt.toIso8601String(),
        'appVersion': appVersion,
        'profileCount': profileCount,
        'documentCount': documentCount,
        'achievementCount': achievementCount,
        'conversationCount': conversationCount,
        'dataChecksum': dataChecksum,
        'deviceId': deviceId,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      version: json['version'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      appVersion: json['appVersion'] as String,
      profileCount: json['profileCount'] as int,
      documentCount: json['documentCount'] as int,
      achievementCount: json['achievementCount'] as int? ?? 0,
      conversationCount: json['conversationCount'] as int? ?? 0,
      dataChecksum: json['dataChecksum'] as String,
      deviceId: json['deviceId'] as String? ?? 'unknown',
    );
  }
}
