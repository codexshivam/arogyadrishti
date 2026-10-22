import 'package:arogya_drishti/core/theme/app_theme.dart';
import 'package:arogya_drishti/core/widgets/arogya_shared_widgets.dart';
import 'package:arogya_drishti/features/auth/auth_screen.dart';
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

      expect(find.text('Officer Sign In'), findsOneWidget);
      expect(find.text('Statutory Surveillance Notice'), findsOneWidget);
      expect(find.text('Verify & Access Portal'), findsOneWidget);
    },
  );
}
