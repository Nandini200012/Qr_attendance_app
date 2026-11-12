import 'package:qr_attendance_app/features/authentication/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.username,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.image,
    required super.phone,
    required super.department,
    required super.jobTitle,
    required super.companyName,
    required super.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final companyMap = company is Map<String, dynamic> ? company : null;

    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? '',
      image: (json['image'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      department: (companyMap?['department'] as String?) ??
          (json['department'] as String?) ??
          'Operations',
      jobTitle: (companyMap?['title'] as String?) ??
          (json['jobTitle'] as String?) ??
          'Employee',
      companyName: (companyMap?['name'] as String?) ??
          (json['companyName'] as String?) ??
          'Smart Corp',
      role: (json['role'] as String?) ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'image': image,
        'phone': phone,
        'department': department,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'role': role,
      };
}

