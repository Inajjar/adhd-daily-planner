import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../onboarding/onboarding_flow.dart';
import '../routines/routines_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';
import '../today/today_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (!appState.isOnboardingComplete) {
          return OnboardingFlow(appState: appState);
        }

        if (appState.isAuthenticating ||
            !appState.isAnonymousAuthenticated ||
            appState.authErrorMessage != null) {
          return _AnonymousAuthGate(appState: appState);
        }

        final screens = <Widget>[
          TodayScreen(appState: appState),
          RoutinesScreen(appState: appState),
          StatisticsScreen(appState: appState),
          SettingsScreen(appState: appState),
        ];

        return Scaffold(
          body: Column(
            children: [
              if (appState.syncErrorMessage != null)
                SafeArea(
                  bottom: false,
                  child: MaterialBanner(
                    content: Text(appState.syncErrorMessage!),
                    actions: [
                      TextButton(
                        onPressed: appState.authenticateAnonymously,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: IndexedStack(index: appState.tabIndex, children: screens),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: appState.tabIndex,
            onDestinationSelected: appState.setTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.repeat_outlined),
                selectedIcon: Icon(Icons.repeat),
                label: 'Routines',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnonymousAuthGate extends StatelessWidget {
  const _AnonymousAuthGate({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_open_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Loading',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  appState.authErrorMessage ?? 'Please wait...',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (appState.isAuthenticating)
                  const CircularProgressIndicator()
                else
                  FilledButton(
                    onPressed: appState.authenticateAnonymously,
                    child: const Text('Try Again'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
