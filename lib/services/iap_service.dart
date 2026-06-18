import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';

enum SubscriptionPlan {
  monthly,
  yearly,
}

class IAPService extends ChangeNotifier {
  static final IAPService _instance = IAPService._internal();
  static const Duration _premiumRefreshPollInterval = Duration(seconds: 2);
  static const Duration _premiumRefreshTimeout = Duration(seconds: 8);

  factory IAPService() => _instance;

  IAPService._internal();

  bool _isPremium = false;
  Offerings? _offerings;
  bool _isInitialized = false;
  String? _appUserId;

  bool get isPremium => _isPremium;
  Offerings? get offerings => _offerings;
  bool get isInitialized => _isInitialized;
  bool get hasAvailablePackages =>
      _activeOffering?.availablePackages.isNotEmpty ?? false;

  Package? get monthlyPackage {
    final offering = _activeOffering;
    if (offering == null) {
      return null;
    }

    return _resolvePackage(
      offering: offering,
      expectedProductId: AppConfig.iosMonthlyProductId,
      fallbackPackage: offering.monthly,
      expectedType: PackageType.monthly,
    );
  }

  Package? get yearlyPackage {
    final offering = _activeOffering;
    if (offering == null) {
      return null;
    }

    return _resolvePackage(
      offering: offering,
      expectedProductId: AppConfig.iosYearlyProductId,
      fallbackPackage: offering.annual,
      expectedType: PackageType.annual,
    );
  }

  String get monthlyPriceString {
    return monthlyPackage?.storeProduct.priceString ?? '';
  }

  String get yearlyPriceString {
    return yearlyPackage?.storeProduct.priceString ?? '';
  }

  Future<void> initialize([String? appUserId]) async {
    if (_isInitialized) {
      if (appUserId != null &&
          appUserId.isNotEmpty &&
          appUserId != _appUserId) {
        await setUserId(appUserId);
      }
      return;
    }

    final apiKey = AppConfig.revenueCatApiKey;
    if (apiKey.isEmpty) {
      debugPrint('IAPService: RevenueCat API key is missing.');
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey));

      if (appUserId != null && appUserId.isNotEmpty) {
        await Purchases.logIn(appUserId);
        _appUserId = appUserId;
      }

      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

      await _refreshCustomerInfo();
      await loadOfferings();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('IAPService: Failed to initialize RevenueCat: $e');
    }
  }

  Future<void> setUserId(String appUserId) async {
    if (appUserId.isEmpty) {
      return;
    }

    if (!_isInitialized) {
      await initialize(appUserId);
      return;
    }

    try {
      await Purchases.logIn(appUserId);
      _appUserId = appUserId;
      await _refreshCustomerInfo();
      await loadOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('IAPService: Failed to log in RevenueCat user: $e');
    }
  }

  Future<void> logout() async {
    if (!_isInitialized) {
      return;
    }

    try {
      await Purchases.logOut();
      _appUserId = null;
      _setPremiumStatus(false);
      notifyListeners();
    } catch (e) {
      debugPrint('IAPService: Failed to logout RevenueCat user: $e');
    }
  }

  Future<void> loadOfferings() async {
    try {
      _offerings = await Purchases.getOfferings();
      final offering = _activeOffering;
      final packageSummary = offering?.availablePackages
          .map(
            (package) =>
                '${package.identifier}:${package.storeProduct.identifier}:${package.packageType.name}',
          )
          .join(', ');
      debugPrint(
        'IAPService: Loaded offerings. '
        'offering=${offering?.identifier ?? "none"} '
        'packages=${packageSummary ?? "none"}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('IAPService: Failed to load offerings: $e');
    }
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      return _refreshCustomerInfoWithRetry();
    } catch (e) {
      debugPrint('IAPService: Failed to check subscription: $e');
      return false;
    }
  }

  Future<bool> checkPremiumStatus() async {
    return checkSubscriptionStatus();
  }

  Future<bool> hasPremiumAccess() async {
    return checkSubscriptionStatus();
  }

  Future<bool> purchase(SubscriptionPlan plan) async {
    final package = plan == SubscriptionPlan.monthly
        ? monthlyPackage
        : yearlyPackage;

    if (package == null) {
      debugPrint('IAPService: ${plan.name} package not available');
      return false;
    }

    return _purchasePackage(package);
  }

  Future<bool> purchaseSubscription({
    SubscriptionPlan? plan,
  }) async {
    return purchase(plan ?? SubscriptionPlan.monthly);
  }

  Future<bool> restore() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _setPremiumStatus(
        customerInfo.entitlements.all[AppConfig.entitlementId]?.isActive ??
            false,
      );
      notifyListeners();

      if (_isPremium) {
        return true;
      }

      return _syncAndRefreshPurchases(
        timeout: _premiumRefreshTimeout,
      );
    } catch (e) {
      debugPrint('IAPService: Failed to restore purchases: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    return restore();
  }

  String humanizeError(Object error) {
    if (error is PlatformException) {
      final errorCode = PurchasesErrorHelper.getErrorCode(error);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return 'Purchase cancelled.';
      }
      if (errorCode == PurchasesErrorCode.networkError ||
          errorCode == PurchasesErrorCode.offlineConnectionError) {
        return 'Check your connection and try again.';
      }
    }

    return 'Unable to start the purchase right now.';
  }

  Future<bool> _purchasePackage(Package package) async {
    try {
      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      _setPremiumStatus(
        result.customerInfo.entitlements.all[AppConfig.entitlementId]
                ?.isActive ??
            false,
      );
      notifyListeners();

      if (_isPremium) {
        return true;
      }

      return _syncAndRefreshPurchases(
        timeout: _premiumRefreshTimeout,
      );
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('IAPService: Purchase cancelled by user');
        return false;
      } else {
        debugPrint('IAPService: Purchase failed: $e');
      }

      final recovered = await _syncAndRefreshPurchases(
        timeout: _premiumRefreshTimeout,
      );
      if (recovered) {
        debugPrint(
          'IAPService: Recovered premium access after purchase exception via sync.',
        );
        return true;
      }

      return false;
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _applyCustomerInfo(info);
    notifyListeners();
  }

  Future<void> _refreshCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _applyCustomerInfo(customerInfo);
      notifyListeners();
    } catch (e) {
      debugPrint('IAPService: Failed to refresh customer info: $e');
    }
  }

  void _setPremiumStatus(
    bool isPremium, {
    DateTime? expirationAt,
  }) {
    _isPremium = isPremium;
  }

  Future<bool> _refreshCustomerInfoWithRetry({
    Duration timeout = _premiumRefreshTimeout,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (true) {
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        final hasAccess = _applyCustomerInfo(customerInfo);
        notifyListeners();

        if (hasAccess) {
          return true;
        }
      } catch (e) {
        debugPrint('IAPService: Failed to refresh customer info: $e');
      }

      if (DateTime.now().isAfter(deadline)) {
        return false;
      }

      await Future.delayed(_premiumRefreshPollInterval);
    }
  }

  Future<bool> _syncAndRefreshPurchases({
    Duration timeout = _premiumRefreshTimeout,
  }) async {
    try {
      await Purchases.syncPurchases();
    } catch (e) {
      debugPrint('IAPService: syncPurchases failed: $e');
    }

    try {
      await Purchases.invalidateCustomerInfoCache();
    } catch (e) {
      debugPrint('IAPService: invalidateCustomerInfoCache failed: $e');
    }

    return _refreshCustomerInfoWithRetry(timeout: timeout);
  }

  bool _applyCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[AppConfig.entitlementId];
    final expirationAt = _parseRevenueCatDate(entitlement?.expirationDate);
    final hasAccess = entitlement?.isActive ?? false;

    _setPremiumStatus(
      hasAccess,
      expirationAt: expirationAt,
    );

    return hasAccess;
  }

  DateTime? _parseRevenueCatDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
  Offering? get _activeOffering {
    final offerings = _offerings;
    if (offerings == null) {
      return null;
    }

    final preferredOffering = offerings.getOffering(AppConfig.offeringId);
    if (preferredOffering != null) {
      return preferredOffering;
    }

    return offerings.current;
  }

  Package? _resolvePackage({
    required Offering offering,
    required String expectedProductId,
    required Package? fallbackPackage,
    required PackageType expectedType,
  }) {
    final normalizedExpectedId = expectedProductId.toLowerCase();
    for (final package in offering.availablePackages) {
      if (package.storeProduct.identifier.toLowerCase() ==
              normalizedExpectedId ||
          package.identifier.toLowerCase() == normalizedExpectedId) {
        return package;
      }
    }

    if (fallbackPackage != null) {
      return fallbackPackage;
    }

    for (final package in offering.availablePackages) {
      if (package.packageType == expectedType) {
        return package;
      }
    }

    return null;
  }

  @visibleForTesting
  void debugSetOfferings(Offerings? offerings) {
    _offerings = offerings;
  }
}
