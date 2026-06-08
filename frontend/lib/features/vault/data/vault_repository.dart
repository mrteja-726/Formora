import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/network/api_client.dart';
import 'package:formora/features/vault/domain/user_document.dart';

class VaultRepository {
  final ApiClient _apiClient;

  VaultRepository(this._apiClient);

  Future<List<UserDocument>> listDocuments({int page = 1, int limit = 20}) async {
    final response = await _apiClient.dio.get(
      '/documents',
      queryParameters: {'page': page, 'limit': limit},
    );
    // NestJS list returns { success: true, data: { items: [...], meta: {...} } }
    final items = response.data['data']['items'] as List;
    return items.map((json) => UserDocument.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<UserDocument> uploadDocument({
    required String filePath,
    required String filename,
    required String documentType,
  }) async {
    final file = await MultipartFile.fromFile(
      filePath,
      filename: filename,
    );
    final formData = FormData.fromMap({
      'file': file,
    });

    final response = await _apiClient.dio.post(
      '/documents',
      queryParameters: {'documentType': documentType},
      data: formData,
    );
    return UserDocument.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String id) async {
    await _apiClient.dio.delete('/documents/$id');
  }
}

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VaultRepository(apiClient);
});
