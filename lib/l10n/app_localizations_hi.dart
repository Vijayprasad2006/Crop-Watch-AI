// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'फार्मगार्ड एआई';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get continueBtn => 'आगे बढ़ें';

  @override
  String get loginTitle => 'वापसी पर स्वागत है';

  @override
  String get loginSubtitle => 'अपने खेत की सुरक्षा के लिए लॉग इन करें';

  @override
  String get phoneNumber => 'फ़ोन नंबर';

  @override
  String get email => 'ईमेल पता';

  @override
  String get loginBtn => 'लॉग इन करें';

  @override
  String get signupTitle => 'खाता बनाएं';

  @override
  String get name => 'पूरा नाम';

  @override
  String get farmLocation => 'खेत का स्थान';

  @override
  String get signupBtn => 'साइन अप करें';

  @override
  String get dashboardTitle => 'डैशबोर्ड';

  @override
  String get cameraStatus => 'कैमरा स्थिति';

  @override
  String get active => 'सक्रिय';

  @override
  String get inactive => 'निष्क्रिय';

  @override
  String get detectionsToday => 'आज की पहचान';

  @override
  String get lastDetected => 'अंतिम पता चला घटना';

  @override
  String get startMonitoring => 'खेत की निगरानी शुरू करें';

  @override
  String get stopMonitoring => 'निगरानी बंद करें';

  @override
  String get demoMode => 'डेमो मोड';

  @override
  String get alertHistory => 'अलर्ट इतिहास';

  @override
  String get noAlerts => 'अभी तक कोई अलर्ट दर्ज नहीं किया गया है।';

  @override
  String alertMessage(String object) {
    return 'अलर्ट! एक $object आपके खेत में घुस आया है।';
  }

  @override
  String get objHuman => 'इंसान';

  @override
  String get objCow => 'गाय';

  @override
  String get objDog => 'कुत्ता';

  @override
  String get objGoat => 'बकरी';

  @override
  String get objWildAnimal => 'जंगली जानवर';

  @override
  String get objVehicle => 'वाहन';

  @override
  String get theftProbability => 'चोरी की संभावना';

  @override
  String get suspiciousActivity => 'संदिग्ध गतिविधि';
}
