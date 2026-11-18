/// Base URL is injected at build time so each flavor can point to its own
/// backend: `flutter run --dart-define=API_BASE_URL=https://staging.example`.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dummyjson.com',
  );
  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 15);
}
