import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/focus_session_item.dart';
import '../../models/routine_item.dart';
import '../../models/task_item.dart';
import '../core/firebase_bootstrap.dart';
import 'firebase_firestore_models.dart';

class FirebaseFirestoreService {
  FirebaseFirestoreService(this._bootstrap);

  final FirebaseBootstrap _bootstrap;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  bool get isReady => _bootstrap.isReady;

  Future<void> upsertUserProfile({
    required String userId,
    required bool onboardingComplete,
    required String selectedIntent,
    required String brainDumpText,
    required bool premium,
    required int streak,
    required String notificationTime,
    required String notificationMode,
  }) async {
    if (!isReady) {
      return;
    }

    await _users.doc(userId).set(<String, dynamic>{
      'id': userId,
      'premium': premium,
      'streak': streak,
      'notificationTime': notificationTime,
      'notificationMode': notificationMode,
      'onboardingComplete': onboardingComplete,
      'selectedIntent': selectedIntent,
      'brainDumpText': brainDumpText,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<FirebasePlannerSnapshot?> fetchPlannerSnapshot(String userId) async {
    if (!isReady) {
      return null;
    }

    final userDoc = await _users.doc(userId).get();
    final tasksQuery = await _tasks(userId).orderBy('createdAt').get();
    final routinesQuery = await _routines(userId).orderBy('createdAt').get();
    final focusQuery = await _focusSessions(userId).orderBy('startTime').get();

    final userData = userDoc.data() ?? <String, dynamic>{};
    return FirebasePlannerSnapshot(
      onboardingComplete: userData['onboardingComplete'] as bool? ?? false,
      selectedIntent: userData['selectedIntent'] as String? ?? 'Focus',
      brainDumpText: userData['brainDumpText'] as String? ?? '',
      streak: userData['streak'] as int? ?? 0,
      notificationTime: userData['notificationTime'] as String? ?? '08:30',
      notificationMode: userData['notificationMode'] as String? ?? 'Gentle',
      tasks: tasksQuery.docs.map(_taskFromDoc).toList(),
      routines: routinesQuery.docs.map(_routineFromDoc).toList(),
      focusSessions: focusQuery.docs.map(_focusSessionFromDoc).toList(),
    );
  }

  Future<void> replaceTasks({
    required String userId,
    required List<TaskItem> tasks,
  }) async {
    if (!isReady) {
      return;
    }

    final batch = _firestore.batch();
    final collection = _tasks(userId);
    final existing = await collection.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final task in tasks) {
      batch.set(collection.doc(task.id), _taskToMap(task));
    }
    await batch.commit();
  }

  Future<void> replaceRoutines({
    required String userId,
    required List<RoutineItem> routines,
  }) async {
    if (!isReady) {
      return;
    }

    final batch = _firestore.batch();
    final collection = _routines(userId);
    final existing = await collection.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final routine in routines) {
      batch.set(collection.doc(routine.id), _routineToMap(routine));
    }
    await batch.commit();
  }

  Future<void> replaceFocusSessions({
    required String userId,
    required List<FocusSessionItem> sessions,
  }) async {
    if (!isReady) {
      return;
    }

    final batch = _firestore.batch();
    final collection = _focusSessions(userId);
    final existing = await collection.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final session in sessions) {
      batch.set(collection.doc(session.id), _focusSessionToMap(session));
    }
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _tasks(String userId) =>
      _users.doc(userId).collection('tasks');

  CollectionReference<Map<String, dynamic>> _routines(String userId) =>
      _users.doc(userId).collection('routines');

  CollectionReference<Map<String, dynamic>> _focusSessions(String userId) =>
      _users.doc(userId).collection('focus_sessions');

  TaskItem _taskFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return TaskItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      durationMinutes: data['duration'] as int? ?? 10,
      createdAt: _dateFromValue(data['createdAt']),
      completedAt: _nullableDateFromValue(data['completedAt']),
      scheduledDate: _dateFromValue(data['date']),
      energy: _energyFromString(data['energy'] as String?),
      isCompleted: data['completed'] as bool? ?? false,
      isFocus: data['isFocus'] as bool? ?? false,
    );
  }

  RoutineItem _routineFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return RoutineItem(
      id: doc.id,
      title: data['name'] as String? ?? '',
      tasks: List<String>.from(data['tasks'] as List<dynamic>? ?? <String>[]),
      createdAt: _dateFromValue(data['createdAt']),
    );
  }

  FocusSessionItem _focusSessionFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return FocusSessionItem(
      id: doc.id,
      taskId: data['taskId'] as String? ?? '',
      startTime: _dateFromValue(data['startTime']),
      endTime: _dateFromValue(data['endTime']),
      durationMinutes: data['duration'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _taskToMap(TaskItem task) {
    return <String, dynamic>{
      'id': task.id,
      'title': task.title,
      'duration': task.durationMinutes,
      'completed': task.isCompleted,
      'createdAt': Timestamp.fromDate(task.createdAt),
      'completedAt':
          task.completedAt == null
              ? null
              : Timestamp.fromDate(task.completedAt!),
      'date': Timestamp.fromDate(task.scheduledDate),
      'energy': task.energy.name,
      'isFocus': task.isFocus,
    };
  }

  Map<String, dynamic> _routineToMap(RoutineItem routine) {
    return <String, dynamic>{
      'id': routine.id,
      'name': routine.title,
      'tasks': routine.tasks,
      'createdAt': Timestamp.fromDate(routine.createdAt),
    };
  }

  Map<String, dynamic> _focusSessionToMap(FocusSessionItem session) {
    return <String, dynamic>{
      'id': session.id,
      'taskId': session.taskId,
      'startTime': Timestamp.fromDate(session.startTime),
      'endTime': Timestamp.fromDate(session.endTime),
      'duration': session.durationMinutes,
    };
  }

  TaskEnergy _energyFromString(String? value) {
    switch (value) {
      case 'low':
        return TaskEnergy.low;
      case 'high':
        return TaskEnergy.high;
      default:
        return TaskEnergy.medium;
    }
  }

  DateTime _dateFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.now();
  }

  DateTime? _nullableDateFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}
