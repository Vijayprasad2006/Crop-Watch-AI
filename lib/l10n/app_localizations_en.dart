// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FarmGuard AI';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get continueBtn => 'Continue';

  @override
  String get loginTitle => 'Welcome Back';

  @override
  String get loginSubtitle => 'Login to protect your farm';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get email => 'Email Address';

  @override
  String get loginBtn => 'Login';

  @override
  String get signupTitle => 'Create Account';

  @override
  String get name => 'Full Name';

  @override
  String get farmLocation => 'Farm Location';

  @override
  String get signupBtn => 'Sign Up';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get cameraStatus => 'Camera Status';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get detectionsToday => 'Detections Today';

  @override
  String get lastDetected => 'Last Detected Event';

  @override
  String get startMonitoring => 'Start Farm Monitoring';

  @override
  String get stopMonitoring => 'Stop Monitoring';

  @override
  String get demoMode => 'Demo Mode';

  @override
  String get alertHistory => 'Alert History';

  @override
  String get noAlerts => 'No alerts recorded yet.';

  @override
  String alertMessage(String object) {
    return 'Alert! A $object has entered your farm.';
  }

  @override
  String get objHuman => 'Human';

  @override
  String get objCow => 'Cow';

  @override
  String get objDog => 'Dog';

  @override
  String get objGoat => 'Goat';

  @override
  String get objWildAnimal => 'Wild Animal';

  @override
  String get objVehicle => 'Vehicle';

  @override
  String get theftProbability => 'Theft Probability';

  @override
  String get suspiciousActivity => 'Suspicious Activity';
}
