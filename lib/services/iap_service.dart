import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

enum SubscriptionPlan {
  monthly,
  yearly,
}

class IAPService extends ChangeNotifier {
  static final IAPService _instance = IAPService._internal();
  static const Duration _premiumRefreshPollInterval = Duration(seconds: 2);
  static const Duration _premiumRefreshTimeout = Duration(seconds: 8);
  static const Duration _recentPremiumGracePeriod = Duration(minutes: 3);
  static const Duration _cachedPremiumOfflineGracePeriod = Duration(days: 14);
  static const Duration _expirationGracePeriod = Duration(hours: 12);
  static const String _cachedPremiumActiveKey = 'iap_cached_premium_active';
  static const String _cachedPremiumExpirationKey =
      'iap_cached_premium_expiration';
  static const String _lastPremiumConfirmedAtKey =
      'iap_last_premium_confirmed_at';

  factory IAPService() => _instance;

  IAPService._internal();

  bool _isPremium = false;
  Offerings? _offerings;
  bool _isInitialized = false;
  bool _hasLoadedCachedState = false;
  String? _appUserId;
  DateTime? _lastPremiumConfirmedAt;
  bool _cachedPremiumActive = false;
  DateTime? _cachedPremiumExpirationAt;

  bool get isPremium => _isPremium;
  Offerings? get offerings => _offerings;
  bool get isInitialized => _isInitialized;
  bool get hasAvailablePackages =>
      _activeOffering?.availablePackages.isNotEmpty ?? false;

  bool get hasRecentPremiumConfirmation {
    if (_isPremium) {
      return true;
    }

    final lastPremiumConfirmedAt = _lastPremiumConfirmedAt;
    if (lastPremiumConfirmedAt == null) {
      return false;
    }

    return DateTime.now().difference(lastPremiumConfirmedAt) <=
        _recentPremiumGracePeriod;
  }

  bool get hasCachedPremiumAccess {
    if (_isPremium) {
      return true;
    }
    if (!_cachedPremiumActive) {
      return false;
    }

    final now = DateTime.now();
    final cachedPremiumExpirationAt = _cachedPremiumExpirationAt;
    if (cachedPremiumExpirationAt != null) {
      return now.isBefore(
        cachedPremiumExpirationAt.add(_expirationGracePeriod),
      );
    }

    final lastPremiumConfirmedAt = _lastPremiumConfirmedAt;
    if (lastPremiumConfirmedAt == null) {
      return false;
    }

    return now.difference(lastPremiumConfirmedAt) <=
        _cachedPremiumOfflineGracePeriod;
  }

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
    await _loadCachedState();

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
      _setPremiumStatus(false, persist: true);
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
      final isPremium = await _refreshCustomerInfoWithRetry();
      if (isPremium) {
        return true;
      }

      if (hasCachedPremiumAccess) {
        debugPrint(
          'IAPService: Using cached premium access while RevenueCat settles.',
        );
        return true;
      }

      if (hasRecentPremiumConfirmation) {
        debugPrint(
          'IAPService: Using recent premium confirmation while App Store status settles.',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('IAPService: Failed to check subscription: $e');
      return hasRecentPremiumConfirmation || hasCachedPremiumAccess;
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
      return hasRecentPremiumConfirmation;
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
      _markRecentPurchaseConfirmation();
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

      return hasRecentPremiumConfirmation || hasCachedPremiumAccess;
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
    bool persist = false,
  }) {
    _isPremium = isPremium;
    _cachedPremiumActive = isPremium;
    _cachedPremiumExpirationAt = expirationAt;

    if (isPremium) {
      _lastPremiumConfirmedAt = DateTime.now();
    }

    if (persist) {
      _persistCachedState();
    }
  }

  void _markRecentPurchaseConfirmation() {
    _cachedPremiumActive = true;
    _lastPremiumConfirmedAt = DateTime.now();
    _persistCachedState();
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
        return hasRecentPremiumConfirmation;
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
    final expirationAt = _parseRevenueCatDate(
      entitlement?.expirationDate ?? customerInfo.latestExpirationDate,
    );
    final hasEntitlementAccess = entitlement?.isActive ?? false;
    final hasStoreLevelActiveSubscription =
        customerInfo.activeSubscriptions.isNotEmpty;
    final isWithinExpirationGrace = expirationAt != null &&
        DateTime.now().isBefore(expirationAt.add(_expirationGracePeriod));
    final hasAccess = hasEntitlementAccess ||
        hasStoreLevelActiveSubscription ||
        isWithinExpirationGrace;

    _setPremiumStatus(
      hasAccess,
      expirationAt: expirationAt,
      persist: true,
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

  Future<void> _loadCachedState() async {
    if (_hasLoadedCachedState) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedPremiumActive = prefs.getBool(_cachedPremiumActiveKey) ?? false;

    final expirationValue = prefs.getString(_cachedPremiumExpirationKey);
    _cachedPremiumExpirationAt = _parseRevenueCatDate(expirationValue);

    final lastConfirmedValue = prefs.getString(_lastPremiumConfirmedAtKey);
    _lastPremiumConfirmedAt = _parseRevenueCatDate(lastConfirmedValue);
    _isPremium = hasCachedPremiumAccess;
    _hasLoadedCachedState = true;
  }

  Future<void> _persistCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cachedPremiumActiveKey, _cachedPremiumActive);

    final cachedPremiumExpirationAt = _cachedPremiumExpirationAt;
    if (cachedPremiumExpirationAt != null) {
      await prefs.setString(
        _cachedPremiumExpirationKey,
        cachedPremiumExpirationAt.toUtc().toIso8601String(),
      );
    } else {
      await prefs.remove(_cachedPremiumExpirationKey);
    }

    final lastPremiumConfirmedAt = _lastPremiumConfirmedAt;
    if (lastPremiumConfirmedAt != null) {
      await prefs.setString(
        _lastPremiumConfirmedAtKey,
        lastPremiumConfirmedAt.toUtc().toIso8601String(),
      );
    } else {
      await prefs.remove(_lastPremiumConfirmedAtKey);
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
