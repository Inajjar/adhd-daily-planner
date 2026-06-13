import 'package:flutter/material.dart';

import '../firebase/core/firebase_bootstrap.dart';
import '../services/iap_service.dart';
import '../state/app_state.dart';
import 'theme.dart';
import '../features/home/home_shell.dart';

class AdhdDailyPlannerApp extends StatefulWidget {
  const AdhdDailyPlannerApp({
    super.key,
    required this.firebaseBootstrap,
    required this.iapService,
  });

  final FirebaseBootstrap firebaseBootstrap;
  final IAPService iapService;

  @override
  State<AdhdDailyPlannerApp> createState() => _AdhdDailyPlannerAppState();
}

class _AdhdDailyPlannerAppState extends State<AdhdDailyPlannerApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState(
      firebaseBootstrap: widget.firebaseBootstrap,
      iapService: widget.iapService,
    )..initialize();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADHD Daily Planner',
      debugShowCheckedModeBanner: false,
      theme: buildAdhdDailyPlannerTheme(),
      home: HomeShell(appState: _appState),
    );
  }
}
