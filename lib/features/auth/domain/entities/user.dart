import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  String get fullName => '$firstName $lastName'.trim();

  @override
  List<Object?> get props => [
    id,
    username,
    email,
    firstName,
    lastName,
    avatarUrl,
  ];
}
