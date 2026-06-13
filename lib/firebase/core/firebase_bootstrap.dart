import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_config.dart';

class FirebaseBootstrap {
  bool _isReady = false;
  String? _statusMessage;

  bool get isReady => _isReady;
  String get statusMessage => _statusMessage ?? 'Firebase placeholder mode';

  Future<void> initialize() async {
    if (!FirebaseConfig.current.enabled) {
      _statusMessage = 'Firebase disabled until you add real config files.';
      return;
    }

    try {
      await Firebase.initializeApp();
      _isReady = true;
      _statusMessage = 'Firebase connected';
    } catch (error, stackTrace) {
      _statusMessage = 'Firebase not configured yet';
      debugPrint('Firebase init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
