// lib/features/backup/domain/backup_manifest.dart
//
// Backup package manifest — stored as manifest.json inside the .formora file.

class BackupManifest {
  static const currentVersion = 1;
  static const fileExtension = '.formora';

  final int version;
  final DateTime createdAt;
  final String appVersion;
  final int profileCount;
  final int documentCount;
  final int achievementCount;
  final int conversationCount;
  final String dataChecksum; // SHA-256 of the unencrypted ZIP
  final String deviceId;    // Anonymous, for corruption debugging

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

  bool get isCompatible => version <= currentVersion;
}

/// Errors that can occur during restore.
enum RestoreError {
  fileNotFound,
  decryptionFailed,
  checksumMismatch,
  versionIncompatible,
  corruptedArchive,
  importFailed,
}

class RestoreException implements Exception {
  final RestoreError error;
  final String message;

  const RestoreException(this.error, this.message);

  @override
  String toString() => 'RestoreException(${error.name}): $message';
}
