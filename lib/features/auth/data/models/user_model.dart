import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';

/// DTO for DummyJSON `/auth/login` and `/auth/me` responses.
class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.image,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as int,
    username: json['username'] as String,
    email: json['email'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    image: json['image'] as String?,
  );

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? image;

  User toEntity() => User(
    id: id,
    username: username,
    email: email,
    firstName: firstName,
    lastName: lastName,
    avatarUrl: image,
  );
}

class LoginResponseModel {
  const LoginResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      LoginResponseModel(
        user: UserModel.fromJson(json),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final UserModel user;
  final String accessToken;
  final String refreshToken;
}
