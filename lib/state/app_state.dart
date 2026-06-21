import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/premium_ai_service.dart';
import '../app/premium_feature_flags.dart';
import '../firebase/auth/firebase_auth_service.dart';
import '../firebase/core/firebase_bootstrap.dart';
import '../firebase/firestore/firebase_firestore_models.dart';
import '../firebase/firestore/firebase_firestore_service.dart';
import '../firebase/remote_config/firebase_remote_config_service.dart';
import '../models/focus_session_item.dart';
import '../models/planning_insight.dart';
import '../models/routine_item.dart';
import '../models/task_item.dart';
import '../services/iap_service.dart';
import '../services/premium_access_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required FirebaseBootstrap firebaseBootstrap,
    required IAPService iapService,
  }) : _firebaseBootstrap = firebaseBootstrap,
       _iapService = iapService,
       _authService = FirebaseAuthService(firebaseBootstrap),
       _firestoreService = FirebaseFirestoreService(firebaseBootstrap),
       _remoteConfigService = FirebaseRemoteConfigService(firebaseBootstrap) {
    _iapService.addListener(_handleIapChanged);
  }

  final FirebaseBootstrap _firebaseBootstrap;
  final IAPService _iapService;
  final PremiumAccessService _premiumAccessService = PremiumAccessService();
  final FirebaseAuthService _authService;
  final FirebaseFirestoreService _firestoreService;
  final FirebaseRemoteConfigService _remoteConfigService;

  PremiumAiService? get _premiumAiServiceOrNull =>
      _firebaseBootstrap.isReady ? PremiumAiService() : null;

  final List<TaskItem> _todayTasks = <TaskItem>[
    TaskItem(id: '1', title: 'Take meds', durationMinutes: 5),
    TaskItem(id: '2', title: 'Plan top 3 priorities', durationMinutes: 10),
    TaskItem(id: '3', title: 'Reply to one message', durationMinutes: 15),
  ];

  final List<RoutineItem> _routines = <RoutineItem>[
    RoutineItem(
      id: 'routine-1',
      title: 'Morning Reset',
      tasks: <String>['Drink water', 'Take meds', 'Review today'],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    RoutineItem(
      id: 'routine-2',
      title: 'Work Launch',
      tasks: <String>['Open calendar', 'Pick first task', 'Start 15 min focus'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<FocusSessionItem> _focusSessions = <FocusSessionItem>[];

  SharedPreferences? _preferences;

  bool _isOnboardingComplete = false;
  String _selectedIntent = 'Focus';
  String _brainDumpText = '';
  int _tabIndex = 0;
  int _streak = 4;
  String _notificationMode = 'Gentle';
  String _notificationTime = '08:30';
  TaskEnergy _currentEnergy = TaskEnergy.medium;
  bool _isAuthenticating = false;
  bool _isAnonymousAuthenticated = false;
  String? _anonymousUserId;
  String? _authErrorMessage;
  String? _syncErrorMessage;
  bool _hasServerPremiumAccess = false;
  int _brainDumpUsesToday = 0;
  DateTime? _lastBrainDumpAt;
  DateTime? _lastTaskCompletionDate;

  List<TaskItem> get todayTasks => List.unmodifiable(_todayTasks);
  List<RoutineItem> get routines => List.unmodifiable(_routines);
  List<FocusSessionItem> get focusSessions => List.unmodifiable(_focusSessions);
  bool get isOnboardingComplete => _isOnboardingComplete;
  String get selectedIntent => _selectedIntent;
  String get brainDumpText => _brainDumpText;
  int get tabIndex => _tabIndex;
  int get streak => _streak;
  String get notificationMode => _notificationMode;
  String get notificationTime => _notificationTime;
  TaskEnergy get currentEnergy => _currentEnergy;
  bool get isAuthenticating => _isAuthenticating;
  bool get isAnonymousAuthenticated => _isAnonymousAuthenticated;
  String? get anonymousUserId => _anonymousUserId;
  String? get authErrorMessage => _authErrorMessage;
  String? get syncErrorMessage => _syncErrorMessage;
  String get firebaseStatus => _firebaseBootstrap.statusMessage;
  String get revenueCatStatus =>
      !_iapService.hasAvailablePackages
          ? 'Plans not ready yet.'
          : 'Plans ready.';
  bool get hasPremium => _hasServerPremiumAccess;
  bool get isRevenueCatConfigured => true;
  String? get monthlyPremiumPrice =>
      _iapService.monthlyPriceString.isEmpty
          ? null
          : _iapService.monthlyPriceString;
  String? get yearlyPremiumPrice =>
      _iapService.yearlyPriceString.isEmpty
          ? null
          : _iapService.yearlyPriceString;
  bool get hasAiPrioritySuggestions =>
      _remoteConfigService.aiPrioritySuggestionsEnabled &&
      (hasPremium || PremiumFeatureFlags.aiPrioritySuggestions);
  bool get hasOverwhelmDetector =>
      _remoteConfigService.overwhelmDetectorEnabled &&
      (hasPremium || PremiumFeatureFlags.overwhelmDetector);
  bool get hasMicroStepGenerator =>
      _remoteConfigService.microStepGeneratorEnabled &&
      (hasPremium || PremiumFeatureFlags.microStepGenerator);
  bool get hasDailyAiPlan =>
      _remoteConfigService.dailyAiPlanEnabled &&
      (hasPremium || PremiumFeatureFlags.dailyAiPlan);
  bool get hasAutoRescheduler =>
      _remoteConfigService.autoReschedulerEnabled &&
      (hasPremium || PremiumFeatureFlags.autoRescheduler);
  bool get hasSmartReminders =>
      _remoteConfigService.smartRemindersEnabled &&
      (hasPremium || PremiumFeatureFlags.smartReminders);
  bool get hasEnergyMatching =>
      _remoteConfigService.energyMatchingEnabled &&
      (hasPremium || PremiumFeatureFlags.energyMatching);
  bool get hasAdhdEmergencyMode =>
      _remoteConfigService.adhdEmergencyModeEnabled &&
      (hasPremium || PremiumFeatureFlags.adhdEmergencyMode);
  bool get canUseBrainDumpToday =>
      hasPremium ||
      _brainDumpUsesToday < _remoteConfigService.freeBrainDumpLimitPerDay;
  bool get canCreateRoutine =>
      hasPremium || _routines.length < _remoteConfigService.freeRoutineLimit;

  int get completedTasksToday =>
      _todayTasks.where((task) => task.isCompleted).length;
  int get totalTasksToday => _todayTasks.length;
  double get todayProgress =>
      _todayTasks.isEmpty ? 0 : completedTasksToday / _todayTasks.length;

  int get completedTasksThisWeek {
    final now = DateTime.now();
    return _todayTasks.where((task) {
      final completedAt = task.completedAt;
      return completedAt != null && now.difference(completedAt).inDays < 7;
    }).length;
  }

  int get focusMinutesToday {
    final now = DateTime.now();
    return _focusSessions
        .where((session) => _isSameDay(session.endTime, now))
        .fold(0, (sum, session) => sum + session.durationMinutes);
  }

  int get focusMinutesThisWeek {
    final now = DateTime.now();
    return _focusSessions
        .where((session) => now.difference(session.endTime).inDays < 7)
        .fold(0, (sum, session) => sum + session.durationMinutes);
  }

  int get productivityScore {
    final taskScore = completedTasksToday * 18;
    final focusScore = focusMinutesToday ~/ 2;
    return (taskScore + focusScore).clamp(0, 100);
  }

  TaskItem? get currentTask {
    try {
      return _todayTasks.firstWhere((task) => task.isFocus);
    } catch (_) {
      return null;
    }
  }

  TaskItem? get overwhelmedSuggestion {
    final openTasks =
        _todayTasks.where((task) => !task.isCompleted).toList()
          ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return openTasks.isEmpty ? null : openTasks.first;
  }

  OverwhelmRecommendation? get overwhelmRecommendation {
    final openTasks = _todayTasks.where((task) => !task.isCompleted).toList();
    if (openTasks.isEmpty) {
      return null;
    }

    openTasks.sort((a, b) => _overwhelmScore(a).compareTo(_overwhelmScore(b)));
    final task = openTasks.first;
    return OverwhelmRecommendation(
      task: task,
      estimatedMinutes: task.durationMinutes,
      energy: task.energy,
      microStep: generateMicroSteps(task.title).first,
      explanation: _overwhelmReason(task),
    );
  }

  List<TaskItem> get dailyFocusTasks {
    if (!hasDailyAiPlan) {
      return <TaskItem>[];
    }
    final openTasks =
        _todayTasks.where((task) => !task.isCompleted).toList()
          ..sort((a, b) => _dailyPlanScore(b).compareTo(_dailyPlanScore(a)));
    return openTasks.take(_remoteConfigService.maxDailyFocusTasks).toList();
  }

  int get hiddenTasksCount {
    final openCount = _todayTasks.where((task) => !task.isCompleted).length;
    final hidden = openCount - dailyFocusTasks.length;
    return hidden < 0 ? 0 : hidden;
  }

  ReminderSuggestion get smartReminderFallback {
    final openTasks =
        _todayTasks.where((task) => !task.isCompleted).toList()
          ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    if (openTasks.isEmpty) {
      return const ReminderSuggestion(
        title: 'Momentum protected',
        message: 'You cleared your list. Keep the rest of the day light.',
        actionLabel: 'Review Today',
      );
    }

    final quickest = openTasks.first;
    if (quickest.durationMinutes <= 5) {
      return ReminderSuggestion(
        title: 'Fast win available',
        message:
            '${quickest.title} only needs ${quickest.durationMinutes} minutes.',
        actionLabel: 'Start ${quickest.title}',
      );
    }
    if (completedTasksToday + 1 >= dailyFocusTasks.length &&
        dailyFocusTasks.isNotEmpty) {
      return const ReminderSuggestion(
        title: 'One more task',
        message: 'You are one task away from protecting today\'s momentum.',
        actionLabel: 'Finish Today Strong',
      );
    }
    return ReminderSuggestion(
      title: 'Low-friction next step',
      message:
          'Start ${quickest.title} now and you can clear it before your energy dips.',
      actionLabel: 'Start ${quickest.title}',
    );
  }

  List<TaskItem> get energyMatchedTasks {
    if (!hasEnergyMatching) {
      return <TaskItem>[];
    }
    final openTasks = _todayTasks.where((task) => !task.isCompleted).toList();
    final matched =
        openTasks.where(_fitsCurrentEnergy).toList()
          ..sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    if (matched.isNotEmpty) {
      return matched;
    }
    openTasks.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return openTasks.take(3).toList();
  }

  TaskItem? get emergencyTask {
    if (!hasAdhdEmergencyMode) {
      return null;
    }
    final openTasks = _todayTasks.where((task) => !task.isCompleted).toList();
    if (openTasks.isEmpty) {
      return null;
    }
    openTasks.sort((a, b) => _emergencyScore(a).compareTo(_emergencyScore(b)));
    return openTasks.first;
  }

  String get emergencyStep {
    final task = emergencyTask;
    if (task == null) {
      return 'Drink a glass of water.';
    }
    return generateMicroSteps(task.title).first;
  }

  String get emergencyNextStep {
    final tasks =
        _todayTasks.where((task) => !task.isCompleted).toList()
          ..sort((a, b) => _emergencyScore(a).compareTo(_emergencyScore(b)));
    if (tasks.length < 2) {
      return 'Take one deep breath.';
    }
    return generateMicroSteps(tasks[1].title).first;
  }

  String get overwhelmedMicroStep {
    final recommendation = overwhelmRecommendation;
    if (recommendation == null) {
      return 'Take one deep breath and add your next tiny task.';
    }
    return recommendation.microStep;
  }

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _isOnboardingComplete =
        _preferences?.getBool('onboarding_complete') ?? false;
    _selectedIntent = _preferences?.getString('intent') ?? _selectedIntent;
    _brainDumpText = _preferences?.getString('brain_dump_text') ?? '';
    _streak = _preferences?.getInt('streak') ?? _streak;
    _notificationMode =
        _preferences?.getString('notification_mode') ?? _notificationMode;
    _notificationTime =
        _preferences?.getString('notification_time') ?? _notificationTime;

    final brainDumpRaw = _preferences?.getString('last_brain_dump_at');
    if (brainDumpRaw != null) {
      _lastBrainDumpAt = DateTime.tryParse(brainDumpRaw);
    }
    _brainDumpUsesToday = _preferences?.getInt('brain_dump_uses_today') ?? 0;
    if (!_isSameDay(_lastBrainDumpAt, DateTime.now())) {
      _brainDumpUsesToday = 0;
    }

    final completionRaw = _preferences?.getString('last_task_completion_date');
    if (completionRaw != null) {
      _lastTaskCompletionDate = DateTime.tryParse(completionRaw);
    }

    await _ensureRemoteConfig();
    if (_isOnboardingComplete) {
      await authenticateAnonymously();
    }
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String intent,
    required String brainDumpText,
    required List<TaskItem> generatedTasks,
  }) async {
    _selectedIntent = intent;
    _brainDumpText = brainDumpText;
    _todayTasks
      ..clear()
      ..addAll(generatedTasks.take(5));
    await _preferences?.setString('intent', intent);
    await _preferences?.setString('brain_dump_text', brainDumpText);
    await authenticateAnonymously(hydrateFromRemote: false);
    _isOnboardingComplete = true;
    await _preferences?.setBool('onboarding_complete', true);
    try {
      await _syncPlannerToFirestore();
    } catch (error) {
      _syncErrorMessage = _formatSyncError(error);
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> authenticateAnonymously({bool hydrateFromRemote = true}) async {
    if (_isAuthenticating) {
      return;
    }

    _isAuthenticating = true;
    _authErrorMessage = null;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      await _authService.signInAnonymouslyIfNeeded();
      _isAnonymousAuthenticated = _authService.isSignedInAnonymously;
      _anonymousUserId = _authService.currentUserId;
      if (!_isAnonymousAuthenticated) {
        _authErrorMessage =
            'We could not finish setting up your private account. Please try again.';
      } else {
        if (_anonymousUserId != null) {
          await _configureRevenueCatForCurrentUser();
          await _refreshPremiumAccess();
        }
        await _finishAnonymousSetup(hydrateFromRemote: hydrateFromRemote);
      }
    } catch (error) {
      _isAnonymousAuthenticated = false;
      _anonymousUserId = null;
      _authErrorMessage = _formatAuthError(error);
      debugPrint('Firebase anonymous sign-in failed: $error');
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> _finishAnonymousSetup({required bool hydrateFromRemote}) async {
    try {
      if (hydrateFromRemote) {
        await _hydrateFromFirestore();
      }
      await _syncUserProfileToFirestore();
      _syncErrorMessage = null;
    } catch (error) {
      _syncErrorMessage = _formatSyncError(error);
      debugPrint('Cloud sync setup failed: $error');
    }
  }

  Future<void> refreshPremiumOfferings() async {
    await _configureRevenueCatForCurrentUser();
    await _iapService.loadOfferings();
    notifyListeners();
  }

  Future<bool> purchasePremiumPlan(String planId) async {
    final userId = _anonymousUserId;
    if (userId == null) {
      throw StateError('Please wait a moment and try again.');
    }

    await _iapService.initialize(userId);
    final purchaseCompleted = await _iapService.purchase(
      planId == 'yearly'
          ? SubscriptionPlan.yearly
          : SubscriptionPlan.monthly,
    );
    if (purchaseCompleted) {
      await syncPremiumStateToCloud();
    }

    notifyListeners();
    return hasPremium;
  }

  Future<bool> restorePremiumPurchases() async {
    final userId = _anonymousUserId;
    if (userId == null) {
      throw StateError('Please wait a moment and try again.');
    }

    await _iapService.initialize(userId);
    final restoreCompleted = await _iapService.restore();
    if (restoreCompleted) {
      await syncPremiumStateToCloud();
    }

    notifyListeners();
    return hasPremium;
  }

  String humanizeRevenueCatError(Object error) {
    return _iapService.humanizeError(error);
  }

  Future<void> syncPremiumStateToCloud() async {
    try {
      await _refreshPremiumAccess();
      if (!hasPremium) {
        notifyListeners();
        return;
      }
      await _syncUserProfileToFirestore();
    } catch (error) {
      _syncErrorMessage = _formatSyncError(error);
    }
    notifyListeners();
  }

  Future<void> _configureRevenueCatForCurrentUser() async {
    final userId = _anonymousUserId;
    if (userId == null) {
      return;
    }

    try {
      await _iapService.initialize(userId);
      await _iapService.setUserId(userId);
    } catch (_) {
      // The paywall can still render even if subscriptions are not ready yet.
    }
  }

  void _handleIapChanged() {
    notifyListeners();
  }

  Future<void> _refreshPremiumAccess() async {
    final userId = _anonymousUserId;
    if (userId == null || !_isAnonymousAuthenticated) {
      _hasServerPremiumAccess = false;
      return;
    }

    try {
      final status = await _premiumAccessService.refreshPremiumStatus();
      _hasServerPremiumAccess = status.isPremium;
    } catch (error) {
      _hasServerPremiumAccess = false;
      debugPrint('Premium access refresh failed: $error');
    }
  }

  void setTab(int index) {
    _tabIndex = index;
    notifyListeners();
  }

  void setCurrentEnergy(TaskEnergy energy) {
    _currentEnergy = energy;
    notifyListeners();
  }

  void addTask({
    required String title,
    required int durationMinutes,
    TaskEnergy energy = TaskEnergy.medium,
  }) {
    _todayTasks.add(
      TaskItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        durationMinutes: durationMinutes,
        energy: energy,
      ),
    );
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void updateTask({
    required String taskId,
    required String title,
    required int durationMinutes,
    required bool completed,
  }) {
    final index = _todayTasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }

    final updatedTask = _todayTasks[index].copyWith(
      title: title,
      durationMinutes: durationMinutes,
      isCompleted: completed,
      completedAt:
          completed ? (_todayTasks[index].completedAt ?? DateTime.now()) : null,
      clearCompletedAt: !completed,
    );
    _todayTasks[index] = updatedTask;
    if (completed) {
      _handleCompletion(updatedTask);
    }
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void toggleTask(TaskItem task) {
    final index = _todayTasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      return;
    }
    final willComplete = !_todayTasks[index].isCompleted;
    final updatedTask = _todayTasks[index].copyWith(
      isCompleted: willComplete,
      completedAt: willComplete ? DateTime.now() : null,
      clearCompletedAt: !willComplete,
    );
    _todayTasks[index] = updatedTask;
    if (willComplete) {
      _handleCompletion(updatedTask);
    }
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void deleteTask(String taskId) {
    _todayTasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void markFocus(TaskItem task) {
    for (var i = 0; i < _todayTasks.length; i++) {
      _todayTasks[i] = _todayTasks[i].copyWith(
        isFocus: _todayTasks[i].id == task.id,
      );
    }
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void clearFocus() {
    for (var i = 0; i < _todayTasks.length; i++) {
      if (_todayTasks[i].isFocus) {
        _todayTasks[i] = _todayTasks[i].copyWith(isFocus: false);
      }
    }
    notifyListeners();
  }

  void completeFocusSession({
    required TaskItem task,
    required DateTime startTime,
    required int elapsedSeconds,
  }) {
    final durationMinutes = (elapsedSeconds / 60).ceil().clamp(
      1,
      task.durationMinutes,
    );
    _focusSessions.add(
      FocusSessionItem(
        id: 'focus-${DateTime.now().microsecondsSinceEpoch}',
        taskId: task.id,
        startTime: startTime,
        endTime: DateTime.now(),
        durationMinutes: durationMinutes,
      ),
    );
    finishTask(task);
  }

  void finishTask(TaskItem task) {
    final index = _todayTasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      return;
    }
    final updatedTask = _todayTasks[index].copyWith(
      isCompleted: true,
      isFocus: false,
      completedAt: _todayTasks[index].completedAt ?? DateTime.now(),
    );
    _todayTasks[index] = updatedTask;
    _handleCompletion(updatedTask);
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void startMyDay() {
    final firstOpen = _todayTasks.indexWhere((task) => !task.isCompleted);
    if (firstOpen != -1) {
      markFocus(_todayTasks[firstOpen]);
    }
  }

  List<TaskItem> generatePlanFromBrainDump(String input) {
    final pieces =
        input
            .split(RegExp(r'[\n,]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(4)
            .toList();

    final seeds =
        pieces.isEmpty
            ? <String>[
              'Drink water',
              'Choose top priority',
              'Clear one surface',
            ]
            : pieces;

    return List<TaskItem>.generate(seeds.length, (index) {
      final duration = switch (index) {
        0 => 5,
        1 => 10,
        2 => 15,
        _ => 30,
      };
      return TaskItem(
        id: 'brain-$index-${DateTime.now().millisecondsSinceEpoch}',
        title: _capitalize(seeds[index]),
        durationMinutes: duration,
        energy: duration <= 10 ? TaskEnergy.low : TaskEnergy.medium,
      );
    });
  }

  PlanningInsight generatePlanningInsight(String input) {
    if (!hasAiPrioritySuggestions) {
      return const PlanningInsight(tasks: <PrioritizedTask>[], suggestion: '');
    }
    final tasks =
        input
            .split(RegExp(r'[\n,]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .map(_buildPrioritizedTask)
            .toList();

    final sorted = List<PrioritizedTask>.from(tasks)..sort(
      (a, b) => _priorityRank(a.priority).compareTo(_priorityRank(b.priority)),
    );

    final suggestion =
        sorted.isEmpty
            ? 'Start with a 5 minute reset task.'
            : 'Start with ${sorted.first.title}. ${_suggestionReason(sorted.first)}';

    return PlanningInsight(tasks: sorted, suggestion: suggestion);
  }

  Future<PlanningInsight> generatePlanningInsightWithAi(String input) async {
    if (!hasAiPrioritySuggestions ||
        !_remoteConfigService.openAiEnabled ||
        !_isAnonymousAuthenticated) {
      return generatePlanningInsight(input);
    }

    final premiumAiService = _premiumAiServiceOrNull;
    if (premiumAiService == null) {
      return generatePlanningInsight(input);
    }

    try {
      final response = await premiumAiService.generatePrioritySuggestions(
        brainDump: input,
        model: _remoteConfigService.openAiModel,
      );
      final rawTasks = (response['tasks'] as List<dynamic>? ?? <dynamic>[]);
      final tasks =
          rawTasks
              .whereType<Map>()
              .map(
                (rawTask) => PrioritizedTask(
                  title: _normalizeTitle('${rawTask['title'] ?? ''}'),
                  priority: _priorityFromString('${rawTask['priority'] ?? ''}'),
                  durationMinutes: _readPositiveInt(
                    rawTask['duration_minutes'],
                    fallback: 15,
                  ),
                  energy: _energyFromString('${rawTask['energy'] ?? ''}'),
                  reason: '${rawTask['reason'] ?? ''}'.trim(),
                ),
              )
              .where((task) => task.title.isNotEmpty)
              .toList();

      if (tasks.isEmpty) {
        return generatePlanningInsight(input);
      }

      final suggestion =
          '${response['suggestion'] ?? response['start_with'] ?? ''}'.trim();
      return PlanningInsight(
        tasks: tasks,
        suggestion:
            suggestion.isEmpty
                ? 'Start with ${tasks.first.title}. ${_suggestionReason(tasks.first)}'
                : suggestion,
      );
    } catch (_) {
      return generatePlanningInsight(input);
    }
  }

  List<String> generateMicroSteps(String taskTitle) {
    if (!hasMicroStepGenerator) {
      return <String>['Upgrade to unlock AI micro-steps.'];
    }
    final lowered = taskTitle.toLowerCase();

    if (lowered.contains('clean')) {
      return <String>[
        'Pick up 5 items.',
        'Throw away visible trash.',
        'Wipe one surface.',
        'Vacuum one room.',
      ];
    }
    if (lowered.contains('insurance')) {
      return <String>[
        'Open the insurance website or app.',
        'Find the phone number or claim page.',
        'Write the one question you need answered.',
        'Make the call or submit the request.',
      ];
    }
    if (lowered.contains('dentist')) {
      return <String>[
        'Find the dentist number.',
        'Open your calendar.',
        'Call and ask for the next available slot.',
      ];
    }
    if (lowered.contains('grocer') || lowered.contains('shopping')) {
      return <String>[
        'Write the top 5 essentials.',
        'Check what you already have.',
        'Go only for the essentials.',
      ];
    }
    if (lowered.contains('project') || lowered.contains('report')) {
      return <String>[
        'Open the project file.',
        'Write the next visible subtask.',
        'Work on it for 10 minutes only.',
      ];
    }
    if (lowered.contains('email') || lowered.contains('reply')) {
      return <String>[
        'Open your inbox.',
        'Pick one message only.',
        'Write a two-line reply.',
      ];
    }

    return <String>[
      'Open what you need for $taskTitle.',
      'Define the first tiny action.',
      'Work on it for 5 minutes.',
    ];
  }

  Future<List<String>> generateMicroStepsWithAi(String taskTitle) async {
    if (!hasMicroStepGenerator ||
        !_remoteConfigService.openAiEnabled ||
        !_isAnonymousAuthenticated) {
      return generateMicroSteps(taskTitle);
    }

    final premiumAiService = _premiumAiServiceOrNull;
    if (premiumAiService == null) {
      return generateMicroSteps(taskTitle);
    }

    try {
      final response = await premiumAiService.generateMicroSteps(
        taskTitle: taskTitle,
        model: _remoteConfigService.openAiModel,
      );
      final steps =
          (response['steps'] as List<dynamic>? ?? <dynamic>[])
              .map((step) => '$step'.trim())
              .where((step) => step.isNotEmpty)
              .toList();
      final tinyFirstStep = '${response['tiny_first_step'] ?? ''}'.trim();
      if (tinyFirstStep.isNotEmpty && !steps.contains(tinyFirstStep)) {
        steps.insert(0, tinyFirstStep);
      }
      return steps.isEmpty ? generateMicroSteps(taskTitle) : steps;
    } catch (_) {
      return generateMicroSteps(taskTitle);
    }
  }

  Future<OverwhelmRecommendation?>
  generateOverwhelmRecommendationWithAi() async {
    if (!hasOverwhelmDetector ||
        !_remoteConfigService.openAiEnabled ||
        !_isAnonymousAuthenticated) {
      return overwhelmRecommendation;
    }

    final openTasks = _todayTasks.where((task) => !task.isCompleted).toList();
    if (openTasks.isEmpty) {
      return null;
    }

    final premiumAiService = _premiumAiServiceOrNull;
    if (premiumAiService == null) {
      return overwhelmRecommendation;
    }

    try {
      final response = await premiumAiService.detectOverwhelm(
        tasks: openTasks.map(_serializeTaskForAi).toList(),
        model: _remoteConfigService.openAiModel,
      );
      final chosenTaskId = '${response['chosen_task_id'] ?? ''}'.trim();
      final chosenTaskTitle = '${response['chosen_task_title'] ?? ''}'.trim();
      TaskItem? task;
      if (chosenTaskId.isNotEmpty) {
        for (final candidate in openTasks) {
          if (candidate.id == chosenTaskId) {
            task = candidate;
            break;
          }
        }
      }
      task ??= openTasks.cast<TaskItem?>().firstWhere(
        (candidate) =>
            candidate?.title.toLowerCase() == chosenTaskTitle.toLowerCase(),
        orElse: () => null,
      );
      task ??= openTasks.first;

      return OverwhelmRecommendation(
        task: task,
        estimatedMinutes: _readPositiveInt(
          response['estimated_minutes'],
          fallback: task.durationMinutes,
        ),
        energy: _energyFromString('${response['energy'] ?? task.energy.name}'),
        microStep:
            '${response['first_micro_step'] ?? ''}'.trim().isEmpty
                ? generateMicroSteps(task.title).first
                : '${response['first_micro_step']}'.trim(),
        explanation:
            '${response['why_this_task'] ?? ''}'.trim().isEmpty
                ? _overwhelmReason(task)
                : '${response['why_this_task']}'.trim(),
      );
    } catch (_) {
      return overwhelmRecommendation;
    }
  }

  DailyPlanRecommendation generateDailyPlanFallback() {
    return DailyPlanRecommendation(
      tasks: dailyFocusTasks,
      hiddenCount: hiddenTasksCount,
      why:
          'These tasks balance urgency, shorter wins, and your current energy.',
    );
  }

  Future<DailyPlanRecommendation> generateDailyPlanWithAi() async {
    if (!hasDailyAiPlan ||
        !_remoteConfigService.openAiEnabled ||
        !_isAnonymousAuthenticated) {
      return generateDailyPlanFallback();
    }

    final openTasks = _todayTasks.where((task) => !task.isCompleted).toList();
    if (openTasks.isEmpty) {
      return generateDailyPlanFallback();
    }

    final premiumAiService = _premiumAiServiceOrNull;
    if (premiumAiService == null) {
      return generateDailyPlanFallback();
    }

    try {
      final response = await premiumAiService.generateDailyPlan(
        tasks: openTasks.map(_serializeTaskForAi).toList(),
        currentEnergy: _currentEnergy.name,
        model: _remoteConfigService.openAiReasoningModel,
      );
      final idList =
          (response['today_focus_ids'] as List<dynamic>? ?? <dynamic>[])
              .map((id) => '$id')
              .toList();
      final tasksById = <String, TaskItem>{
        for (final task in openTasks) task.id: task,
      };
      final selected =
          idList.map((id) => tasksById[id]).whereType<TaskItem>().toList();
      if (selected.isEmpty) {
        return generateDailyPlanFallback();
      }
      final hiddenCount = _readPositiveInt(
        response['hidden_count'],
        fallback: (openTasks.length - selected.length).clamp(
          0,
          openTasks.length,
        ),
      );
      return DailyPlanRecommendation(
        tasks: selected,
        hiddenCount: hiddenCount,
        why:
            '${response['why'] ?? ''}'.trim().isEmpty
                ? generateDailyPlanFallback().why
                : '${response['why']}'.trim(),
      );
    } catch (_) {
      return generateDailyPlanFallback();
    }
  }

  Future<ReminderSuggestion> generateSmartReminderWithAi() async {
    if (!hasSmartReminders ||
        !_remoteConfigService.openAiEnabled ||
        !_isAnonymousAuthenticated) {
      return smartReminderFallback;
    }

    final premiumAiService = _premiumAiServiceOrNull;
    if (premiumAiService == null) {
      return smartReminderFallback;
    }

    try {
      final response = await premiumAiService.generateSmartReminders(
        tasks: _todayTasks.map(_serializeTaskForAi).toList(),
        currentEnergy: _currentEnergy.name,
        streak: _streak,
        model: _remoteConfigService.openAiModel,
      );
      final reminders =
          (response['reminders'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => ReminderSuggestion(
                  title: '${item['title'] ?? ''}'.trim(),
                  message: '${item['message'] ?? ''}'.trim(),
                  actionLabel: '${item['action_label'] ?? 'Open Today'}'.trim(),
                ),
              )
              .where((item) => item.title.isNotEmpty && item.message.isNotEmpty)
              .toList();
      if (reminders.isEmpty) {
        return smartReminderFallback;
      }
      return reminders.first;
    } catch (_) {
      return smartReminderFallback;
    }
  }

  Future<ReschedulePlan> generateReschedulePlanWithAi() async {
    final openTasks = _todayTasks.where((task) => !task.isCompleted).toList();
    if (!hasAutoRescheduler ||
        !_remoteConfigService.openAiEnabled ||
        !_isAnonymousAuthenticated ||
        openTasks.isEmpty) {
      return _fallbackReschedulePlan(openTasks);
    }

    final premiumAiService = _premiumAiServiceOrNull;
    if (premiumAiService == null) {
      return _fallbackReschedulePlan(openTasks);
    }

    try {
      final response = await premiumAiService.rescheduleTasks(
        tasks: openTasks.map(_serializeTaskForAi).toList(),
        model: _remoteConfigService.openAiReasoningModel,
      );
      final droppedIds =
          (response['dropped_task_ids'] as List<dynamic>? ?? <dynamic>[])
              .map((id) => '$id')
              .toSet();
      final tasksById = <String, TaskItem>{
        for (final task in openTasks) task.id: task,
      };
      final tomorrow =
          (response['tomorrow'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map>()
              .map((item) {
                final task = tasksById['${item['id'] ?? ''}'];
                if (task == null) {
                  return null;
                }
                return RescheduleItem(
                  task: task,
                  priorityReason: '${item['priority_reason'] ?? ''}'.trim(),
                );
              })
              .whereType<RescheduleItem>()
              .toList();
      if (tomorrow.isEmpty) {
        return _fallbackReschedulePlan(openTasks);
      }
      final dropped =
          openTasks.where((task) => droppedIds.contains(task.id)).toList();
      return ReschedulePlan(tomorrow: tomorrow, droppedTasks: dropped);
    } catch (_) {
      return _fallbackReschedulePlan(openTasks);
    }
  }

  Future<ReschedulePlan> applyAutoRescheduler() async {
    final plan = await generateReschedulePlanWithAi();
    final tomorrowDate = DateTime.now().add(const Duration(days: 1));
    final keptIds = plan.tomorrow.map((item) => item.task.id).toSet();
    _todayTasks.removeWhere(
      (task) => !task.isCompleted && !keptIds.contains(task.id),
    );

    final reordered = <TaskItem>[];
    for (final item in plan.tomorrow) {
      reordered.add(item.task.copyWith(scheduledDate: tomorrowDate));
    }

    final completedTasks =
        _todayTasks.where((task) => task.isCompleted).toList();
    _todayTasks
      ..clear()
      ..addAll(reordered)
      ..addAll(completedTasks);
    notifyListeners();
    await _syncPlannerToFirestore();
    return plan;
  }

  Future<bool> registerBrainDumpUse() async {
    if (!canUseBrainDumpToday) {
      return false;
    }
    final previousUseAt = _lastBrainDumpAt;
    _lastBrainDumpAt = DateTime.now();
    if (_isSameDay(previousUseAt, _lastBrainDumpAt)) {
      _brainDumpUsesToday += 1;
    } else {
      _brainDumpUsesToday = 1;
    }
    await _preferences?.setString(
      'last_brain_dump_at',
      _lastBrainDumpAt!.toIso8601String(),
    );
    await _preferences?.setInt('brain_dump_uses_today', _brainDumpUsesToday);
    notifyListeners();
    return true;
  }

  void addTasksToToday(List<TaskItem> tasks) {
    for (final task in tasks) {
      addTask(
        title: task.title,
        durationMinutes: task.durationMinutes,
        energy: task.energy,
      );
    }
  }

  void createRoutine(String name) {
    _routines.add(
      RoutineItem(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        title: name,
        tasks: <String>[],
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void addTaskToRoutine({
    required String routineId,
    required String taskTitle,
  }) {
    final index = _routines.indexWhere((routine) => routine.id == routineId);
    if (index == -1) {
      return;
    }
    final tasks = List<String>.from(_routines[index].tasks)..add(taskTitle);
    _routines[index] = _routines[index].copyWith(tasks: tasks);
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void deleteTaskFromRoutine({
    required String routineId,
    required int taskIndex,
  }) {
    final index = _routines.indexWhere((routine) => routine.id == routineId);
    if (index == -1) {
      return;
    }
    final tasks = List<String>.from(_routines[index].tasks);
    if (taskIndex < 0 || taskIndex >= tasks.length) {
      return;
    }
    tasks.removeAt(taskIndex);
    _routines[index] = _routines[index].copyWith(tasks: tasks);
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void deleteRoutine(String routineId) {
    _routines.removeWhere((routine) => routine.id == routineId);
    notifyListeners();
    _scheduleFirestoreSync();
  }

  void startRoutine(RoutineItem routine) {
    for (final taskTitle in routine.tasks) {
      addTask(title: taskTitle, durationMinutes: 10);
    }
  }

  Future<void> resetOnboarding() async {
    _isOnboardingComplete = false;
    await _preferences?.setBool('onboarding_complete', false);
    notifyListeners();
    await _syncUserProfileToFirestore();
  }

  Future<void> updateNotifications({
    required String mode,
    required String time,
  }) async {
    _notificationMode = mode;
    _notificationTime = time;
    await _preferences?.setString('notification_mode', mode);
    await _preferences?.setString('notification_time', time);
    notifyListeners();
    await _syncUserProfileToFirestore();
  }

  void _handleCompletion(TaskItem task) {
    final now = task.completedAt ?? DateTime.now();
    if (_isSameDay(_lastTaskCompletionDate, now)) {
      return;
    }
    _lastTaskCompletionDate = now;
    _streak += 1;
    _preferences?.setInt('streak', _streak);
    _preferences?.setString('last_task_completion_date', now.toIso8601String());
  }

  Future<void> _ensureRemoteConfig() async {
    try {
      await _remoteConfigService.sync();
    } catch (_) {
      // Keep the app usable even if remote config is unavailable.
    }
  }

  Future<void> _hydrateFromFirestore() async {
    final userId = _anonymousUserId;
    if (userId == null) {
      return;
    }

    final snapshot = await _firestoreService.fetchPlannerSnapshot(userId);
    if (snapshot == null) {
      return;
    }

    _applyFirestoreSnapshot(snapshot);
    await _preferences?.setString('intent', _selectedIntent);
    await _preferences?.setString('brain_dump_text', _brainDumpText);
    await _preferences?.setString('notification_mode', _notificationMode);
    await _preferences?.setString('notification_time', _notificationTime);
    await _preferences?.setInt('streak', _streak);
    await _preferences?.setBool('onboarding_complete', _isOnboardingComplete);
  }

  void _applyFirestoreSnapshot(FirebasePlannerSnapshot snapshot) {
    _selectedIntent = snapshot.selectedIntent;
    _brainDumpText = snapshot.brainDumpText;
    _notificationTime = snapshot.notificationTime;
    _notificationMode = snapshot.notificationMode;
    _streak = snapshot.streak == 0 ? _streak : snapshot.streak;

    if (snapshot.tasks.isNotEmpty) {
      _todayTasks
        ..clear()
        ..addAll(snapshot.tasks);
    }

    if (snapshot.routines.isNotEmpty) {
      _routines
        ..clear()
        ..addAll(snapshot.routines);
    }

    if (snapshot.focusSessions.isNotEmpty) {
      _focusSessions
        ..clear()
        ..addAll(snapshot.focusSessions);
    }

    if (snapshot.onboardingComplete) {
      _isOnboardingComplete = true;
    }
  }

  void _scheduleFirestoreSync() {
    unawaited(_syncPlannerToFirestore());
  }

  Future<void> _syncPlannerToFirestore() async {
    final userId = _anonymousUserId;
    if (userId == null || !_isAnonymousAuthenticated) {
      return;
    }

    try {
      await _syncUserProfileToFirestore();
      await _firestoreService.replaceTasks(userId: userId, tasks: _todayTasks);
      await _firestoreService.replaceRoutines(
        userId: userId,
        routines: _routines,
      );
      await _firestoreService.replaceFocusSessions(
        userId: userId,
        sessions: _focusSessions,
      );
      _syncErrorMessage = null;
    } catch (error) {
      _syncErrorMessage = _formatSyncError(error);
      notifyListeners();
    }
  }

  Future<void> _syncUserProfileToFirestore() async {
    final userId = _anonymousUserId;
    if (userId == null || !_isAnonymousAuthenticated) {
      return;
    }

    await _firestoreService.upsertUserProfile(
      userId: userId,
      onboardingComplete: _isOnboardingComplete,
      selectedIntent: _selectedIntent,
      brainDumpText: _brainDumpText,
      streak: _streak,
      notificationTime: _notificationTime,
      notificationMode: _notificationMode,
    );
  }

  PrioritizedTask _buildPrioritizedTask(String rawTitle) {
    final normalized = _normalizeTitle(rawTitle);
    final lowered = normalized.toLowerCase();

    final hasUrgentKeyword = _containsAny(lowered, <String>[
      'insurance',
      'dentist',
      'bill',
      'call',
      'appointment',
      'deadline',
    ]);
    final isLargeTask = _containsAny(lowered, <String>[
      'project',
      'report',
      'apartment',
      'clean',
      'organize',
      'finish',
    ]);
    final isErrand = _containsAny(lowered, <String>[
      'grocer',
      'buy',
      'shopping',
      'store',
    ]);

    final priority =
        hasUrgentKeyword
            ? PriorityLevel.high
            : isLargeTask
            ? PriorityLevel.medium
            : isErrand
            ? PriorityLevel.low
            : PriorityLevel.medium;

    final durationMinutes = _estimatedDurationForText(lowered);
    final energy = _energyForText(lowered, durationMinutes);

    return PrioritizedTask(
      title: normalized,
      priority: priority,
      durationMinutes: durationMinutes,
      energy: energy,
      reason: _reasonForPriority(priority, lowered),
    );
  }

  int _priorityRank(PriorityLevel priority) {
    switch (priority) {
      case PriorityLevel.high:
        return 0;
      case PriorityLevel.medium:
        return 1;
      case PriorityLevel.low:
        return 2;
    }
  }

  int _estimatedDurationForText(String lowered) {
    if (_containsAny(lowered, <String>['dentist', 'schedule'])) {
      return 5;
    }
    if (_containsAny(lowered, <String>[
      'insurance',
      'call',
      'reply',
      'email',
    ])) {
      return 10;
    }
    if (_containsAny(lowered, <String>['grocer', 'shopping', 'buy'])) {
      return 30;
    }
    if (_containsAny(lowered, <String>['project', 'report', 'finish'])) {
      return 45;
    }
    if (_containsAny(lowered, <String>['clean', 'apartment', 'organize'])) {
      return 30;
    }
    return 15;
  }

  TaskEnergy _energyForText(String lowered, int durationMinutes) {
    if (_containsAny(lowered, <String>[
      'call',
      'dentist',
      'insurance',
      'reply',
    ])) {
      return TaskEnergy.low;
    }
    if (_containsAny(lowered, <String>['project', 'report', 'finish'])) {
      return TaskEnergy.high;
    }
    if (durationMinutes <= 10) {
      return TaskEnergy.low;
    }
    if (durationMinutes >= 30) {
      return TaskEnergy.high;
    }
    return TaskEnergy.medium;
  }

  String _reasonForPriority(PriorityLevel priority, String lowered) {
    switch (priority) {
      case PriorityLevel.high:
        return lowered.contains('call')
            ? 'Fast external task with likely urgency.'
            : 'Time-sensitive admin task.';
      case PriorityLevel.medium:
        return lowered.contains('project')
            ? 'Important but requires a longer block.'
            : 'Useful next step after urgent items.';
      case PriorityLevel.low:
        return 'Can wait until higher-pressure tasks are handled.';
    }
  }

  String _suggestionReason(PrioritizedTask task) {
    if (task.durationMinutes <= 10) {
      return 'Fastest win.';
    }
    if (task.priority == PriorityLevel.high) {
      return 'Highest urgency.';
    }
    return 'Best next step.';
  }

  int _overwhelmScore(TaskItem task) {
    var score = task.durationMinutes;
    switch (task.energy) {
      case TaskEnergy.low:
        score -= 6;
      case TaskEnergy.medium:
        score += 0;
      case TaskEnergy.high:
        score += 12;
    }
    final lowered = task.title.toLowerCase();
    if (_containsAny(lowered, <String>['call', 'dentist', 'reply'])) {
      score -= 4;
    }
    if (_containsAny(lowered, <String>['project', 'clean', 'finish'])) {
      score += 8;
    }
    return score;
  }

  String _overwhelmReason(TaskItem task) {
    if (task.durationMinutes <= 5) {
      return 'Shortest task on your list.';
    }
    if (task.energy == TaskEnergy.low) {
      return 'Low energy task with a quick payoff.';
    }
    return 'Most manageable next step right now.';
  }

  int _dailyPlanScore(TaskItem task) {
    var score = 0;
    final lowered = task.title.toLowerCase();
    if (_containsAny(lowered, <String>[
      'dentist',
      'insurance',
      'call',
      'deadline',
    ])) {
      score += 18;
    }
    if (_containsAny(lowered, <String>['project', 'report', 'finish'])) {
      score += 12;
    }
    if (task.durationMinutes <= 10) {
      score += 8;
    } else if (task.durationMinutes <= 20) {
      score += 5;
    }
    switch (task.energy) {
      case TaskEnergy.low:
        score += 5;
      case TaskEnergy.medium:
        score += 3;
      case TaskEnergy.high:
        score += 1;
    }
    return score;
  }

  bool _fitsCurrentEnergy(TaskItem task) {
    switch (_currentEnergy) {
      case TaskEnergy.low:
        return task.energy == TaskEnergy.low;
      case TaskEnergy.medium:
        return task.energy != TaskEnergy.high;
      case TaskEnergy.high:
        return true;
    }
  }

  int _emergencyScore(TaskItem task) {
    var score = task.durationMinutes;
    switch (task.energy) {
      case TaskEnergy.low:
        score -= 8;
      case TaskEnergy.medium:
        score += 0;
      case TaskEnergy.high:
        score += 10;
    }
    final lowered = task.title.toLowerCase();
    if (_containsAny(lowered, <String>[
      'drink',
      'water',
      'call',
      'reply',
      'dentist',
    ])) {
      score -= 4;
    }
    if (_containsAny(lowered, <String>['project', 'clean', 'finish'])) {
      score += 6;
    }
    return score;
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }

  ReschedulePlan _fallbackReschedulePlan(List<TaskItem> openTasks) {
    final ordered = List<TaskItem>.from(openTasks)
      ..sort((a, b) => _dailyPlanScore(b).compareTo(_dailyPlanScore(a)));
    return ReschedulePlan(
      tomorrow:
          ordered
              .map(
                (task) => RescheduleItem(
                  task: task,
                  priorityReason:
                      task.durationMinutes <= 10
                          ? 'Quickest win to restart tomorrow.'
                          : _overwhelmReason(task),
                ),
              )
              .toList(),
      droppedTasks: const <TaskItem>[],
    );
  }

  String _normalizeTitle(String rawTitle) {
    final cleaned =
        rawTitle
            .replaceFirst(RegExp(r'^need to\s+', caseSensitive: false), '')
            .trim();
    if (cleaned.isEmpty) {
      return rawTitle.trim();
    }
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  Map<String, dynamic> _serializeTaskForAi(TaskItem task) {
    return <String, dynamic>{
      'id': task.id,
      'title': task.title,
      'duration_minutes': task.durationMinutes,
      'energy': task.energy.name,
      'completed': task.isCompleted,
    };
  }

  PriorityLevel _priorityFromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return PriorityLevel.high;
      case 'low':
        return PriorityLevel.low;
      default:
        return PriorityLevel.medium;
    }
  }

  TaskEnergy _energyFromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return TaskEnergy.low;
      case 'high':
        return TaskEnergy.high;
      default:
        return TaskEnergy.medium;
    }
  }

  int _readPositiveInt(Object? value, {required int fallback}) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      return fallback;
    }
    return parsed;
  }

  String _formatAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'operation-not-allowed':
          return 'Private sign-in is not available right now. Please try again later.';
        case 'network-request-failed':
          return 'We could not connect right now. Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts right now. Please wait a moment and try again.';
        default:
          return 'We could not create your private account yet. Please try again.';
      }
    }
    return 'We could not create your private account yet. Please try again.';
  }

  String? _formatSyncError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return null;
        case 'network-request-failed':
        case 'unavailable':
          return 'Cloud sync is temporarily unavailable. Your changes stay on this device until the connection is back.';
      }
    }
    return null;
  }

  @override
  void dispose() {
    _iapService.removeListener(_handleIapChanged);
    super.dispose();
  }
}
