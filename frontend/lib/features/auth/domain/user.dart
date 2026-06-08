class User {
  final String id;
  final String email;
  final String fullName;
  final String plan;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.plan,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      plan: json['plan'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'plan': plan,
    };
  }
}
