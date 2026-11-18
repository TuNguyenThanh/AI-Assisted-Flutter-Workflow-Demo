import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:demo_ai_workflow/core/storage/token_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockFlutterSecureStorage secure;
  late SecureTokenStorage storage;

  setUp(() {
    secure = MockFlutterSecureStorage();
    storage = SecureTokenStorage(secure);
  });

  PlatformException platformError() =>
      PlatformException(code: 'KeystoreError', message: 'boom');

  void stubWrite() => when(
    () => secure.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((_) async {});

  void stubDelete() => when(
    () => secure.delete(key: any(named: 'key')),
  ).thenAnswer((_) async {});

  test('AC-1: saves and reads tokens under the expected keys', () async {
    stubWrite();
    when(
      () => secure.read(key: 'access_token'),
    ).thenAnswer((_) async => 'a1');
    when(
      () => secure.read(key: 'refresh_token'),
    ).thenAnswer((_) async => 'r1');

    await storage.saveTokens(accessToken: 'a1', refreshToken: 'r1');

    verify(() => secure.write(key: 'access_token', value: 'a1')).called(1);
    verify(() => secure.write(key: 'refresh_token', value: 'r1')).called(1);
    expect(await storage.readAccessToken(), 'a1');
    expect(await storage.readRefreshToken(), 'r1');
  });

  test('regression: clear deletes both token keys', () async {
    stubDelete();

    await storage.clear();

    verify(() => secure.delete(key: 'access_token')).called(1);
    verify(() => secure.delete(key: 'refresh_token')).called(1);
  });

  test('regression: read returns null when nothing is stored', () async {
    when(
      () => secure.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);

    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('regression: readAccessToken maps PlatformException to '
      'StorageException', () async {
    when(() => secure.read(key: any(named: 'key'))).thenThrow(platformError());

    await expectLater(
      storage.readAccessToken(),
      throwsA(isA<StorageException>()),
    );
  });

  test('regression: readRefreshToken maps PlatformException to '
      'StorageException', () async {
    when(() => secure.read(key: any(named: 'key'))).thenThrow(platformError());

    await expectLater(
      storage.readRefreshToken(),
      throwsA(isA<StorageException>()),
    );
  });

  test('regression: saveTokens maps PlatformException to '
      'StorageException', () async {
    when(
      () => secure.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(platformError());

    await expectLater(
      storage.saveTokens(accessToken: 'a', refreshToken: 'r'),
      throwsA(isA<StorageException>()),
    );
  });

  test(
    'regression: clear maps PlatformException to StorageException',
    () async {
      when(
        () => secure.delete(key: any(named: 'key')),
      ).thenThrow(platformError());

      await expectLater(storage.clear(), throwsA(isA<StorageException>()));
    },
  );
}
