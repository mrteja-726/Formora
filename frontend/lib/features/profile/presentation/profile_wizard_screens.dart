import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formora/features/profile/application/profile_notifier.dart';
import 'package:formora/features/profile/data/local_profile_repository.dart';

class ProfileWizardScreen extends ConsumerStatefulWidget {
  const ProfileWizardScreen({super.key});

  @override
  ConsumerState<ProfileWizardScreen> createState() => _ProfileWizardScreenState();
}

class _ProfileWizardScreenState extends ConsumerState<ProfileWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form keys
  final _basicFormKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();

  // Input Data
  String _profileType = 'Personal'; // Personal, Professional, Medical, Developer
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  String _gender = 'Female'; // Female, Male, Other

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  String? _avatarEmoji = '👤';
  int _colorSeed = 0xFF00478D;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1 && !_basicFormKey.currentState!.validate()) return;
    if (_currentStep == 2 && !_contactFormKey.currentState!.validate()) return;

    if (_currentStep < 5) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    // 1. Create the profile in Drift SQLite DB
    final notifier = ref.read(profileNotifierProvider.notifier);
    final profileId = await notifier.createProfile(
      name: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      avatarEmoji: _avatarEmoji ?? '👤',
      colorSeed: _colorSeed,
    );

    // 2. Save fields associated with this profile
    final repo = ref.read(profileRepositoryProvider);
    final fields = [
      {'section': 'PERSONAL', 'key': 'first_name', 'value': _firstNameController.text.trim()},
      {'section': 'PERSONAL', 'key': 'last_name', 'value': _lastNameController.text.trim()},
      {'section': 'PERSONAL', 'key': 'date_of_birth', 'value': _dobController.text.trim()},
      {'section': 'PERSONAL', 'key': 'gender', 'value': _gender},
      {'section': 'CONTACT', 'key': 'email', 'value': _emailController.text.trim()},
      {'section': 'CONTACT', 'key': 'phone', 'value': _phoneController.text.trim()},
      {'section': 'CONTACT', 'key': 'address_line1', 'value': _addressController.text.trim()},
      {'section': 'CONTACT', 'key': 'city', 'value': _cityController.text.trim()},
      {'section': 'CONTACT', 'key': 'country', 'value': _countryController.text.trim()},
    ];

    for (final field in fields) {
      if (field['value']!.isNotEmpty) {
        await repo.upsertField(
          profileId: profileId,
          section: field['section']!,
          fieldKey: field['key']!,
          value: field['value']!,
        );
      }
    }

    // 3. Navigate to Home
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        centerTitle: true,
        leading: _currentStep > 0 && _currentStep < 5
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress bar
          if (_currentStep < 5) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildProfileTypeStep(),
                _buildBasicInfoStep(),
                _buildContactInfoStep(),
                _buildDocumentSetupStep(),
                _buildReviewStep(),
                _buildSuccessStep(),
              ],
            ),
          ),

          // Bottom buttons
          if (_currentStep < 5) ...[
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(_currentStep == 4 ? 'Confirm & Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 1: Profile Type
  Widget _buildProfileTypeStep() {
    final colorScheme = Theme.of(context).colorScheme;

    Widget typeCard(String type, String desc, IconData icon, Color color) {
      final isSelected = _profileType == type;
      return GestureDetector(
        onTap: () {
          setState(() {
            _profileType = type;
            if (type == 'Personal') {
              _avatarEmoji = '👤';
              _colorSeed = 0xFF00478D;
            } else if (type == 'Professional') {
              _avatarEmoji = '💼';
              _colorSeed = 0xFF7E5361;
            } else if (type == 'Medical') {
              _avatarEmoji = '🏥';
              _colorSeed = 0xFFBA1A1A;
            } else {
              _avatarEmoji = '💻';
              _colorSeed = 0xFF565E71;
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.05) : colorScheme.surfaceContainer,
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Profile Type',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Formora organizes data using profiles. Choose one to start onboarding.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          typeCard('Personal', 'For general job applications, accounts, and details', Icons.person_outline, const Color(0xFF00478D)),
          typeCard('Professional', 'Tailored for professional credentials and resumes', Icons.work_outline, const Color(0xFF7E5361)),
          typeCard('Medical', 'Organize personal medical records and details securely', Icons.medical_services_outlined, const Color(0xFFBA1A1A)),
          typeCard('Developer', 'For code accounts, repository access tokens and keys', Icons.code_outlined, const Color(0xFF565E71)),
        ],
      ),
    );
  }

  // Step 2: Basic Info
  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _basicFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter last name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobController,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter date of birth';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
              items: const [
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'Female'),
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Contact Info
  Widget _buildContactInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _contactFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter phone number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Street Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter street address' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter city' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter country' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: Optional Document Setup
  Widget _buildDocumentSetupStep() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Verification Documents',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional: Add a passport scan, resume, or national ID. Formora can extract details from them later using on-device OCR.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 48, color: colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'Upload PDF or Image scans',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Drag and drop files here or click to browse',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Placeholder for file pick trigger
                  },
                  icon: const Icon(Icons.file_open),
                  label: const Text('Browse Files'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 5: Review Step
  Widget _buildReviewStep() {
    final colorScheme = Theme.of(context).colorScheme;

    Widget detailRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value.isNotEmpty ? value : '(Not provided)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Profile Details',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(_avatarEmoji ?? '👤', style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_firstNameController.text} ${_lastNameController.text}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            '$_profileType Profile',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                detailRow('BIRTHDATE', _dobController.text),
                detailRow('GENDER', _gender),
                detailRow('EMAIL', _emailController.text),
                detailRow('PHONE', _phoneController.text),
                detailRow('ADDRESS', '${_addressController.text}, ${_cityController.text}, ${_countryController.text}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 6: Success Step
  Widget _buildSuccessStep() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 80,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Profile Created Successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your data has been encrypted and stored in your device database. You can now use Formora to autofill forms instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _finishOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Go to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
