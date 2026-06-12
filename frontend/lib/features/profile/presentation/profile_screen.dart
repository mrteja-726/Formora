import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/profile/application/completion_notifier.dart';
import 'package:formora/features/profile/data/local_profile_repository.dart';
import 'package:formora/features/profile/domain/profile_entities.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isProSimulated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showUpgradeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2E4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upgrade to Formora Pro',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '\$9.99/mo',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFeatureRow(Icons.bolt, 'Unlimited Autofills', 'No limits or restrictions on any web forms'),
              _buildFeatureRow(Icons.psychology, 'Advanced AI Mapping', 'Powered by priority GPT-4o mapping engine'),
              _buildFeatureRow(Icons.cloud_done, '1GB Vault Storage', 'Encrypted document parsing & templates'),
              _buildFeatureRow(Icons.settings_suggest, 'Custom Rules', 'Configure custom alias mapping rules per domain'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showCheckoutSheet();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Subscribe Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const _CheckoutSheetBody(),
        );
      },
    ).then((success) {
      if (success == true) {
        setState(() {
          _isProSimulated = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeProfileAsync = ref.watch(activeProfileProvider);

    return activeProfileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F1A),
            body: Center(
              child: Text(
                'No active profile found. Please create one.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final completionAsync = ref.watch(activeProfileCompletionProvider);
        final score = completionAsync.value?.overallRounded ?? 0;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          appBar: AppBar(
            title: Text(profile.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF1A1A2E),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.privacy_tip_outlined, color: Colors.white),
                tooltip: 'Privacy & GDPR Settings',
                onPressed: () => _showSettingsSheet(context, profile),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF6366F1),
              tabs: const [
                Tab(text: 'Personal'),
                Tab(text: 'Contact'),
                Tab(text: 'Employment'),
                Tab(text: 'Education'),
                Tab(text: 'Medical'),
              ],
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Completeness Header ──
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF16162A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile Completeness',
                          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '$score%',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: const Color(0xFF0F0F1A),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Onboarding Import Card ──
              if (score < 100) ...[
                _buildOnboardingImportCard(context, profile),
              ],

              // ── Dynamic Upgrade / Pro Banner ──
              if (!_isProSimulated) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF6366F1).withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.1)],
                    ),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFF2E2E4A), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_outline, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Formora Pro Plan Available',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Get unlimited fills and advanced AI rules for \$9.99/mo.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _showUpgradeSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Upgrade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.05),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFF22C55E), width: 1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pro Plan Active',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Unlimited autofills and priority AI engine features unlocked.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Tabs Contents ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // PERSONAL
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        ProfileFieldWidget(section: 'PERSONAL', fieldKey: 'first_name', label: 'FIRST NAME', hint: 'Jane'),
                        ProfileFieldWidget(section: 'PERSONAL', fieldKey: 'last_name', label: 'LAST NAME', hint: 'Doe'),
                        ProfileFieldWidget(section: 'PERSONAL', fieldKey: 'date_of_birth', label: 'DATE OF BIRTH', hint: 'YYYY-MM-DD'),
                        ProfileFieldWidget(section: 'PERSONAL', fieldKey: 'gender', label: 'GENDER', hint: 'Female / Male / Other'),
                      ],
                    ),
                    // CONTACT
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        ProfileFieldWidget(section: 'CONTACT', fieldKey: 'email', label: 'EMAIL ADDRESS', hint: 'jane@example.com'),
                        ProfileFieldWidget(section: 'CONTACT', fieldKey: 'phone', label: 'PHONE NUMBER', hint: '+1 555-0199'),
                        ProfileFieldWidget(section: 'CONTACT', fieldKey: 'address_line1', label: 'ADDRESS LINE 1', hint: '123 Main St'),
                        ProfileFieldWidget(section: 'CONTACT', fieldKey: 'city', label: 'CITY', hint: 'San Francisco'),
                        ProfileFieldWidget(section: 'CONTACT', fieldKey: 'country', label: 'COUNTRY', hint: 'United States'),
                      ],
                    ),
                    // EMPLOYMENT
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        ProfileFieldWidget(section: 'EMPLOYMENT', fieldKey: 'current_job_title', label: 'JOB TITLE', hint: 'Software Engineer'),
                        ProfileFieldWidget(section: 'EMPLOYMENT', fieldKey: 'employer', label: 'EMPLOYER', hint: 'Acme Corp'),
                        ProfileFieldWidget(section: 'EMPLOYMENT', fieldKey: 'years_experience', label: 'YEARS OF EXPERIENCE', hint: '5'),
                      ],
                    ),
                    // EDUCATION
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        ProfileFieldWidget(section: 'EDUCATION', fieldKey: 'highest_degree', label: 'HIGHEST DEGREE', hint: "Bachelor's / Master's"),
                        ProfileFieldWidget(section: 'EDUCATION', fieldKey: 'institution', label: 'INSTITUTION', hint: 'Stanford University'),
                        ProfileFieldWidget(section: 'EDUCATION', fieldKey: 'graduation_year', label: 'GRADUATION YEAR', hint: '2020'),
                      ],
                    ),
                    // MEDICAL
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        ProfileFieldWidget(section: 'MEDICAL', fieldKey: 'blood_type', label: 'BLOOD TYPE', hint: 'O+ / A-'),
                        ProfileFieldWidget(section: 'MEDICAL', fieldKey: 'allergies', label: 'ALLERGIES', hint: 'Peanuts / Penicillin'),
                        ProfileFieldWidget(section: 'MEDICAL', fieldKey: 'emergency_contact', label: 'EMERGENCY CONTACT', hint: 'John Doe - 555-0100'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, Profile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E2E4A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: Color(0xFF6366F1)),
                      SizedBox(width: 12),
                      Text(
                        'Privacy & GDPR Settings',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Data Export Card
                  _buildSettingsCard(
                    icon: Icons.download_outlined,
                    title: 'Export Profile Data',
                    desc: 'Download your full decrypted profile in JSON format (Right to Portability).',
                    actionLabel: 'Export JSON',
                    actionColor: const Color(0xFF6366F1),
                    onAction: () => _handleDataExport(context, ref, profile),
                  ),

                  const SizedBox(height: 16),

                  // Account Deletion Card
                  _buildSettingsCard(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete Profile',
                    desc: 'Permanently purge this profile and all its encrypted fields (Right to Be Forgotten).',
                    actionLabel: 'Delete Permanently',
                    actionColor: const Color(0xFFEF4444),
                    onAction: () => _confirmAccountDeletion(context, ref, profile),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String desc,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E4A).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDataExport(BuildContext context, WidgetRef ref, Profile profile) async {
    Navigator.pop(context); // close bottom sheet
    
    // Show spinner dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1))),
      ),
    );

    try {
      final repository = ref.read(profileRepositoryProvider);
      final rawData = await repository.exportProfileToJson(profile.id);
      
      if (!context.mounted) return;
      Navigator.pop(context); // close spinner

      // Pretty print JSON
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(rawData);

      // Try to save to local downloads directory
      Directory? dir;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final filePath = '${dir.path}/formora_profile_${profile.name.replaceAll(RegExp(r'\s+'), '_')}_export.json';
      final file = File(filePath);
      await file.writeAsString(prettyJson);

      // Also copy to clipboard as backup
      await Clipboard.setData(ClipboardData(text: prettyJson));

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
                SizedBox(width: 12),
                Text('Export Complete', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your profile data has been exported successfully.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SAVED FILE:',
                        style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        filePath,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Courier'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '💡 Note: The JSON content has also been copied to your clipboard.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close spinner if active
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _confirmAccountDeletion(BuildContext context, WidgetRef ref, Profile profile) async {
    Navigator.pop(context); // close bottom sheet
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete Profile?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete profile "${profile.name}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This action is irreversible. All of this profile\'s encrypted fields and credentials will be permanently purged.',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Yes, Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Show spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFEF4444))),
        ),
      );

      try {
        await ref.read(profileNotifierProvider.notifier).deleteProfile(profile.id);
        if (context.mounted) {
          Navigator.pop(context); // close spinner
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile deleted successfully.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // close spinner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete profile: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Widget _buildOnboardingImportCard(BuildContext context, Profile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6366F1).withOpacity(0.15), const Color(0xFF8B5CF6).withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flash_on, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Fill Onboarding',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Upload a document in the Document Vault to automatically map your profile fields.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileFieldWidget extends ConsumerStatefulWidget {
  final String section;
  final String fieldKey;
  final String label;
  final String hint;

  const ProfileFieldWidget({
    super.key,
    required this.section,
    required this.fieldKey,
    required this.label,
    required this.hint,
  });

  @override
  ConsumerState<ProfileFieldWidget> createState() => _ProfileFieldWidgetState();
}

class _ProfileFieldWidgetState extends ConsumerState<ProfileFieldWidget> {
  late final TextEditingController _controller;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String activeProfileId) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileNotifierProvider.notifier).updateField(
            profileId: activeProfileId,
            section: widget.section,
            fieldKey: widget.fieldKey,
            value: _controller.text,
          );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.label} saved!'),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save field: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider).value;
    if (activeProfile == null) return const SizedBox.shrink();

    final fieldsAsync = ref.watch(profileFieldsProvider(activeProfile.id));
    final fieldVal = fieldsAsync.when(
      data: (fields) {
        final f = fields.firstWhere(
          (f) => f.fieldKey == widget.fieldKey && f.section == widget.section,
          orElse: () => ProfileField(
            id: '',
            profileId: activeProfile.id,
            section: widget.section,
            fieldKey: widget.fieldKey,
            value: '',
            updatedAt: DateTime.now(),
          ),
        );
        return f.value;
      },
      loading: () => '',
      error: (_, __) => '',
    );

    if (!_isEditing && _controller.text != fieldVal) {
      _controller.text = fieldVal;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  onChanged: (val) {
                    if (!_isEditing) setState(() => _isEditing = true);
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
                    filled: true,
                    fillColor: const Color(0xFF16162A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSaving ? null : () => _save(activeProfile.id),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, color: Color(0xFF22C55E)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF16162A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutSheetBody extends StatefulWidget {
  const _CheckoutSheetBody();

  @override
  State<_CheckoutSheetBody> createState() => _CheckoutSheetBodyState();
}

class _CheckoutSheetBodyState extends State<_CheckoutSheetBody> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isPaying = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isPaying = true;
      });

      // Simulate Stripe loading payment
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isPaying = false;
          _isSuccess = true;
        });
        // Auto close after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 80),
            SizedBox(height: 24),
            Text(
              'Upgrade Successful!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Welcome to Formora Pro.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stripe Checkout',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.payment, color: Colors.white),
              ],
            ),
            const Divider(color: Color(0xFF2E2E4A), height: 32),
            
            // Name field
            const Text('CARDHOLDER NAME', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Jane Doe'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Card Number field
            const Text('CARD NUMBER', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('4242 4242 4242 4242'),
              validator: (v) => v == null || v.length < 16 ? 'Invalid Card Number' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EXPIRY', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _expiryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('MM/YY'),
                        validator: (v) => v == null || v.length < 5 ? 'Invalid Expiry' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CVV', style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cvvController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('123'),
                        validator: (v) => v == null || v.length < 3 ? 'Invalid CVV' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isPaying ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isPaying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Text('Pay \$9.99', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
      filled: true,
      fillColor: const Color(0xFF0F0F1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
