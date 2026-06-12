// lib/features/profile/domain/profile_field_schema.dart
//
// Defines ALL profile sections and their fields.
// This is the single source of truth for:
//   - What fields exist
//   - Their display labels
//   - Their data types
//   - Their section weights for completion calculation
//   - Which are "sensitive" (require biometric to view)

/// A single field definition in the profile schema.
class FieldDefinition {
  final String key;          // Unique within its section
  final String label;        // Human-readable label
  final String dataType;     // string | date | number | phone | email | id
  final bool required;       // Required for section completion
  final bool sensitive;      // Requires biometric to reveal
  final String? hint;        // Placeholder hint text
  final String? validationPattern; // Optional regex

  const FieldDefinition({
    required this.key,
    required this.label,
    this.dataType = 'string',
    this.required = false,
    this.sensitive = false,
    this.hint,
    this.validationPattern,
  });
}

/// One section of the profile (e.g. "Personal Info").
class SectionDefinition {
  final String key;
  final String label;
  final String emoji;
  final double weight; // Contribution to overall completion (must sum to 1.0)
  final List<FieldDefinition> fields;

  const SectionDefinition({
    required this.key,
    required this.label,
    required this.emoji,
    required this.weight,
    required this.fields,
  });

  int get totalFields => fields.length;
}

/// The complete Formora profile schema.
/// Section weights sum to exactly 1.0.
class ProfileFieldSchema {
  static const List<SectionDefinition> sections = [
    // 20% — Personal Info
    SectionDefinition(
      key: 'personal_info',
      label: 'Personal Info',
      emoji: '👤',
      weight: 0.20,
      fields: [
        FieldDefinition(key: 'firstName', label: 'First Name', required: true),
        FieldDefinition(key: 'lastName', label: 'Last Name', required: true),
        FieldDefinition(key: 'dateOfBirth', label: 'Date of Birth', dataType: 'date', required: true),
        FieldDefinition(key: 'gender', label: 'Gender'),
        FieldDefinition(key: 'nationality', label: 'Nationality'),
        FieldDefinition(key: 'phone', label: 'Phone Number', dataType: 'phone', hint: '+91 98765 43210'),
        FieldDefinition(key: 'email', label: 'Email Address', dataType: 'email'),
        FieldDefinition(key: 'bloodGroup', label: 'Blood Group'),
      ],
    ),

    // 25% — Identity Documents
    SectionDefinition(
      key: 'identity_documents',
      label: 'Identity Documents',
      emoji: '🪪',
      weight: 0.25,
      fields: [
        FieldDefinition(key: 'passportNumber', label: 'Passport Number', dataType: 'id', sensitive: true),
        FieldDefinition(key: 'passportExpiry', label: 'Passport Expiry', dataType: 'date'),
        FieldDefinition(key: 'passportCountry', label: 'Passport Country'),
        FieldDefinition(key: 'nationalIdNumber', label: 'National ID / Aadhaar', dataType: 'id', sensitive: true, hint: 'XXXX XXXX XXXX'),
        FieldDefinition(key: 'drivingLicenseNumber', label: 'Driving Licence No.', dataType: 'id', sensitive: true),
        FieldDefinition(key: 'drivingLicenseExpiry', label: 'Licence Expiry', dataType: 'date'),
        FieldDefinition(key: 'taxId', label: 'Tax ID / PAN', dataType: 'id', sensitive: true, hint: 'ABCDE1234F'),
        FieldDefinition(key: 'voterIdNumber', label: 'Voter ID', dataType: 'id', sensitive: true),
      ],
    ),

    // 10% — Address
    SectionDefinition(
      key: 'address',
      label: 'Address',
      emoji: '🏠',
      weight: 0.10,
      fields: [
        FieldDefinition(key: 'addressLine1', label: 'Address Line 1', required: true),
        FieldDefinition(key: 'addressLine2', label: 'Address Line 2'),
        FieldDefinition(key: 'city', label: 'City', required: true),
        FieldDefinition(key: 'state', label: 'State / Province', required: true),
        FieldDefinition(key: 'postalCode', label: 'Postal Code', dataType: 'number'),
        FieldDefinition(key: 'country', label: 'Country', required: true),
      ],
    ),

    // 10% — Education
    SectionDefinition(
      key: 'education',
      label: 'Education',
      emoji: '🎓',
      weight: 0.10,
      fields: [
        FieldDefinition(key: 'highestQualification', label: 'Highest Qualification'),
        FieldDefinition(key: 'institution', label: 'Institution Name'),
        FieldDefinition(key: 'degree', label: 'Degree / Programme'),
        FieldDefinition(key: 'major', label: 'Field of Study'),
        FieldDefinition(key: 'graduationYear', label: 'Graduation Year', dataType: 'number'),
        FieldDefinition(key: 'gpa', label: 'GPA / Percentage', dataType: 'number'),
      ],
    ),

    // 10% — Employment
    SectionDefinition(
      key: 'employment',
      label: 'Employment',
      emoji: '💼',
      weight: 0.10,
      fields: [
        FieldDefinition(key: 'employmentStatus', label: 'Employment Status'),
        FieldDefinition(key: 'employer', label: 'Employer / Company'),
        FieldDefinition(key: 'jobTitle', label: 'Job Title'),
        FieldDefinition(key: 'employeeId', label: 'Employee ID', sensitive: true),
        FieldDefinition(key: 'workEmail', label: 'Work Email', dataType: 'email'),
        FieldDefinition(key: 'startDate', label: 'Start Date', dataType: 'date'),
        FieldDefinition(key: 'annualIncome', label: 'Annual Income', dataType: 'number', sensitive: true),
      ],
    ),

    // 10% — Banking
    SectionDefinition(
      key: 'banking',
      label: 'Banking',
      emoji: '🏦',
      weight: 0.10,
      fields: [
        FieldDefinition(key: 'bankName', label: 'Bank Name'),
        FieldDefinition(key: 'accountNumber', label: 'Account Number', dataType: 'id', sensitive: true),
        FieldDefinition(key: 'ifscCode', label: 'IFSC / Routing Code', sensitive: true),
        FieldDefinition(key: 'swiftCode', label: 'SWIFT / BIC Code', sensitive: true),
        FieldDefinition(key: 'upiId', label: 'UPI ID', sensitive: true),
        FieldDefinition(key: 'creditScore', label: 'Credit Score', dataType: 'number'),
      ],
    ),

    // 10% — Family
    SectionDefinition(
      key: 'family',
      label: 'Family',
      emoji: '👨‍👩‍👧',
      weight: 0.10,
      fields: [
        FieldDefinition(key: 'maritalStatus', label: 'Marital Status'),
        FieldDefinition(key: 'spouseName', label: 'Spouse / Partner Name'),
        FieldDefinition(key: 'numberOfDependents', label: 'Number of Dependents', dataType: 'number'),
        FieldDefinition(key: 'fatherName', label: "Father's Name"),
        FieldDefinition(key: 'motherName', label: "Mother's Name"),
        FieldDefinition(key: 'mothersMaidenName', label: "Mother's Maiden Name", sensitive: true),
      ],
    ),

    // 5% — Emergency Contact
    SectionDefinition(
      key: 'emergency',
      label: 'Emergency Contact',
      emoji: '🆘',
      weight: 0.05,
      fields: [
        FieldDefinition(key: 'emergencyContactName', label: 'Contact Name', required: true),
        FieldDefinition(key: 'emergencyContactPhone', label: 'Contact Phone', dataType: 'phone', required: true),
        FieldDefinition(key: 'emergencyContactRelationship', label: 'Relationship'),
        FieldDefinition(key: 'emergencyContactEmail', label: 'Contact Email', dataType: 'email'),
      ],
    ),
  ];

  // ── Lookups ───────────────────────────────────────────────────────────────

  /// Total number of fields across all sections.
  static int get totalFieldCount =>
      sections.fold(0, (sum, s) => sum + s.totalFields);

  /// Section definition by key.
  static SectionDefinition? sectionByKey(String key) {
    try {
      return sections.firstWhere((s) => s.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Field definition by section + fieldKey.
  static FieldDefinition? fieldByKey(String sectionKey, String fieldKey) {
    final section = sectionByKey(sectionKey);
    if (section == null) return null;
    try {
      return section.fields.firstWhere((f) => f.key == fieldKey);
    } catch (_) {
      return null;
    }
  }

  /// Whether a field is sensitive (requires biometric to view).
  static bool isSensitive(String sectionKey, String fieldKey) {
    return fieldByKey(sectionKey, fieldKey)?.sensitive ?? false;
  }

  /// Map of section key → weight.
  static Map<String, double> get sectionWeights {
    return {for (final s in sections) s.key: s.weight};
  }
}
