import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/features/profile/presentation/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Fetch profile on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).fetchProfile();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final score = profileState.completeness?['score'] as int? ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
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
      body: profileState.isLoading && profileState.profile == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
    final initialValue = ref.read(profileProvider).decryptedValues[widget.fieldKey] ?? '';
    _controller = TextEditingController(text: initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final success = await ref.read(profileProvider.notifier).saveField(
          section: widget.section,
          fieldKey: widget.fieldKey,
          value: _controller.text,
        );
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.label} saved!'),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileProvider, (prev, next) {
      final val = next.decryptedValues[widget.fieldKey] ?? '';
      if (val != _controller.text && !_isEditing) {
        _controller.text = val;
      }
    });

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
                  onPressed: _isSaving ? null : _save,
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
