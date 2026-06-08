import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/storage/secure_storage.dart';
import 'package:formora/features/auth/data/auth_repository.dart';
import 'package:formora/features/auth/domain/user.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isMfaRequired;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isMfaRequired = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool? isMfaRequired,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isMfaRequired: isMfaRequired ?? this.isMfaRequired,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState()) {
    tryAutoLogin();
  }

  Future<void> tryAutoLogin() async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      state = state.copyWith(isLoading: true);
      try {
        final user = await _repository.getMe();
        state = state.copyWith(user: user, isLoading: false);
      } catch (e) {
        state = state.copyWith(isLoading: false, clearUser: true);
        await SecureStorage.clear();
      }
    }
  }

  Future<bool> login({required String email, required String password, String? mfaCode}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _repository.login(email: email, password: password, mfaCode: mfaCode);
      
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final expiresIn = data['expiresIn'] as int;

      await SecureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
      );

      final user = await _repository.getMe();
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on DioException catch (e) {
      String msg = e.message ?? e.toString();
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          msg = data['message'] ?? msg;
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({required String email, required String password, required String fullName}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.register(email: email, password: password, fullName: fullName);
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      String msg = e.message ?? e.toString();
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          msg = data['message'] ?? msg;
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _repository.logout(refreshToken);
      } catch (_) {}
    }
    await SecureStorage.clear();
    state = state.copyWith(isLoading: false, clearUser: true);
  }

  Future<bool> upgradeUserPlan() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.upgradePlan();
      final user = await _repository.getMe();
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on DioException catch (e) {
      String msg = e.message ?? e.toString();
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          msg = data['message'] ?? msg;
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
