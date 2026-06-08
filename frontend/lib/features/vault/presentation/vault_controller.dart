import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/features/vault/data/vault_repository.dart';
import 'package:formora/features/vault/domain/user_document.dart';

class VaultState {
  final List<UserDocument> documents;
  final bool isLoading;
  final String? errorMessage;
  final bool isUploading;

  VaultState({
    this.documents = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isUploading = false,
  });

  VaultState copyWith({
    List<UserDocument>? documents,
    bool? isLoading,
    String? errorMessage,
    bool? isUploading,
  }) {
    return VaultState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class VaultNotifier extends StateNotifier<VaultState> {
  final VaultRepository _repository;

  VaultNotifier(this._repository) : super(VaultState());

  Future<void> fetchDocuments() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final documents = await _repository.listDocuments();
      state = state.copyWith(documents: documents, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> uploadDocument({
    required String filePath,
    required String filename,
    required String documentType,
  }) async {
    state = state.copyWith(isUploading: true, errorMessage: null);
    try {
      await _repository.uploadDocument(
        filePath: filePath,
        filename: filename,
        documentType: documentType,
      );
      state = state.copyWith(isUploading: false);
      await fetchDocuments();
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteDocument(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteDocument(id);
      state = state.copyWith(isLoading: false);
      await fetchDocuments();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final repository = ref.watch(vaultRepositoryProvider);
  return VaultNotifier(repository);
});
