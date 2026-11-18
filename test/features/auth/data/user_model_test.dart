import 'package:demo_ai_workflow/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('LoginResponseModel.fromJson', () {
    test('parses user and tokens', () {
      final model = LoginResponseModel.fromJson(tLoginJson);

      expect(model.accessToken, 'access-123');
      expect(model.refreshToken, 'refresh-456');
      expect(model.user.toEntity(), tUser);
    });

    test('tolerates missing optional fields', () {
      final model = UserModel.fromJson(const {'id': 2, 'username': 'bob'});

      expect(model.toEntity().fullName, '');
      expect(model.toEntity().avatarUrl, isNull);
    });
  });
}
