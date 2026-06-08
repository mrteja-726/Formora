import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/network/api_client.dart';
import 'package:formora/features/auth/domain/user.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<User> getMe() async {
    final response = await _apiClient.dio.get('/users/me');
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        if (mfaCode != null) 'mfaCode': mfaCode,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _apiClient.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'fullName': fullName,
      },
    );
  }

  Future<void> logout(String refreshToken) async {
    await _apiClient.dio.post(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});
