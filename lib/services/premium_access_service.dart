import 'package:cloud_functions/cloud_functions.dart';

class PremiumAccessStatus {
  const PremiumAccessStatus({
    required this.isPremium,
    this.expiresAt,
  });

  final bool isPremium;
  final DateTime? expiresAt;
}

class PremiumAccessService {
  PremiumAccessService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<PremiumAccessStatus> refreshPremiumStatus() async {
    final result = await _functions
        .httpsCallable('refreshPremiumStatus')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);

    return PremiumAccessStatus(
      isPremium: data['isPremium'] == true,
      expiresAt: _parseDate(data['expiresAt'] as String?),
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
}
