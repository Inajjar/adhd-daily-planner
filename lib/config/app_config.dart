import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _revenueCatIosKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: 'appl_wXoIRLkRqkljMJmjMXNXAbLthIS',
  );
  static const String _revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: '',
  );

  static const String entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'ADHD_Daily_Pro',
  );
  static const String offeringId = String.fromEnvironment(
    'REVENUECAT_OFFERING_ID',
    defaultValue: 'default',
  );
  static const String iosMonthlyProductId = String.fromEnvironment(
    'REVENUECAT_IOS_MONTHLY_PRODUCT_ID',
    defaultValue: 'MonthlyADHD',
  );
  static const String iosYearlyProductId = String.fromEnvironment(
    'REVENUECAT_IOS_YEARLY_PRODUCT_ID',
    defaultValue: 'yearADHD',
  );

  static String get revenueCatApiKey {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _revenueCatAndroidKey;
    }
    return _revenueCatIosKey;
  }
}
