import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/storage/secure_storage.dart';
import 'package:formora/features/auth/presentation/auth_controller.dart';
import 'package:formora/features/form_automation/data/desktop_autofill_service.dart';

final syncServerProvider = StateNotifierProvider<SyncServerNotifier, SyncServerState>((ref) {
  final notifier = SyncServerNotifier(ref);
  ref.onDispose(() {
    notifier.stop();
  });
  
  // Listen to local auth state changes to broadcast to extension
  ref.listen(authProvider, (previous, next) async {
    if (previous?.user != next.user) {
      await notifier.broadcastLocalAuth();
    }
  });

  return notifier;
});

class SyncServerState {
  final bool isRunning;
  final int clientCount;
  final String? error;

  SyncServerState({
    required this.isRunning,
    required this.clientCount,
    this.error,
  });

  SyncServerState copyWith({
    bool? isRunning,
    int? clientCount,
    String? error,
  }) {
    return SyncServerState(
      isRunning: isRunning ?? this.isRunning,
      clientCount: clientCount ?? this.clientCount,
      error: error ?? this.error,
    );
  }
}

class SyncServerNotifier extends StateNotifier<SyncServerState> {
  final Ref _ref;
  HttpServer? _server;
  final List<WebSocket> _clients = [];

  SyncServerNotifier(this._ref) : super(SyncServerState(isRunning: false, clientCount: 0)) {
    // Only auto-start if running on desktop (non-web and windows/macos/linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      start();
    }
  }

  Future<void> start() async {
    if (state.isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 19190);
      state = SyncServerState(isRunning: true, clientCount: 0);

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleAddClient(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      }, onError: (err) {
        state = state.copyWith(error: err.toString());
      });
      debugPrint('[Formora Sync Server] Running on port 19190');
    } catch (e) {
      state = SyncServerState(isRunning: false, clientCount: 0, error: e.toString());
      debugPrint('[Formora Sync Server] Failed to start: $e');
    }
  }

  void stop() {
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    _server?.close();
    _server = null;
    state = SyncServerState(isRunning: false, clientCount: 0);
    debugPrint('[Formora Sync Server] Stopped.');
  }

  void _handleAddClient(WebSocket socket) {
    _clients.add(socket);
    state = state.copyWith(clientCount: _clients.length);
    debugPrint('[Formora Sync Server] Client connected. Total: ${_clients.length}');

    socket.listen(
      (data) {
        _handleMessage(socket, data.toString());
      },
      onDone: () {
        _clients.remove(socket);
        state = state.copyWith(clientCount: _clients.length);
        debugPrint('[Formora Sync Server] Client disconnected. Total: ${_clients.length}');
      },
      onError: (err) {
        _clients.remove(socket);
        state = state.copyWith(clientCount: _clients.length);
        debugPrint('[Formora Sync Server] Client error: $err. Total: ${_clients.length}');
      },
    );
  }

  Future<void> _handleMessage(WebSocket sender, String data) async {
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      final type = msg['type'];
      debugPrint('[Formora Sync Server] Received msg: $type');

      if (type == 'AUTH_SYNC') {
        final accessToken = msg['accessToken'] as String?;
        final refreshToken = msg['refreshToken'] as String?;
        final expiresAt = msg['expiresAt'] as int?;

        final currentAccess = await SecureStorage.getAccessToken();
        if (currentAccess != accessToken) {
          if (accessToken != null && refreshToken != null) {
            await SecureStorage.saveTokens(
              accessToken: accessToken,
              refreshToken: refreshToken,
              expiresAtMs: expiresAt ?? (DateTime.now().millisecondsSinceEpoch + 15 * 60 * 1000),
            );
            // Trigger UI reload in auth controller
            await _ref.read(authProvider.notifier).tryAutoLogin();
            debugPrint('[Formora Sync Server] Local auth storage updated from client.');
          } else {
            await SecureStorage.clear();
            await _ref.read(authProvider.notifier).logout();
            debugPrint('[Formora Sync Server] Local auth storage cleared.');
          }
          // Broadcast to other connected clients
          _broadcast(data, exclude: sender);
        }
      } else if (type == 'GET_AUTH') {
        final accessToken = await SecureStorage.getAccessToken();
        final refreshToken = await SecureStorage.getRefreshToken();
        final expiresAt = await SecureStorage.getExpiresAt();

        sender.add(jsonEncode({
          'type': 'AUTH_SYNC',
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'expiresAt': expiresAt,
        }));
      } else if (type == 'TRIGGER_DESKTOP_FILL') {
        final values = Map<String, dynamic>.from(msg['values'] as Map);
        await _executeSmartFill(values);
      }
    } catch (e) {
      debugPrint('[Formora Sync Server] Error handling message: $e');
    }
  }

  Future<void> _executeSmartFill(Map<String, dynamic> values) async {
    if (values.isEmpty) return;

    final focused = await DesktopAutofillService.getFocusedElement();
    debugPrint('[Formora Sync Server] Focused element: $focused');

    if (focused != null && focused['success'] == true) {
      final String? focusedName = focused['name']?.toString().toLowerCase();
      final String? focusedId = focused['id']?.toString().toLowerCase();
      final String? focusedClass = focused['className']?.toString().toLowerCase();

      String? valueToFill;

      // Smart match by field name or ID
      for (final entry in values.entries) {
        final key = entry.key.toLowerCase();
        if ((focusedName != null && (focusedName.contains(key) || key.contains(focusedName))) ||
            (focusedId != null && (focusedId.contains(key) || key.contains(focusedId))) ||
            (focusedClass != null && focusedClass.contains(key))) {
          valueToFill = entry.value?.toString();
          debugPrint('[Formora Sync Server] Smart match found: key "$key" matches focused element.');
          break;
        }
      }

      // Fallback: fill first non-null value if no smart match
      if (valueToFill == null) {
        valueToFill = values.values.firstWhere((v) => v != null, orElse: () => null)?.toString();
        debugPrint('[Formora Sync Server] No smart match. Using fallback value: $valueToFill');
      }

      if (valueToFill != null) {
        final success = await DesktopAutofillService.triggerAutofill(valueToFill);
        debugPrint('[Formora Sync Server] Autofill trigger result: $success');
        
        // Notify all clients of result
        _broadcast(jsonEncode({
          'type': 'FILL_COMPLETED',
          'success': success,
        }));
      }
    }
  }

  Future<void> broadcastLocalAuth() async {
    final accessToken = await SecureStorage.getAccessToken();
    final refreshToken = await SecureStorage.getRefreshToken();
    final expiresAt = await SecureStorage.getExpiresAt();

    final payload = jsonEncode({
      'type': 'AUTH_SYNC',
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt,
    });
    
    _broadcast(payload);
    debugPrint('[Formora Sync Server] Broadcast local auth state to clients.');
  }

  void _broadcast(String message, {WebSocket? exclude}) {
    for (final client in _clients) {
      if (client != exclude && client.readyState == WebSocket.open) {
        client.add(message);
      }
    }
  }
}
