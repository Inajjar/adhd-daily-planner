import 'package:cloud_functions/cloud_functions.dart';

class PremiumAiService {
  PremiumAiService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> generatePrioritySuggestions({
    required String brainDump,
    String? model,
  }) async {
    final result = await _functions
        .httpsCallable('generatePrioritySuggestions')
        .call(<String, dynamic>{'brainDump': brainDump, 'model': model});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> detectOverwhelm({
    required List<Map<String, dynamic>> tasks,
    String? model,
  }) async {
    final result = await _functions.httpsCallable('detectOverwhelm').call(
      <String, dynamic>{'tasks': tasks, 'model': model},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> generateMicroSteps({
    required String taskTitle,
    String? model,
  }) async {
    final result = await _functions.httpsCallable('generateMicroSteps').call(
      <String, dynamic>{'taskTitle': taskTitle, 'model': model},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> generateDailyPlan({
    required List<Map<String, dynamic>> tasks,
    required String currentEnergy,
    String? model,
  }) async {
    final result = await _functions.httpsCallable('generateDailyPlan').call(
      <String, dynamic>{
        'tasks': tasks,
        'currentEnergy': currentEnergy,
        'model': model,
      },
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> rescheduleTasks({
    required List<Map<String, dynamic>> tasks,
    String? model,
  }) async {
    final result = await _functions.httpsCallable('rescheduleTasks').call(
      <String, dynamic>{'tasks': tasks, 'model': model},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> generateSmartReminders({
    required List<Map<String, dynamic>> tasks,
    required String currentEnergy,
    required int streak,
    String? model,
  }) async {
    final result = await _functions
        .httpsCallable('generateSmartReminders')
        .call(<String, dynamic>{
          'tasks': tasks,
          'currentEnergy': currentEnergy,
          'streak': streak,
          'model': model,
        });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
