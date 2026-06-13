import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase/core/firebase_bootstrap.dart';
import 'services/iap_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseBootstrap = FirebaseBootstrap();
  await firebaseBootstrap.initialize();

  final iapService = IAPService();
  await iapService.initialize();

  runApp(
    AdhdDailyPlannerApp(
      firebaseBootstrap: firebaseBootstrap,
      iapService: iapService,
    ),
  );
}
