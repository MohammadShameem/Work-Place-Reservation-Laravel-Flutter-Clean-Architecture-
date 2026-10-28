import 'package:flutter/foundation.dart';

/// Where the Laravel API lives for each platform this app runs on.
///
/// `php artisan serve` listens on 127.0.0.1:8000, which means something
/// different depending on who is asking:
///  - Flutter Web: the browser talks to the same machine, so 127.0.0.1 works.
///  - Windows/desktop: same machine too, 127.0.0.1 works.
///  - Android emulator: 127.0.0.1 points at the emulator itself, not your PC.
///    The emulator's special alias for "the host machine" is 10.0.2.2.
///  - iOS simulator: shares the host's network, 127.0.0.1 works.
///  - A real phone on the same Wi-Fi: none of the above reach your PC. Pass
///    your PC's LAN IP instead, e.g.:
///      flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000/api
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }
}
