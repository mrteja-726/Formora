// lib/core/permissions/permission_service.dart
//
// Handles camera, photo library, and storage permissions.
// Provides user-facing rationale before requesting.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

enum PermissionType { camera, photos, storage }

class PermissionService {
  /// Request camera access (for document capture).
  Future<bool> requestCamera() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true; // Desktop platforms handle file access differently
    }
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request photo library access (for picking document images).
  Future<bool> requestPhotos() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }
    if (Platform.isAndroid) {
      // Android 13+: READ_MEDIA_IMAGES, older: READ_EXTERNAL_STORAGE
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        final alt = await Permission.storage.request();
        return alt.isGranted;
      }
      return status.isGranted;
    }
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Check if a permission is permanently denied.
  Future<bool> isPermanentlyDenied(PermissionType type) async {
    final permission = _toPermission(type);
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings so user can manually grant permissions.
  Future<void> openSettings() => openAppSettings();

  /// Current status of a permission.
  Future<PermissionStatus> check(PermissionType type) =>
      _toPermission(type).status;

  Permission _toPermission(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return Permission.camera;
      case PermissionType.photos:
        return Permission.photos;
      case PermissionType.storage:
        return Permission.storage;
    }
  }
}
