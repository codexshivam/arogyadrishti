import 'package:arogya_drishti/core/theme/app_theme.dart';
import 'package:arogya_drishti/core/widgets/arogya_shared_widgets.dart';
import 'package:arogya_drishti/features/auth/auth_screen.dart';
import 'package:arogya_drishti/features/support/support_screen.dart';
import 'package:arogya_drishti/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Arogya Drishti shared clinical widgets & WHO Breteau Index gauge render accurately',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ArogyaTheme.lightTheme(),
            home: const Scaffold(
              body: Column(
                children: [
                  StatusPillChip(
                    label: 'CRITICAL ZONE',
                    color: ArogyaSpacing.riskCritical,
                  ),
                  VectorDensityGauge(breteauIndex: 28.5),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('CRITICAL ZONE'), findsOneWidget);
      expect(find.textContaining('BI: 28.5'), findsOneWidget);
      expect(find.text('CRITICAL (>20)'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthScreen renders NCVBDC role selector and DPDP Act 2023 badge',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ArogyaTheme.lightTheme(),
            home: const AuthScreen(),
          ),
        ),
      );

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Statutory Surveillance Notice'), findsOneWidget);
      expect(find.text('Verify & Access Portal'), findsOneWidget);
    },
  );

  testWidgets(
    'ArogyaTopShellBar renders as an AppBar with white background and dark overlay',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ArogyaTheme.lightTheme(),
            home: const Scaffold(
              appBar: ArogyaTopShellBar(activeTabIndex: 0),
              body: Center(child: Text('Content')),
            ),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Arogya Drishti'), findsOneWidget);
      expect(find.text('developed and managed by Team Rocket'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(Colors.white));
      expect(appBar.systemOverlayStyle?.statusBarColor, equals(Colors.white));
      expect(appBar.systemOverlayStyle?.statusBarIconBrightness, equals(Brightness.dark));
    },
  );

  testWidgets(
    'SupportScreen renders SOS Hotlines, Escalation Form, and Nodal Directory without infinite width constraints',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ArogyaTheme.lightTheme(),
            home: const SupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Outbreak Emergency SOS Hotline'), findsOneWidget);
      expect(find.text('NCDC Vector Control Room'), findsOneWidget);
      expect(find.text('1800-11-VECTOR'), findsOneWidget);
      expect(find.text('Log Field Issue / Outbreak Alert'), findsOneWidget);
      expect(find.text('Submit Ticket'), findsOneWidget);
      expect(find.text('Recent Tickets & Dispatch Pipeline'), findsOneWidget);
      expect(find.text('Direct Nodal Officer Directory'), findsOneWidget);
      expect(find.text('Dr. R. K. Sharma'), findsOneWidget);
    },
  );

  test('arogyaRouter protects routes and initial location is /auth', () {
    expect(arogyaRouter.routeInformationProvider.value.uri.path, equals('/auth'));
  });
}
