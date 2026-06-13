import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/planning_insight.dart';
import '../../models/task_item.dart';
import '../../state/app_state.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../premium/premium_screen.dart';
import '../../widgets/tutorial_wrapper.dart';

final GlobalKey _progressCardKey = GlobalKey(debugLabel: 'today-progress');
final GlobalKey _dailyPlanKey = GlobalKey(debugLabel: 'today-daily-plan');
final GlobalKey _brainDumpKey = GlobalKey(debugLabel: 'today-brain-dump');
final GlobalKey _overwhelmedKey = GlobalKey(debugLabel: 'today-overwhelmed');
final GlobalKey _energyMatchingKey = GlobalKey(debugLabel: 'today-energy');
final GlobalKey _firstTaskKey = GlobalKey(debugLabel: 'today-first-task');
final GlobalKey _fabKey = GlobalKey(debugLabel: 'today-fab');

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final tasks = appState.todayTasks;
        final completedCount = appState.completedTasksToday;

        return TutorialWrapper(
          tutorialId: 'today_home',
          steps: _tutorialSteps(appState),
          child: Scaffold(
            floatingActionButton: FloatingActionButton(
              key: _fabKey,
              heroTag: null,
              onPressed: () => _openAddTask(context),
              child: const Icon(Icons.add),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Today',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      _Pill(label: '${appState.streak}d'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    key: _progressCardKey,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$completedCount/${tasks.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: appState.todayProgress,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (appState.hasDailyAiPlan &&
                      appState.dailyFocusTasks.isNotEmpty)
                    _DailyAiPlanCard(
                      key: ValueKey(
                        'daily-plan-${appState.currentEnergy.name}-${appState.completedTasksToday}-${appState.totalTasksToday}',
                      ),
                      markerKey: _dailyPlanKey,
                      appState: appState,
                    )
                  else
                    _LockedPremiumCard(
                      markerKey: _dailyPlanKey,
                      title: 'Daily AI Plan',
                      subtitle: 'Unlock your top tasks for today.',
                      onPressed: () => _openPremium(context),
                    ),
                  const SizedBox(height: 16),
                  if (appState.hasSmartReminders)
                    _SmartReminderCard(
                      key: ValueKey(
                        'smart-reminder-${appState.currentEnergy.name}-${appState.completedTasksToday}-${appState.totalTasksToday}',
                      ),
                      appState: appState,
                    )
                  else
                    _LockedPremiumCard(
                      title: 'Smart Reminder',
                      subtitle: 'Unlock the next best nudge.',
                      onPressed: () => _openPremium(context),
                    ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: _brainDumpKey,
                              onPressed: () => _openBrainDump(context),
                              icon: const Icon(Icons.psychology_alt_outlined),
                              label: const Text('Brain Dump'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: _overwhelmedKey,
                              onPressed: () => _openOverwhelmed(context),
                              icon: const Icon(Icons.favorite_outline),
                              label: const Text('Overwhelmed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openEmergencyMode(context),
                          icon: const Icon(Icons.warning_amber_outlined),
                          label: const Text('Emergency Mode'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (appState.hasEnergyMatching)
                    _EnergyMatchingCard(
                      key: _energyMatchingKey,
                      appState: appState,
                    )
                  else
                    _LockedPremiumCard(
                      markerKey: _energyMatchingKey,
                      title: 'Energy Matching',
                      subtitle: 'Unlock task matching for your energy.',
                      onPressed: () => _openPremium(context),
                    ),
                  const SizedBox(height: 16),
                  if (appState.hasAutoRescheduler &&
                      appState.todayTasks.any((task) => !task.isCompleted))
                    _AutoReschedulerCard(
                      key: ValueKey(
                        'auto-rescheduler-${appState.completedTasksToday}-${appState.totalTasksToday}',
                      ),
                      appState: appState,
                    )
                  else if (appState.todayTasks.any((task) => !task.isCompleted))
                    _LockedPremiumCard(
                      title: 'Auto Rescheduler',
                      subtitle: 'Unlock tomorrow planning.',
                      onPressed: () => _openPremium(context),
                    ),
                  const SizedBox(height: 18),
                  if (tasks.isEmpty)
                    const _EmptyTodayState()
                  else
                    ...tasks.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: KeyedSubtree(
                          key: entry.key == 0 ? _firstTaskKey : null,
                          child: Dismissible(
                            key: ValueKey(entry.value.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE7E5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.delete_outline),
                            ),
                            onDismissed:
                                (_) => appState.deleteTask(entry.value.id),
                            child: TaskCard(
                              task: entry.value,
                              onToggle: () => appState.toggleTask(entry.value),
                              onStart:
                                  () => _openFocusMode(context, entry.value),
                              onEdit: () => _openEditTask(context, entry.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<CoachMarkStep> _tutorialSteps(AppState appState) {
    return <CoachMarkStep>[
      CoachMarkStep(
        targetKey: _progressCardKey,
        title: 'Progress',
        description: 'See what is done.',
      ),
      if (appState.hasDailyAiPlan && appState.dailyFocusTasks.isNotEmpty)
        CoachMarkStep(
          targetKey: _dailyPlanKey,
          title: 'Focus',
          description: 'See your top tasks.',
        ),
      CoachMarkStep(
        targetKey: _brainDumpKey,
        title: 'Brain Dump',
        description: 'Clear your head fast.',
      ),
      CoachMarkStep(
        targetKey: _overwhelmedKey,
        title: 'Overwhelmed',
        description: 'Get one next step.',
      ),
      if (appState.hasEnergyMatching)
        CoachMarkStep(
          targetKey: _energyMatchingKey,
          title: 'Energy',
          description: 'Match tasks to energy.',
        ),
      CoachMarkStep(
        targetKey: _firstTaskKey,
        title: 'Tasks',
        description: 'Tap to edit or start.',
      ),
      CoachMarkStep(
        targetKey: _fabKey,
        title: 'Add',
        description: 'Add a task fast.',
      ),
    ];
  }

  Future<void> _openAddTask(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TaskEditorSheet(appState: appState),
    );
  }

  Future<void> _openEditTask(BuildContext context, TaskItem task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TaskEditorSheet(appState: appState, task: task),
    );
  }

  Future<void> _openBrainDump(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BrainDumpScreen(appState: appState)),
    );
  }

  Future<void> _openPremium(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PremiumScreen(appState: appState)),
    );
  }

  Future<void> _openOverwhelmed(BuildContext context) async {
    if (!appState.hasOverwhelmDetector) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PremiumScreen(appState: appState)),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => OverwhelmedScreen(appState: appState)),
    );
  }

  Future<void> _openFocusMode(BuildContext context, TaskItem task) async {
    appState.markFocus(task);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FocusModeScreen(task: task, appState: appState),
      ),
    );
  }

  Future<void> _openEmergencyMode(BuildContext context) async {
    if (!appState.hasAdhdEmergencyMode) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PremiumScreen(appState: appState)),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EmergencyModeScreen(appState: appState),
      ),
    );
  }

}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onStart,
    required this.onEdit,
  });

  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onStart;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: task.isFocus ? const Color(0xFFEAF3FF) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(99),
                child: Icon(
                  task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: task.isCompleted ? Colors.green : Colors.black54,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color:
                            task.isCompleted ? Colors.black38 : Colors.black87,
                        decoration:
                            task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.durationMinutes} min',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: task.isCompleted ? null : onStart,
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, required this.appState, this.task});

  final AppState appState;
  final TaskItem? task;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _titleController;
  late int _duration;
  late bool _completed;
  List<String> _microSteps = const <String>[];
  bool _isGeneratingMicroSteps = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _duration = widget.task?.durationMinutes ?? 10;
    _completed = widget.task?.isCompleted ?? false;
    if (widget.task != null && widget.appState.hasMicroStepGenerator) {
      _loadMicroSteps(widget.task!.title);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEdit ? 'Edit Task' : 'Add Task',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              filled: true,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          if (_isEdit && widget.appState.hasMicroStepGenerator) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed:
                  _isGeneratingMicroSteps
                      ? null
                      : () => _loadMicroSteps(
                        _titleController.text.trim().isEmpty
                            ? widget.task!.title
                            : _titleController.text.trim(),
                      ),
              child:
                  _isGeneratingMicroSteps
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Generate Micro-Steps'),
            ),
            if (_microSteps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFF8FBFF),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Micro-Step Generator',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._microSteps.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('${entry.key + 1}. ${entry.value}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else if (_isEdit) ...[
            const SizedBox(height: 16),
            _PremiumLockRow(
              title: 'Micro-Steps',
              subtitle: 'Premium',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PremiumScreen(appState: widget.appState),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _duration,
            decoration: const InputDecoration(
              labelText: 'Duration',
              filled: true,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            items:
                const <int>[5, 10, 15, 30, 60]
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value min'),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _duration = value ?? 10),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              value: _completed,
              contentPadding: EdgeInsets.zero,
              title: const Text('Completed'),
              onChanged: (value) => setState(() => _completed = value),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_isEdit ? 'Cancel' : 'Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEdit ? 'Save' : 'Save'),
                ),
              ),
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.appState.deleteTask(widget.task!.id);
                  Navigator.of(context).pop();
                },
                child: const Text('Delete'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    if (_isEdit) {
      widget.appState.updateTask(
        taskId: widget.task!.id,
        title: title,
        durationMinutes: _duration,
        completed: _completed,
      );
    } else {
      widget.appState.addTask(title: title, durationMinutes: _duration);
    }
    Navigator.of(context).pop();
  }

  Future<void> _loadMicroSteps(String title) async {
    setState(() => _isGeneratingMicroSteps = true);
    final steps = await widget.appState.generateMicroStepsWithAi(title);
    if (!mounted) {
      return;
    }
    setState(() {
      _microSteps = steps;
      _isGeneratingMicroSteps = false;
    });
  }
}

class BrainDumpScreen extends StatefulWidget {
  const BrainDumpScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends State<BrainDumpScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TaskItem> _generatedTasks = const <TaskItem>[];
  PlanningInsight? _planningInsight;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.appState.brainDumpText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brain Dump')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appState.hasPremium
                    ? 'Unlimited brain dumps'
                    : 'Free plan: 1 use per day',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Write everything you need to do...',
                  filled: true,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isGenerating ? null : _generate,
                child:
                    _isGenerating
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Generate'),
              ),
              if (!widget.appState.canUseBrainDumpToday &&
                  !widget.appState.hasPremium) ...[
                const SizedBox(height: 12),
                const Text(
                  'Limit reached today.',
                ),
              ],
              if (!widget.appState.hasAiPrioritySuggestions) ...[
                const SizedBox(height: 12),
                _PremiumLockRow(
                  title: 'AI Suggestions',
                  subtitle: 'Premium',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder:
                            (_) => PremiumScreen(appState: widget.appState),
                      ),
                    );
                  },
                ),
              ],
              if (_generatedTasks.isNotEmpty) ...[
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      if (_planningInsight != null &&
                          widget.appState.hasAiPrioritySuggestions)
                        _PlanningInsightCard(insight: _planningInsight!),
                      ..._generatedTasks.map((task) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(task.title),
                          subtitle: Text('${task.durationMinutes} min'),
                        );
                      }),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    widget.appState.addTasksToToday(_generatedTasks);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Add To Today'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    final allowed = await widget.appState.registerBrainDumpUse();
    if (!allowed) {
      setState(() {});
      return;
    }
    setState(() => _isGenerating = true);
    final generatedTasks = widget.appState.generatePlanFromBrainDump(
      _controller.text,
    );
    final planningInsight =
        widget.appState.hasAiPrioritySuggestions
            ? await widget.appState.generatePlanningInsightWithAi(
              _controller.text,
            )
            : null;
    if (!mounted) {
      return;
    }
    setState(() {
      _generatedTasks = generatedTasks;
      _planningInsight = planningInsight;
      _isGenerating = false;
    });
  }
}

class OverwhelmedScreen extends StatefulWidget {
  const OverwhelmedScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<OverwhelmedScreen> createState() => _OverwhelmedScreenState();
}

class _OverwhelmedScreenState extends State<OverwhelmedScreen> {
  OverwhelmRecommendation? _recommendation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final recommendation = _recommendation;
    final task = recommendation?.task;

    return Scaffold(
      appBar: AppBar(title: const Text('Overwhelmed')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : recommendation == null || task == null
                  ? const Center(
                    child: Text('No open task to suggest right now.'),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended task',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: const Color(0xFFF3F8FF),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${recommendation.estimatedMinutes} min • ${_energyLabel(recommendation.energy)} energy',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ignore everything else.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(recommendation.explanation),
                      const SizedBox(height: 20),
                      Text(
                        'First micro-step',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(recommendation.microStep),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder:
                                  (_) => FocusModeScreen(
                                    task: task,
                                    appState: appState,
                                  ),
                            ),
                          );
                        },
                        child: const Text('Start Task'),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Future<void> _loadRecommendation() async {
    final recommendation =
        await widget.appState.generateOverwhelmRecommendationWithAi();
    if (!mounted) {
      return;
    }
    setState(() {
      _recommendation = recommendation;
      _isLoading = false;
    });
  }
}

class _PlanningInsightCard extends StatelessWidget {
  const _PlanningInsightCard({required this.insight});

  final PlanningInsight insight;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFFF3F8FF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Priority Suggestions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _PriorityGroup(
              title: 'High',
              tasks:
                  insight.tasks
                      .where((task) => task.priority == PriorityLevel.high)
                      .toList(),
            ),
            const SizedBox(height: 8),
            _PriorityGroup(
              title: 'Medium',
              tasks:
                  insight.tasks
                      .where((task) => task.priority == PriorityLevel.medium)
                      .toList(),
            ),
            const SizedBox(height: 8),
            _PriorityGroup(
              title: 'Low',
              tasks:
                  insight.tasks
                      .where((task) => task.priority == PriorityLevel.low)
                      .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              insight.suggestion,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyAiPlanCard extends StatefulWidget {
  const _DailyAiPlanCard({super.key, required this.appState, this.markerKey});

  final AppState appState;
  final Key? markerKey;

  @override
  State<_DailyAiPlanCard> createState() => _DailyAiPlanCardState();
}

class _DailyAiPlanCardState extends State<_DailyAiPlanCard> {
  DailyPlanRecommendation? _plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void didUpdateWidget(covariant _DailyAiPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState.currentEnergy != widget.appState.currentEnergy ||
        oldWidget.appState.totalTasksToday != widget.appState.totalTasksToday ||
        oldWidget.appState.completedTasksToday !=
            widget.appState.completedTasksToday) {
      _loadPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan ?? widget.appState.generateDailyPlanFallback();
    return Card(
      key: widget.markerKey,
      color: const Color(0xFFF3F8FF),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...plan.tasks.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${entry.key + 1}. ${entry.value.title} (${entry.value.durationMinutes} min)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPlan() async {
    final plan = await widget.appState.generateDailyPlanWithAi();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = plan;
    });
  }
}

class _SmartReminderCard extends StatefulWidget {
  const _SmartReminderCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<_SmartReminderCard> createState() => _SmartReminderCardState();
}

class _SmartReminderCardState extends State<_SmartReminderCard> {
  ReminderSuggestion? _reminder;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminder ?? widget.appState.smartReminderFallback;
    return Card(
      color: const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              reminder.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _loadReminder,
                    child: Text(_isLoading ? '...' : reminder.actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadReminder() async {
    setState(() => _isLoading = true);
    final reminder = await widget.appState.generateSmartReminderWithAi();
    if (!mounted) {
      return;
    }
    setState(() {
      _reminder = reminder;
      _isLoading = false;
    });
  }
}

class _AutoReschedulerCard extends StatefulWidget {
  const _AutoReschedulerCard({super.key, required this.appState});

  final AppState appState;

  @override
  State<_AutoReschedulerCard> createState() => _AutoReschedulerCardState();
}

class _AutoReschedulerCardState extends State<_AutoReschedulerCard> {
  bool _isApplying = false;
  ReschedulePlan? _lastPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto Rescheduler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Plan tomorrow fast.'),
            if (_lastPlan != null) ...[
              const SizedBox(height: 12),
              ..._lastPlan!.tomorrow
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${item.task.title}'),
                    ),
                  ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _isApplying ? null : _applyReschedule,
              child: Text(_isApplying ? 'Rescheduling...' : 'Plan Tomorrow'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyReschedule() async {
    setState(() => _isApplying = true);
    final plan = await widget.appState.applyAutoRescheduler();
    if (!mounted) {
      return;
    }
    setState(() {
      _lastPlan = plan;
      _isApplying = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tomorrow is ready with ${plan.tomorrow.length} prioritized tasks.',
        ),
      ),
    );
  }
}

class _EnergyMatchingCard extends StatelessWidget {
  const _EnergyMatchingCard({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Energy Matching',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Current Energy'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children:
                  TaskEnergy.values.map((energy) {
                    return ChoiceChip(
                      label: Text(_energyLabel(energy)),
                      selected: appState.currentEnergy == energy,
                      onSelected: (_) => appState.setCurrentEnergy(energy),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Recommended now',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...appState.energyMatchedTasks
                .take(3)
                .map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '✓ ${task.title} • ${task.durationMinutes} min',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _LockedPremiumCard extends StatelessWidget {
  const _LockedPremiumCard({
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.markerKey,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final Key? markerKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: markerKey,
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: onPressed,
                  icon: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF667085),
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Open Premium',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _PremiumLockRow extends StatelessWidget {
  const _PremiumLockRow({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.lock_outline),
            color: const Color(0xFF667085),
            visualDensity: VisualDensity.compact,
            tooltip: 'Open Premium',
          ),
        ],
      ),
    );
  }
}

class _PriorityGroup extends StatelessWidget {
  const _PriorityGroup({required this.title, required this.tasks});

  final String title;
  final List<PrioritizedTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (tasks.isEmpty)
          const Text('No tasks')
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${task.title} • ${task.durationMinutes} min • ${_energyLabel(task.energy)} energy',
              ),
            ),
          ),
      ],
    );
  }
}

String _energyLabel(TaskEnergy energy) {
  switch (energy) {
    case TaskEnergy.low:
      return 'Low';
    case TaskEnergy.medium:
      return 'Medium';
    case TaskEnergy.high:
      return 'High';
  }
}

class EmergencyModeScreen extends StatelessWidget {
  const EmergencyModeScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final task = appState.emergencyTask;

    return Scaffold(
      appBar: AppBar(title: const Text('ADHD Emergency Mode')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              task == null
                  ? const Center(child: Text('No task available right now.'))
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Everything feels impossible.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text('Ignore everything else.'),
                      const SizedBox(height: 24),
                      Card(
                        color: const Color(0xFFFFF7E8),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text('${task.durationMinutes} min'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'One step only',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appState.emergencyStep,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          appState.markFocus(task);
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder:
                                  (_) => FocusModeScreen(
                                    task: task,
                                    appState: appState,
                                  ),
                            ),
                          );
                        },
                        child: const Text('Start This Only'),
                      ),
                      const SizedBox(height: 12),
                      Text('Next step: ${appState.emergencyNextStep}'),
                    ],
                  ),
        ),
      ),
    );
  }
}

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({
    super.key,
    required this.task,
    required this.appState,
  });

  final TaskItem task;
  final AppState appState;

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  Timer? _timer;
  late final DateTime _startedAt;
  late int _remainingSeconds;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _remainingSeconds = widget.task.durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.task.durationMinutes * 60;
    final progress =
        totalSeconds == 0 ? 0.0 : 1 - (_remainingSeconds / totalSeconds);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        final shouldExit = await _confirmExit(context);
        if (shouldExit && context.mounted) {
          widget.appState.clearFocus();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () async {
                      final shouldExit = await _confirmExit(context);
                      if (shouldExit && context.mounted) {
                        widget.appState.clearFocus();
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Exit'),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.task.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  borderRadius: BorderRadius.circular(99),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _togglePause,
                        child: Text(_isPaused ? 'Resume' : 'Pause'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _completeSession,
                        child: const Text('Complete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) {
        return;
      }
      if (_remainingSeconds == 0) {
        _completeSession();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _completeSession() {
    _timer?.cancel();
    final elapsedSeconds =
        (widget.task.durationMinutes * 60) - _remainingSeconds;
    widget.appState.completeFocusSession(
      task: widget.task,
      startTime: _startedAt,
      elapsedSeconds: elapsedSeconds,
    );
    Navigator.of(context).pop();
  }

  Future<bool> _confirmExit(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Exit focus mode?'),
                content: const Text(
                  'This session will not be saved.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Stay'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EmptyTodayState extends StatelessWidget {
  const _EmptyTodayState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 40),
            const SizedBox(height: 12),
            Text('No tasks', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Tap + or Brain Dump.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
