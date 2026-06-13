import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_bootstrap.dart';
import 'firebase_remote_config_keys.dart';

class FirebaseRemoteConfigService {
  FirebaseRemoteConfigService(this._bootstrap);

  final FirebaseBootstrap _bootstrap;

  static const Map<String, dynamic> _defaults = <String, dynamic>{
    FirebaseRemoteConfigKeys.bypassSubscriptionEnforcement: false,
    FirebaseRemoteConfigKeys.paywallEnabled: true,
    FirebaseRemoteConfigKeys.onboardingEnabled: true,
    FirebaseRemoteConfigKeys.aiPrioritySuggestionsEnabled: true,
    FirebaseRemoteConfigKeys.overwhelmDetectorEnabled: true,
    FirebaseRemoteConfigKeys.microStepGeneratorEnabled: true,
    FirebaseRemoteConfigKeys.dailyAiPlanEnabled: true,
    FirebaseRemoteConfigKeys.autoReschedulerEnabled: true,
    FirebaseRemoteConfigKeys.smartRemindersEnabled: true,
    FirebaseRemoteConfigKeys.energyMatchingEnabled: true,
    FirebaseRemoteConfigKeys.adhdEmergencyModeEnabled: true,
    FirebaseRemoteConfigKeys.openAiEnabled: true,
    FirebaseRemoteConfigKeys.openAiModel: 'gpt-5-mini',
    FirebaseRemoteConfigKeys.openAiReasoningModel: 'gpt-5.2',
    FirebaseRemoteConfigKeys.showAiReasonBadges: true,
    FirebaseRemoteConfigKeys.freeBrainDumpLimitPerDay: 1,
    FirebaseRemoteConfigKeys.freeRoutineLimit: 3,
    FirebaseRemoteConfigKeys.maxDailyFocusTasks: 3,
  };

  FirebaseRemoteConfig? _remoteConfig;

  FirebaseRemoteConfig get _rc {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      throw StateError(
        'FirebaseRemoteConfigService.sync() must be called first.',
      );
    }
    return remoteConfig;
  }

  bool get bypassSubscriptionEnforcement =>
      _readBool(FirebaseRemoteConfigKeys.bypassSubscriptionEnforcement);

  bool get paywallEnabled => _readBool(FirebaseRemoteConfigKeys.paywallEnabled);

  bool get onboardingEnabled =>
      _readBool(FirebaseRemoteConfigKeys.onboardingEnabled);

  bool get aiPrioritySuggestionsEnabled =>
      _readBool(FirebaseRemoteConfigKeys.aiPrioritySuggestionsEnabled);

  bool get overwhelmDetectorEnabled =>
      _readBool(FirebaseRemoteConfigKeys.overwhelmDetectorEnabled);

  bool get microStepGeneratorEnabled =>
      _readBool(FirebaseRemoteConfigKeys.microStepGeneratorEnabled);

  bool get dailyAiPlanEnabled =>
      _readBool(FirebaseRemoteConfigKeys.dailyAiPlanEnabled);

  bool get autoReschedulerEnabled =>
      _readBool(FirebaseRemoteConfigKeys.autoReschedulerEnabled);

  bool get smartRemindersEnabled =>
      _readBool(FirebaseRemoteConfigKeys.smartRemindersEnabled);

  bool get energyMatchingEnabled =>
      _readBool(FirebaseRemoteConfigKeys.energyMatchingEnabled);

  bool get adhdEmergencyModeEnabled =>
      _readBool(FirebaseRemoteConfigKeys.adhdEmergencyModeEnabled);

  bool get openAiEnabled => _readBool(FirebaseRemoteConfigKeys.openAiEnabled);

  String get openAiModel => _readString(FirebaseRemoteConfigKeys.openAiModel);

  String get openAiReasoningModel =>
      _readString(FirebaseRemoteConfigKeys.openAiReasoningModel);

  bool get showAiReasonBadges =>
      _readBool(FirebaseRemoteConfigKeys.showAiReasonBadges);

  int get freeBrainDumpLimitPerDay =>
      _readInt(FirebaseRemoteConfigKeys.freeBrainDumpLimitPerDay);

  int get freeRoutineLimit =>
      _readInt(FirebaseRemoteConfigKeys.freeRoutineLimit);

  int get maxDailyFocusTasks =>
      _readInt(FirebaseRemoteConfigKeys.maxDailyFocusTasks);

  Future<void> sync() async {
    if (!_bootstrap.isReady) {
      return;
    }

    _remoteConfig ??= FirebaseRemoteConfig.instance;

    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 1),
      ),
    );

    await _rc.setDefaults(_defaults);
    try {
      await _rc.fetchAndActivate();
    } catch (error) {
      debugPrint(
        'FirebaseRemoteConfigService: fetch failed, using defaults: $error',
      );
    }
  }

  bool _readBool(String key) {
    if (_remoteConfig == null) {
      return (_defaults[key] as bool?) ?? false;
    }
    return _rc.getBool(key);
  }

  int _readInt(String key) {
    if (_remoteConfig == null) {
      return (_defaults[key] as int?) ?? 0;
    }
    return _rc.getInt(key);
  }

  String _readString(String key) {
    if (_remoteConfig == null) {
      return (_defaults[key] as String?) ?? '';
    }
    return _rc.getString(key);
  }
}
