import 'package:arogya_drishti/core/network/api_client.dart';
import 'package:arogya_drishti/core/theme/app_theme.dart';
import 'package:arogya_drishti/core/widgets/arogya_shared_widgets.dart';
import 'package:arogya_drishti/features/auth/auth_screen.dart';
import 'package:arogya_drishti/features/support/support_screen.dart';
import 'package:arogya_drishti/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plump_icons/plump_icons.dart';

class _FakeSupportApiClient extends ArogyaApiClient {
  _FakeSupportApiClient() : super(baseUrl: 'http://localhost:8080');

  @override
  Future<Map<String, dynamic>> fetchSupportOverview({String? lgdCode}) async {
    return <String, dynamic>{
      'emergency_hotlines': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'NCDC Vector Control Room',
          'subtitle': '1800-11-VECTOR',
          'number': '1800114377',
          'icon_type': 'phone',
          'is_primary': true,
          'badge': 'NATIONAL',
        },
      ],
      'nodal_officers': <Map<String, dynamic>>[
        <String, dynamic>{
          'initials': 'RK',
          'name': 'Dr. R. K. Sharma',
          'role': 'District Nodal Representative (Chandigarh)',
          'phone': '911123900110',
          'email': 'shivam@revlet.me',
          'color_hex': '0xFF8B0014',
          'is_chat': false,
          'source': '3_Staff_Directory / api.data.gov.in',
        },
      ],
      'available_wards': <Map<String, dynamic>>[
        <String, dynamic>{
          'lgd_code': '0404400017',
          'ward_name': 'Sector 22-B',
          'district': 'Chandigarh',
          'state': 'Chandigarh',
          'risk_tier': 'CRITICAL',
        },
      ],
      'escalation_categories': <String>[
        'Outbreak Cluster Flare-up (High Larval Index)',
        'Stagnant Water / Construction Debris',
      ],
      'severity_levels': <String>[
        'Critical (2h SLA)',
        'High (6h SLA)',
      ],
      'recent_tickets': <Map<String, dynamic>>[],
      'selected_ward': <String, dynamic>{
        'lgd_code': '0404400017',
        'ward_name': 'Sector 22-B',
        'district': 'Chandigarh',
        'state': 'Chandigarh',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> verifyStaff({
    required String uid,
    String? phone,
    String? email,
  }) async {
    final cleanPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.endsWith('9915549458') || cleanPhone.endsWith('9501588795')) {
      return {'status': 'STAFF_VERIFIED', 'officer_profile': {'name': 'Officer'}};
    }
    throw Exception('Phone number or email is not pre-authorized');
  }
}

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
    'AuthScreen renders initial phone input and Send OTP button',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    'AuthScreen displays Phone number not registered snackbar for unregistered phone numbers',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(_FakeSupportApiClient()),
          ],
          child: MaterialApp(
            theme: ArogyaTheme.lightTheme(),
            home: const AuthScreen(),
          ),
        ),
      );

      // Enter an unregistered phone number
      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '9123456780');
      await tester.pump();

      // Tap Send OTP
      await tester.tap(find.text('Send OTP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Expect normal snackbar with 'Phone number not registered'
      expect(find.text('Phone number not registered'), findsOneWidget);
      // OTP field should NOT be revealed
      expect(find.text('Enter 6-Digit Verification Code'), findsNothing);
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
      expect(find.text('ArogyaDrishti'), findsOneWidget);
      expect(find.text('developed and managed by Team Rocket'), findsOneWidget);
      expect(find.byType(PlumpIcon), findsNWidgets(5));

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
          overrides: [
            apiClientProvider.overrideWithValue(_FakeSupportApiClient()),
          ],
          child: MaterialApp(
            theme: ArogyaTheme.lightTheme(),
            home: const SupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Escalations'), findsOneWidget);
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
