import 'package:adhd_daily_planner/services/iap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/object_wrappers.dart';

void main() {
  final service = IAPService();

  tearDown(() {
    service.debugSetOfferings(null);
  });

  test(
    'resolves exact App Store product ids from available packages when current is missing',
    () {
      final offering = Offering(
        'default',
        'Default offering',
        const {},
        [
          _package(
            identifier: 'monthly_custom_package',
            productId: 'MonthlyADHD',
            title: 'Monthly Pro',
            subscriptionPeriod: 'P1M',
          ),
          _package(
            identifier: 'yearly_custom_package',
            productId: 'yearADHD',
            title: 'Yearly Pro',
            subscriptionPeriod: 'P1Y',
          ),
        ],
      );

      service.debugSetOfferings(
        Offerings(
          {
            offering.identifier: offering,
          },
        ),
      );

      expect(service.monthlyPackage?.storeProduct.identifier, 'MonthlyADHD');
      expect(service.yearlyPackage?.storeProduct.identifier, 'yearADHD');
    },
  );

  test(
    'falls back to RevenueCat monthly and annual package slots',
    () {
      final monthlyPackage = _package(
        identifier: '\$rc_monthly',
        productId: 'another_monthly_product',
        title: 'Monthly Plan',
        packageType: PackageType.monthly,
      );
      final yearlyPackage = _package(
        identifier: '\$rc_annual',
        productId: 'another_yearly_product',
        title: 'Yearly Plan',
        packageType: PackageType.annual,
      );
      final offering = Offering(
        'paywall',
        'Paywall offering',
        const {},
        [
          monthlyPackage,
          yearlyPackage,
        ],
        monthly: monthlyPackage,
        annual: yearlyPackage,
      );

      service.debugSetOfferings(
        Offerings(
          {
            offering.identifier: offering,
          },
          current: offering,
        ),
      );

      expect(service.monthlyPackage?.identifier, '\$rc_monthly');
      expect(service.yearlyPackage?.identifier, '\$rc_annual');
    },
  );
}

Package _package({
  required String identifier,
  required String productId,
  required String title,
  PackageType packageType = PackageType.custom,
  String? subscriptionPeriod,
}) {
  return Package(
    identifier,
    packageType,
    StoreProduct(
      productId,
      '$title description',
      title,
      9.99,
      '\$9.99',
      'USD',
      subscriptionPeriod: subscriptionPeriod,
    ),
    const PresentedOfferingContext(
      'default',
      null,
      null,
    ),
  );
}
