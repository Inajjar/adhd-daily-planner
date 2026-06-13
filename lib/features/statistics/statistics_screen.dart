import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../premium/premium_screen.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Stats',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                _StatCard(
                  title: 'Today',
                  items: <String>[
                    'Done: ${appState.completedTasksToday}',
                    'Streak: ${appState.streak}',
                  ],
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'This Week',
                  items: <String>[
                    'Done: ${appState.completedTasksThisWeek}',
                  ],
                ),
                const SizedBox(height: 12),
                if (appState.hasPremium)
                  _StatCard(
                    title: 'Premium',
                    items: <String>[
                      'Focus today: ${appState.focusMinutesToday} min',
                      'Focus week: ${appState.focusMinutesThisWeek} min',
                      'Score: ${appState.productivityScore}',
                      'AI reminders: ${appState.hasSmartReminders ? 'on' : 'off'}',
                      'Auto plan: ${appState.hasAutoRescheduler ? 'on' : 'off'}',
                      appState.syncErrorMessage ??
                          'Backup: ${appState.isAnonymousAuthenticated ? 'on' : 'off'}',
                    ],
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          const Text('More stats.'),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder:
                                      (_) => PremiumScreen(appState: appState),
                                ),
                              );
                            },
                            child: const Text('Open Premium'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
