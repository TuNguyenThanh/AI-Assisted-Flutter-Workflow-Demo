import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';

const tUser = User(
  id: 1,
  username: 'emilys',
  email: 'emily.johnson@x.dummyjson.com',
  firstName: 'Emily',
  lastName: 'Johnson',
  avatarUrl: 'https://dummyjson.com/icon/emilys/128',
);

const tLoginJson = <String, dynamic>{
  'id': 1,
  'username': 'emilys',
  'email': 'emily.johnson@x.dummyjson.com',
  'firstName': 'Emily',
  'lastName': 'Johnson',
  'image': 'https://dummyjson.com/icon/emilys/128',
  'accessToken': 'access-123',
  'refreshToken': 'refresh-456',
};
