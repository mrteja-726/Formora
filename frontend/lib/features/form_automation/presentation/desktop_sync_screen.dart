import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/features/auth/presentation/auth_controller.dart';
import 'package:formora/features/form_automation/data/desktop_autofill_service.dart';
import 'package:formora/features/form_automation/data/sync_server.dart';

class DesktopSyncScreen extends ConsumerStatefulWidget {
  const DesktopSyncScreen({super.key});

  @override
  ConsumerState<DesktopSyncScreen> createState() => _DesktopSyncScreenState();
}

class _DesktopSyncScreenState extends ConsumerState<DesktopSyncScreen> {
  bool _isTrackingFocus = false;
  Timer? _focusTimer;
  Map<String, dynamic>? _focusedElement;
  bool _isAccessibilityTrusted = true;
  final _testInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _testInputController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessibility() async {
    // Only call method channel on actual desktop targets (Windows/macOS)
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      final trusted = await DesktopAutofillService.isAccessibilityTrusted();
      if (mounted) {
        setState(() {
          _isAccessibilityTrusted = trusted;
        });
      }
    }
  }

  void _toggleFocusTracking(bool value) {
    setState(() {
      _isTrackingFocus = value;
    });

    if (value) {
      _focusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
          final element = await DesktopAutofillService.getFocusedElement();
          if (mounted && _isTrackingFocus) {
            setState(() {
              _focusedElement = element;
            });
          }
        }
      });
    } else {
      _focusTimer?.cancel();
      _focusTimer = null;
      setState(() {
        _focusedElement = null;
      });
    }
  }

  Future<void> _runTestFill() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Click the test input field below to focus it... Filling in 2 seconds.'),
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      await DesktopAutofillService.triggerAutofill('Formora Native Fill Work!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(syncServerProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Desktop Integration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _checkAccessibility();
              ref.read(syncServerProvider.notifier).start();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Connection Status Cards ──
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    title: 'SYNC SERVER',
                    status: serverState.isRunning ? 'RUNNING' : 'STOPPED',
                    subtitle: serverState.isRunning ? 'Port 19190' : (serverState.error ?? 'Unavailable'),
                    color: serverState.isRunning ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    icon: Icons.router,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusCard(
                    title: 'EXTENSION CLIENTS',
                    status: '${serverState.clientCount} CONNECTED',
                    subtitle: 'Automatic syncing',
                    color: serverState.clientCount > 0 ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                    icon: Icons.settings_input_hdmi,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Accessibility Permission Warning (macOS specific check) ──
            if (!_isAccessibilityTrusted && !kIsWeb && Platform.isMacOS) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accessibility Permissions Required',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Formora requires system accessibility privileges to detect focus events and inject field values into other applications. Please enable it in System Settings > Privacy & Security > Accessibility.',
                            style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Focus Tracking Module ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OS Focus Tracking',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Monitor focused fields in other applications',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isTrackingFocus,
                        onChanged: _toggleFocusTracking,
                        activeColor: const Color(0xFF6366F1),
                        activeTrackColor: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF2E2E4A), height: 32),
                  if (_isTrackingFocus) ...[
                    if (_focusedElement != null && _focusedElement!['success'] == true) ...[
                      _buildDetailRow('Field Name / Label', _focusedElement!['name']?.toString() ?? 'None'),
                      _buildDetailRow('Element ID / Desc', _focusedElement!['id']?.toString() ?? 'None'),
                      _buildDetailRow('Class Name', _focusedElement!['className']?.toString() ?? 'None'),
                      _buildDetailRow('Control Type', _focusedElement!['controlType']?.toString() ?? 'None'),
                      _buildDetailRow('AX Role (macOS)', _focusedElement!['role']?.toString() ?? 'None'),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Click/focus an input field in another application...',
                            style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Focus tracking disabled. Enable switch to monitor.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Keystroke Test Simulator Panel ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Autofill Keystroke Test',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Safely test native keystroke simulation locally in the app',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _testInputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Click here, then click "Test Native Fill" button...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _runTestFill,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_outlined),
                    label: const Text('Test Native Fill', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Device Sync Info Card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6366F1).withOpacity(0.1), const Color(0xFF8B5CF6).withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 8),
                      Text(
                        'Device Synchronization',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To pair with your browser, open the Formora Extension and it will automatically connect on Port 19190. Signed-in state is synced instantly. Active User: ${authState.user?.fullName ?? authState.user?.email ?? "Guest"}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String status,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
