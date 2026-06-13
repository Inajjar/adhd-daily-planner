import 'package:adhd_daily_planner/app/app.dart';
import 'package:adhd_daily_planner/firebase/core/firebase_bootstrap.dart';
import 'package:adhd_daily_planner/services/iap_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows onboarding entry point', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    await tester.pumpWidget(
      AdhdDailyPlannerApp(
        firebaseBootstrap: FirebaseBootstrap(),
        iapService: IAPService(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ADHD Daily Planner'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
