import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../services/tutorial_service.dart';
import '../premium/premium_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.appState});

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
                  'Settings',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'General',
                  items: <String>[
                    'Intent: ${appState.selectedIntent}',
                    'Brain dump: ${appState.brainDumpText.isEmpty ? 'No' : 'Yes'}',
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Notifications',
                  items: <String>[
                    'Time: ${appState.notificationTime}',
                    'Mode: ${appState.notificationMode}',
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Subscription',
                  items: <String>[
                    appState.hasPremium ? 'Premium active' : 'Free plan',
                    appState.hasPremium
                        ? 'Ready'
                        : 'Upgrade',
                  ],
                  actionLabel: 'Premium',
                  onAction: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => PremiumScreen(appState: appState),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Privacy & Sync',
                  items: <String>[
                    appState.isAnonymousAuthenticated
                        ? 'Account: on'
                        : 'Account: off',
                    appState.syncErrorMessage ??
                        (appState.isAnonymousAuthenticated
                            ? 'Backup: on'
                            : 'Backup: off'),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'App',
                  items: <String>[
                    'Ready',
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: appState.resetOnboarding,
                  child: const Text('Onboarding'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await TutorialService.resetAllTutorials();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tutorials reset.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Tutorials'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.items,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<String> items;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
