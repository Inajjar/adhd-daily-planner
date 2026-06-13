import 'package:flutter/material.dart';

import '../../models/routine_item.dart';
import '../../state/app_state.dart';
import '../premium/premium_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => _createRoutine(context),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Routines',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  appState.hasPremium
                      ? 'Unlimited'
                      : '${appState.routines.length} / 3',
                ),
                const SizedBox(height: 20),
                ...appState.routines.map((routine) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: RoutineCard(
                      routine: routine,
                      onTap: () => _openRoutineDetail(context, routine),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createRoutine(BuildContext context) async {
    if (!appState.canCreateRoutine) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PremiumScreen(appState: appState)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => CreateRoutineDialog(appState: appState),
    );
  }

  Future<void> _openRoutineDetail(
    BuildContext context,
    RoutineItem routine,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => RoutineDetailScreen(appState: appState, routine: routine),
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({super.key, required this.routine, required this.onTap});

  final RoutineItem routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.repeat)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('${routine.tasks.length} tasks'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({
    super.key,
    required this.appState,
    required this.routine,
  });

  final AppState appState;
  final RoutineItem routine;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final currentRoutine = appState.routines.firstWhere(
          (item) => item.id == routine.id,
          orElse: () => routine,
        );

        return Scaffold(
          appBar: AppBar(title: Text(currentRoutine.title)),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentRoutine.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child:
                        currentRoutine.tasks.isEmpty
                            ? const Center(child: Text('No tasks'))
                            : ListView.builder(
                              itemCount: currentRoutine.tasks.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    title: Text(currentRoutine.tasks[index]),
                                    trailing: IconButton(
                                      onPressed: () {
                                        appState.deleteTaskFromRoutine(
                                          routineId: currentRoutine.id,
                                          taskIndex: index,
                                        );
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        () => _showAddTaskDialog(context, currentRoutine),
                    child: const Text('Add'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      appState.startRoutine(currentRoutine);
                      appState.setTab(0);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Start'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      appState.deleteRoutine(currentRoutine.id);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Delete Routine'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddTaskDialog(
    BuildContext context,
    RoutineItem routine,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Add'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Task name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  appState.addTaskToRoutine(
                    routineId: routine.id,
                    taskTitle: value,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
  }
}

class CreateRoutineDialog extends StatefulWidget {
  const CreateRoutineDialog({super.key, required this.appState});

  final AppState appState;

  @override
  State<CreateRoutineDialog> createState() => _CreateRoutineDialogState();
}

class _CreateRoutineDialogState extends State<CreateRoutineDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New routine'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Routine name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) {
              return;
            }
            widget.appState.createRoutine(name);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
