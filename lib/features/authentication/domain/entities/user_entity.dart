import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.image,
    required this.phone,
    required this.department,
    required this.jobTitle,
    required this.companyName,
    required this.role,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String image;
  final String phone;
  final String department;
  final String jobTitle;
  final String companyName;
  final String role;

  String get fullName => '$firstName $lastName'.trim();
  String get employeeCode => 'EMP-${id.toString().padLeft(3, '0')}';
  bool get isAdmin => role.toLowerCase() == 'admin';

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        firstName,
        lastName,
        image,
        phone,
        department,
        jobTitle,
        companyName,
        role,
      ];
}

