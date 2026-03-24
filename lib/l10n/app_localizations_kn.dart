// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kannada (`kn`).
class AppLocalizationsKn extends AppLocalizations {
  AppLocalizationsKn([String locale = 'kn']) : super(locale);

  @override
  String get appTitle => 'ಫಾರ್ಮ್‌ಗಾರ್ಡ್ AI';

  @override
  String get selectLanguage => 'ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ';

  @override
  String get continueBtn => 'ಮುಂದುವರಿಸಿ';

  @override
  String get loginTitle => 'ಮರಳಿ ಸುಸ್ವಾಗತ';

  @override
  String get loginSubtitle => 'ನಿಮ್ಮ ಫಾರ್ಮ್ ಅನ್ನು ರಕ್ಷಿಸಲು ಲಾಗಿನ್ ಮಾಡಿ';

  @override
  String get phoneNumber => 'ದೂರವಾಣಿ ಸಂಖ್ಯೆ';

  @override
  String get email => 'ಇಮೇಲ್ ವಿಳಾಸ';

  @override
  String get loginBtn => 'ಲಾಗಿನ್';

  @override
  String get signupTitle => 'ಖಾತೆಯನ್ನು ರಚಿಸಿ';

  @override
  String get name => 'ಪೂರ್ಣ ಹೆಸರು';

  @override
  String get farmLocation => 'ಫಾರ್ಮ್ ಸ್ಥಳ';

  @override
  String get signupBtn => 'ಸೈನ್ ಅಪ್';

  @override
  String get dashboardTitle => 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್';

  @override
  String get cameraStatus => 'ಕ್ಯಾಮೆರಾ ಸ್ಥಿತಿ';

  @override
  String get active => 'ಸಕ್ರಿಯ';

  @override
  String get inactive => 'ನಿಷ್ಕ್ರಿಯ';

  @override
  String get detectionsToday => 'ಇಂದಿನ ಪತ್ತೆಗಳು';

  @override
  String get lastDetected => 'ಕೊನೆಯ ಈವೆಂಟ್';

  @override
  String get startMonitoring => 'ಫಾರ್ಮ್ ಮಾನಿಟರಿಂಗ್ ಪ್ರಾರಂಭಿಸಿ';

  @override
  String get stopMonitoring => 'ಮಾನಿಟರಿಂಗ್ ನಿಲ್ಲಿಸಿ';

  @override
  String get demoMode => 'ಡೆಮೊ ಮೋಡ್';

  @override
  String get alertHistory => 'ಎಚ್ಚರಿಕೆ ಇತಿಹಾಸ';

  @override
  String get noAlerts => 'ಇನ್ನೂ ಯಾವುದೇ ಎಚ್ಚರಿಕೆಗಳನ್ನು ದಾಖಲಿಸಲಾಗಿಲ್ಲ.';

  @override
  String alertMessage(String object) {
    return 'ಎಚ್ಚರಿಕೆ! ನಿಮ್ಮ ಫಾರ್ಮ್‌ ಒಳಗೆ $object ಬಂದಿದೆ.';
  }

  @override
  String get objHuman => 'ಮಾನವ';

  @override
  String get objCow => 'ಹಸು';

  @override
  String get objDog => 'ನಾಯಿ';

  @override
  String get objGoat => 'ಮೇಕೆ';

  @override
  String get objWildAnimal => 'ಕಾಡು ಪ್ರಾಣಿ';

  @override
  String get objVehicle => 'ವಾಹನ';

  @override
  String get theftProbability => 'ಕಳ್ಳತನದ ಸಂಭವನೀಯತೆ';

  @override
  String get suspiciousActivity => 'ಸಂಶಯಾಸ್ಪದ ಚಟುವಟಿಕೆ';
}
