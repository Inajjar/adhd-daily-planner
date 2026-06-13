import 'package:firebase_auth/firebase_auth.dart';

import '../core/firebase_bootstrap.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._bootstrap);

  final FirebaseBootstrap _bootstrap;

  User? get currentUser {
    if (!_bootstrap.isReady) {
      return null;
    }
    return FirebaseAuth.instance.currentUser;
  }

  bool get isSignedInAnonymously => currentUser?.isAnonymous ?? false;

  String? get currentUserId => currentUser?.uid;

  Future<UserCredential?> signInAnonymouslyIfNeeded() async {
    if (!_bootstrap.isReady) {
      return null;
    }
    if (FirebaseAuth.instance.currentUser != null) {
      return null;
    }
    return FirebaseAuth.instance.signInAnonymously();
  }
}
