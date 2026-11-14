// Core API configuration constants
import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  /// Default API port for Suniti backend (Express defaults to 5000 in server.js)
  static const int defaultPort = 5000;

  /// Default local development base URL.
  /// Note for Android Emulator:
  /// Android emulators cannot use `localhost` or `127.0.0.1` to access host machine services;
  /// instead, use `http://10.0.2.2:5000`.
  /// For physical Android devices connected via USB/Wi-Fi, use your PC's LAN IP (e.g., http://192.168.1.X:5000).
  static const String emulatorBaseUrl = 'http://10.0.2.2:5000';
  static const String localHostBaseUrl = 'http://localhost:5000';

  /// Active default base URL (can be updated at runtime via ApiClient.setBaseUrl
  /// or specified at build time using --dart-define=API_BASE_URL=...)
  static final String defaultBaseUrl =
      const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : (kIsWeb || defaultTargetPlatform == TargetPlatform.windows
            ? localHostBaseUrl
            : emulatorBaseUrl);

  /// Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  /// Secure Storage Keys
  static const String tokenStorageKey = 'suniti_jwt_auth_token';
  static const String userStorageKey = 'suniti_current_employee';
}
