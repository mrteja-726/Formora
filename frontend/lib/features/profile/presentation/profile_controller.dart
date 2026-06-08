import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/features/profile/data/profile_repository.dart';
import 'package:formora/features/profile/domain/profile.dart';

class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? completeness;
  final Map<String, String> decryptedValues;

  ProfileState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.completeness,
    this.decryptedValues = const {},
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? completeness,
    Map<String, String>? decryptedValues,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      completeness: completeness ?? this.completeness,
      decryptedValues: decryptedValues ?? this.decryptedValues,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(ProfileState());

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _repository.getProfile();
      final completeness = await _repository.getCompleteness();
      final decryptedList = await _repository.exportProfile();

      final Map<String, String> decryptedValues = {};
      for (final f in decryptedList) {
        decryptedValues[f['fieldKey'] as String] = f['value'] as String? ?? '';
      }

      state = state.copyWith(
        profile: profile,
        completeness: completeness,
        decryptedValues: decryptedValues,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> saveField({
    required String section,
    required String fieldKey,
    required String value,
    String dataType = 'string',
    String visibility = 'PRIVATE',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.upsertField(
        section: section,
        fieldKey: fieldKey,
        value: value,
        dataType: dataType,
        visibility: visibility,
      );
      // Reload profile
      await fetchProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteField(String fieldKey) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteField(fieldKey);
      await fetchProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});
