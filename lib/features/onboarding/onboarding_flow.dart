import 'package:flutter/material.dart';

import '../../models/task_item.dart';
import '../../state/app_state.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.appState});

  final AppState appState;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();
  final TextEditingController _brainDumpController = TextEditingController();

  final List<String> _options = const <String>[
    'Focus',
    'Daily Planning',
    'Routines',
    'Feeling Overwhelmed',
  ];

  int _pageIndex = 0;
  String _selectedOption = 'Focus';
  List<TaskItem> _generatedTasks = const <TaskItem>[];

  @override
  void dispose() {
    _controller.dispose();
    _brainDumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFF8FBFF), Color(0xFFE8F3FF)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADHD Daily Planner',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: (_pageIndex + 1) / 4,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: PageView(
                        controller: _controller,
                        physics: const NeverScrollableScrollPhysics(),
                        children: <Widget>[
                          _buildWelcomeStep(context),
                          _buildNeedHelpStep(context),
                          _buildBrainDumpStep(context),
                          _buildPlanStep(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeStep(BuildContext context) {
    return _StepShell(
      title: 'Start small.',
      subtitle: 'Plan less. Start faster.',
      footer: FilledButton(onPressed: _next, child: const Text('Start')),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFEAF3FF),
              child: Icon(Icons.bolt_rounded, size: 34),
            ),
            Spacer(),
            Text(
              'Plan less.\nStart faster.',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedHelpStep(BuildContext context) {
    return _StepShell(
      title: 'Pick one.',
      subtitle: '',
      footer: FilledButton(onPressed: _next, child: const Text('Next')),
      child: Column(
        children:
            _options.map((option) {
              final selected = option == _selectedOption;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedOption = option),
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF0A84FF) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _iconForOption(option),
                          color: selected ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildBrainDumpStep(BuildContext context) {
    return _StepShell(
      title: 'Brain dump',
      subtitle: 'Write it all.',
      footer: FilledButton(
        onPressed: () {
          setState(() {
            _generatedTasks = widget.appState.generatePlanFromBrainDump(
              _brainDumpController.text,
            );
          });
          _next();
        },
        child: const Text('Next'),
      ),
      child: TextField(
        controller: _brainDumpController,
        maxLines: 12,
        decoration: InputDecoration(
          hintText: 'Type here...',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanStep(BuildContext context) {
    final tasks =
        _generatedTasks.isEmpty
            ? widget.appState.generatePlanFromBrainDump(
              _brainDumpController.text,
            )
            : _generatedTasks;

    return _StepShell(
      title: 'Ready.',
      subtitle: 'These go into Today.',
      footer: FilledButton(
        onPressed:
            widget.appState.isAuthenticating
                ? null
                : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.appState.completeOnboarding(
                      intent: _selectedOption,
                      brainDumpText: _brainDumpController.text.trim(),
                      generatedTasks: tasks,
                    );
                  } catch (_) {
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.appState.authErrorMessage ??
                              'We could not finish setting up your private account.',
                        ),
                      ),
                    );
                  }
                },
        child:
            widget.appState.isAuthenticating
                ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('Add'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.appState.authErrorMessage != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7E5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(widget.appState.authErrorMessage!),
            ),
          ],
          Expanded(
            child: ListView(
              children:
                  tasks.map((task) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.task_alt_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text('${task.durationMinutes} min'),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_pageIndex >= 3) {
      return;
    }
    setState(() => _pageIndex += 1);
    _controller.animateToPage(
      _pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  IconData _iconForOption(String option) {
    switch (option) {
      case 'Daily Planning':
        return Icons.calendar_today_outlined;
      case 'Routines':
        return Icons.repeat_outlined;
      case 'Feeling Overwhelmed':
        return Icons.favorite_outline;
      default:
        return Icons.center_focus_strong_outlined;
    }
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Expanded(child: child),
        const SizedBox(height: 20),
        footer,
      ],
    );
  }
}
