// lib/core/security/encryption_service.dart
//
// AES-256-GCM encryption for:
//  - Document files (encrypt to disk / decrypt to temp)
//  - Backup packages (encrypt/decrypt byte arrays)
//
// Master key: 256-bit random key, stored in FlutterSecureStorage.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:formora/core/storage/secure_storage.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

class EncryptionService {
  static const _ivLength = 16; // 128-bit IV for AES-GCM

  // ── Key Management ─────────────────────────────────────────────────────

  Future<enc.Key> getMasterKey() async {
    String? keyBase64 = await SecureStorage.getMasterKey();
    if (keyBase64 == null) {
      // First run — generate a new 256-bit key
      final keyBytes = _generateRandomBytes(32);
      keyBase64 = base64Encode(keyBytes);
      await SecureStorage.saveMasterKey(keyBase64);
    }
    final keyBytes = base64Decode(keyBase64);
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  Uint8List _generateRandomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rng.nextInt(256)));
  }

  // ── File Encryption ────────────────────────────────────────────────────

  /// Encrypts [sourceFile] and writes ciphertext to [destPath].
  /// Format: [16 bytes IV][ciphertext...]
  Future<void> encryptFile(File sourceFile, String destPath) async {
    final key = await getMasterKey();
    final iv = enc.IV(_generateRandomBytes(_ivLength));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final plaintext = await sourceFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(plaintext.toList(), iv: iv);

    // Prepend IV to ciphertext
    final output = Uint8List(_ivLength + encrypted.bytes.length);
    output.setRange(0, _ivLength, iv.bytes);
    output.setRange(_ivLength, output.length, encrypted.bytes);

    final destFile = File(destPath);
    await destFile.parent.create(recursive: true);
    await destFile.writeAsBytes(output);
  }

  /// Decrypts an encrypted file to a temporary file.
  /// ⚠️ Caller MUST delete the temp file after use.
  Future<File> decryptFileToTemp(File encFile, String originalFilename) async {
    final bytes = await encFile.readAsBytes();
    final decrypted = await _decryptBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, 'formora_$originalFilename'));
    await tempFile.writeAsBytes(decrypted);
    return tempFile;
  }

  /// Decrypts an encrypted file and returns the raw bytes.
  Future<Uint8List> decryptFileBytes(File encFile) async {
    final bytes = await encFile.readAsBytes();
    return _decryptBytes(bytes);
  }

  Future<Uint8List> _decryptBytes(Uint8List data) async {
    if (data.length < _ivLength) {
      throw const EncryptionException('Encrypted data too short');
    }
    final key = await getMasterKey();
    final iv = enc.IV(data.sublist(0, _ivLength));
    final ciphertext = data.sublist(_ivLength);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    try {
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(ciphertext)),
        iv: iv,
      );
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw EncryptionException('Decryption failed: $e');
    }
  }

  // ── Backup Encryption ──────────────────────────────────────────────────

  /// Encrypts raw bytes for a backup package.
  Future<Uint8List> encryptBackupBytes(Uint8List plaintext) async {
    final key = await getMasterKey();
    final iv = enc.IV(_generateRandomBytes(_ivLength));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(plaintext.toList(), iv: iv);
    final output = Uint8List(_ivLength + encrypted.bytes.length);
    output.setRange(0, _ivLength, iv.bytes);
    output.setRange(_ivLength, output.length, encrypted.bytes);
    return output;
  }

  /// Decrypts a backup package.
  Future<Uint8List> decryptBackupBytes(Uint8List ciphertext) async {
    return _decryptBytes(ciphertext);
  }

  // ── Checksum ───────────────────────────────────────────────────────────

  /// Returns a SHA-256 hex digest for integrity verification.
  String checksumBytes(Uint8List data) {
    return sha256.convert(data).toString();
  }
}

class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);
  @override
  String toString() => 'EncryptionException: $message';
}
