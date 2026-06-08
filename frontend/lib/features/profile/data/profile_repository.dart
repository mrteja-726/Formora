import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/network/api_client.dart';
import 'package:formora/features/profile/domain/profile.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Future<UserProfile> getProfile() async {
    final response = await _apiClient.dio.get('/profile');
    return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<ProfileField> getField(String fieldKey) async {
    final response = await _apiClient.dio.get('/profile/fields/$fieldKey');
    return ProfileField.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> upsertField({
    required String section,
    required String fieldKey,
    required String value,
    String dataType = 'string',
    String visibility = 'PRIVATE',
  }) async {
    await _apiClient.dio.put(
      '/profile/fields/$fieldKey',
      data: {
        'section': section,
        'fieldKey': fieldKey,
        'value': value,
        'dataType': dataType,
        'visibility': visibility,
      },
    );
  }

  Future<void> bulkUpsertFields(List<Map<String, dynamic>> fields) async {
    await _apiClient.dio.post(
      '/profile/fields/bulk',
      data: {
        'fields': fields,
      },
    );
  }

  Future<void> deleteField(String fieldKey) async {
    await _apiClient.dio.delete('/profile/fields/$fieldKey');
  }

  Future<Map<String, dynamic>> getCompleteness() async {
    final response = await _apiClient.dio.get('/profile/completeness');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> exportProfile() async {
    final response = await _apiClient.dio.get('/profile/export');
    final fields = response.data['data']['fields'] as List;
    return fields.cast<Map<String, dynamic>>();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient);
});
