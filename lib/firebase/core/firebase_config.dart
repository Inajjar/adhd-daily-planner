class FirebaseConfig {
  const FirebaseConfig({required this.enabled});

  final bool enabled;

  static const current = FirebaseConfig(enabled: true);
}
