import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nidaniq/core/theme/app_theme.dart';
import 'package:nidaniq/core/utils/bs_calendar_formatter.dart';
import 'package:nidaniq/main.dart';
import 'package:nidaniq/models/domain_models.dart';
import 'package:nidaniq/services/budget_device_optimizer.dart';
import 'package:nidaniq/services/camera_exif_stripper.dart';
import 'package:nidaniq/services/geofence_validator.dart';
import 'package:nidaniq/services/local_audit_chain.dart';
import 'package:nidaniq/viewmodels/surveillance_viewmodel.dart';

void main() {
  group('Sovereign Nepal Government Field App — Security, RBAC & Offline Tests', () {
    testWidgets(
      '1. Login screen has ZERO role selection UI, supports +977 and +91, and rejects invalid numbers',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        // CRITICAL: Zero role selection dropdowns, radio buttons, or segmented buttons on login screen
        expect(find.byType(DropdownButton<String>), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.byType(Radio<String>), findsNothing);
        expect(find.byType(SegmentedButton<String>), findsNothing);

        // Rejects invalid international numbers (e.g. US +1)
        await tester.enterText(
          find.byKey(const Key('nepal_phone_input')),
          '+12025550199',
        );
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_error_banner')), findsOneWidget);

        // Accepts Indian phone numbers (+91)
        await tester.enterText(
          find.byKey(const Key('nepal_phone_input')),
          '+919876543210',
        );
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('otp_code_input')), findsOneWidget);
      },
    );

    testWidgets(
      '2. Backend-driven RBAC routes FCHV to FchvHomeView & blocks deep-links to Palika Chief / ULV Override',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        // Enter FCHV +977 number -> Request OTP -> Verify 6-digit OTP
        await tester.enterText(
          find.byKey(const Key('nepal_phone_input')),
          '+9779841000001',
        );
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('otp_code_input')), findsOneWidget);
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        // Automatically routed to FCHV dashboard without any UI role selector
        expect(find.byKey(const Key('fchv_home_view')), findsOneWidget);
        expect(find.byKey(const Key('palika_chief_view')), findsNothing);

        // Attempt unauthorized deep-link to Palika Health Chief dashboard & ULV Override
        deps.router.go('/dashboard/palika-chief');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fchv_home_view')), findsOneWidget);
        expect(find.byKey(const Key('palika_chief_view')), findsNothing);

        deps.router.go('/ulv-override');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fchv_home_view')), findsOneWidget);
      },
    );

    testWidgets(
      '3. Offline inspection queueing encrypts local payload, shows orange banner, and Logout purges all keys',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        // Authenticate as FCHV (+9779841000001)
        await tester.ensureVisible(find.byKey(const Key('request_otp_button')));
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        // Enable Offline Mode and submit field inspection
        deps.surveillanceViewModel.setOfflineMode(true);
        await tester.pumpAndSettle();

        final submitFinder = find.byKey(const Key('submit_inspection_button'));
        await tester.ensureVisible(submitFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        // Verify exact orange banner text
        expect(find.byKey(const Key('offline_queue_banner')), findsOneWidget);
        expect(
          find.text(SurveillanceViewModel.offlineBannerText),
          findsOneWidget,
        );

        // Verify encrypted storage holds ciphertext (not raw JSON) and 1 queued item
        expect(deps.surveillanceViewModel.queuedInspections.length, 1);
        final encryptedSnapshot = deps.storage.debugEncryptedBoxSnapshot;
        expect(encryptedSnapshot.isNotEmpty, isTrue);
        final rawCipher =
            encryptedSnapshot['np_gov_offline_inspections_enc'] ?? '';
        expect(rawCipher.contains('uncovered_plastic_drum'), isFalse);

        // Verify 2G SMS Shortcode 31115 compact payload
        expect(
          deps.surveillanceViewModel.last2gSmsFallbackCode,
          'VEC W17 H25 P9 RDT0',
        );

        // Tap Logout -> verify all secure storage keys & encrypted offline box are purged
        await tester.tap(find.byKey(const Key('logout_button')));
        await tester.pumpAndSettle();

        expect(deps.authViewModel.isAuthenticated, isFalse);
        expect(deps.storage.debugSecureKeystoreSnapshot.isEmpty, isTrue);
        expect(deps.storage.debugEncryptedBoxSnapshot.isEmpty, isTrue);
        expect(find.byKey(const Key('nepal_phone_input')), findsOneWidget);
      },
    );

    test(
      '4. In-memory CameraExifStripperService removes JPEG APP1 EXIF segment and computes 64-bit dHash',
      () {
        const stripper = CameraExifStripperService();
        final rawJpegWithExif = Uint8List.fromList(<int>[
          0xFF, 0xD8, // SOI
          0xFF, 0xE1, 0x00, 0x0E, // APP1 marker + length 14
          0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
          0x47, 0x50, 0x53, 0x32, 0x37, 0x37, // Simulated GPS tag bytes
          0xFF, 0xDA, // SOS
          ...List<int>.generate(64, (int i) => (i * 29 + 7) & 0xFF),
          0xFF, 0xD9, // EOI
        ]);

        expect(stripper.containsAsciiExifHeader(rawJpegWithExif), isTrue);

        final sanitized = stripper.stripExifAndComputeDhash(rawJpegWithExif);
        expect(sanitized.removedExifSegments, 1);
        expect(sanitized.zeroCitizenPiiVerified, isTrue);
        expect(
          stripper.containsAsciiExifHeader(sanitized.sanitizedBytes),
          isFalse,
        );
        expect(sanitized.dhashHex.length, 16);
      },
    );

    testWidgets(
      '5. Palika Health Chief (+9779851000003) routes to PalikaChiefView and signs Focal ULV Override',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('nepal_phone_input')),
          '+9779851000003',
        );
        await tester.ensureVisible(find.byKey(const Key('request_otp_button')));
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('palika_chief_view')), findsOneWidget);

        final approveBtn = find.byKey(const Key('approve_ulv_override_button'));
        await tester.ensureVisible(approveBtn);
        await tester.pumpAndSettle();
        await tester.tap(approveBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ulv_approval_receipt_text')), findsOneWidget);
      },
    );

    test(
      '6. Pillar 1: ST_DWithin(100m), Mock GPS/Time-Tamper Block, Device-Key EXIF Signature & dHash Anti-Replay',
      () {
        const validator = WardGeofenceValidator();

        // Genuine inspection within 100m of target household
        final genuine = validator.validateSubmission(
          compositeWardId: 'NP-P3-D27-30608-W17',
          latitude: 27.7124,
          longitude: 85.3065,
          targetHouseholdLat: 27.7126,
          targetHouseholdLng: 85.3066,
        );
        expect(genuine.within100mHouseholdAnchor, isTrue);
        expect(genuine.submissionBlocked, isFalse);

        // Blocked when Fake GPS / Mock Location app is detected
        final mockBlocked = validator.validateSubmission(
          compositeWardId: 'NP-P3-D27-30608-W17',
          latitude: 27.7124,
          longitude: 85.3065,
          isMockLocationDetected: true,
        );
        expect(mockBlocked.submissionBlocked, isTrue);
        expect(mockBlocked.blockReasonNeEn, contains('Fake/Mock Location App'));

        // Blocked when Device Clock is manually modified (> 300s drift)
        final timeBlocked = validator.validateSubmission(
          compositeWardId: 'NP-P3-D27-30608-W17',
          latitude: 27.7124,
          longitude: 85.3065,
          deviceClockDriftSeconds: 620.0,
        );
        expect(timeBlocked.submissionBlocked, isTrue);
        expect(timeBlocked.blockReasonNeEn, contains('Device Clock'));

        // Blocked when inspector is > 100m away from reported household/container (ST_DWithin)
        final dwithinBlocked = validator.validateSubmission(
          compositeWardId: 'NP-P3-D27-30608-W17',
          latitude: 27.7124,
          longitude: 85.3065,
          targetHouseholdLat: 27.7150,
          targetHouseholdLng: 85.3065,
        );
        expect(dwithinBlocked.within100mHouseholdAnchor, isFalse);
        expect(dwithinBlocked.submissionBlocked, isTrue);

        // Cryptographic EXIF Signature & 64-bit dHash recycled photo detection
        const stripper = CameraExifStripperService();
        final rawJpeg = Uint8List.fromList(<int>[
          0xFF, 0xD8,
          0xFF, 0xE1, 0x00, 0x0A, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0xAA, 0xBB,
          0xFF, 0xDA,
          ...List<int>.generate(96, (int i) => (i * 31 + 11) & 0xFF),
          0xFF, 0xD9,
        ]);
        final firstScan = stripper.stripExifAndComputeDhash(rawJpeg);
        expect(
          firstScan.cryptographicExifSignature.startsWith('NP-EXIF-SIG-'),
          isTrue,
        );
        expect(
          stripper.verifyImagePayloadSignature(
            sanitizedBytes: firstScan.sanitizedBytes,
            dhashHex: firstScan.dhashHex,
            exifAnchorDigestHex: firstScan.exifAnchorDigestHex,
            compositeWardId: 'NP-P3-D27-30608-W17',
            signature: firstScan.cryptographicExifSignature,
          ),
          isTrue,
        );

        // Re-uploading the same snapshot against recentDhashHistory is flagged (Hamming == 0 <= 8)
        final replayScan = stripper.stripExifAndComputeDhash(
          rawJpeg,
          recentDhashHistory: <String>[firstScan.dhashHex],
        );
        expect(replayScan.recycledPhotoBlocked, isTrue);
        expect(replayScan.minHammingDistanceFromHistory, 0);
      },
    );

    test(
      '7. Pillars 2, 3, 4 & 5: Status Pill, ENC31115 Token, Dual BS/AD Date, 48dp Theme, Blockchain Audit Chain & Budget Auto-Vacuum',
      () {
        // Pillar 3: Dual BS Devanagari & Gregorian AD formatting + 48dp touch target
        expect(
          BsCalendarFormatter.formatOfficialBsAdDual(),
          '२०८३ कार्तिक ९ | 2026-10-26',
        );
        expect(NepalGovTheme.minTouchTargetDp, 48.0);

        // Pillar 2: Encrypted >24h SMS Shortcode Token (`ENC31115:...`)
        const sub = FieldInspectionSubmission(
          clientSubmissionUuid: 'sub-enc-001',
          compositeWardId: 'NP-P3-D27-30608-W17',
          housesInspected: 25,
          housesInfested: 4,
          wetContainersInspected: 40,
          positiveContainers: 9,
          pupaeCount: 12,
          containerType: 'uncovered_plastic_drum',
          waterMatrix: 'clean_non_potable',
          larvicideApplied: 'Bti',
          latitude: 27.7124,
          longitude: 85.3065,
          createdAtBs: '2083-07-09 BS | २०८३ कार्तिक ९',
        );
        final encToken = sub.toEncryptedSmsShortcodeToken();
        expect(encToken.startsWith('ENC31115:'), isTrue);
        expect(encToken.length <= 160, isTrue);

        // Pillar 4: Immutable Blockchain-Style Audit Trail
        final chain = LocalTamperEvidentAuditChain();
        chain.appendAction(
          actionType: 'RRT_VAN_DISPATCHED',
          actorId: 'staff-ward-kmc-w17',
          actorRole: 'ward_health_officer',
          targetResourceId: 'RRT-KMC-01->W17',
          summary: 'Dispatched RRT van',
        );
        expect(chain.entries.length, 2);
        expect(chain.verifyChainIntegrity(), isTrue);

        // Pillar 5: Budget Device Optimizer (Low-Power Fused Location & Auto-Vacuum)
        final optimizer = BudgetDeviceOptimizerService(maxRetainedSyncedRecords: 3);
        optimizer.updateBatteryLevel(15);
        expect(optimizer.lowPowerFusedLocationActive, isTrue);
        final pruned = optimizer.autoVacuumSyncedHistory<int>(
          <int>[1, 2, 3, 4, 5, 6, 7],
        );
        expect(pruned.length, 3);
        expect(optimizer.totalVacuumedRecords, 4);
        expect(optimizer.reclaimedStorageBytes, greaterThan(0));
      },
    );

    testWidgets(
      '8. Pillars 4 & 6 UI: 1-Tap GIOMS Ward Outbreak Brief, FCHV Larvae Socratic Guide & 1-Tap Palika IT Officer Escalation',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        // Login as FCHV (+9779841000001) -> test Offline Status Pill, Socratic Quiz & 1-Tap Palika IT Escalation
        await tester.ensureVisible(find.byKey(const Key('request_otp_button')));
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('offline_status_pill')), findsOneWidget);
        expect(find.text('Offline • 0 reports saved locally'), findsOneWidget);

        // Scroll to Interactive FCHV Guide & tap Aedes quiz option
        final aedesOption = find.byKey(const Key('quiz_option_aedes'));
        await tester.ensureVisible(aedesOption);
        await tester.pumpAndSettle();
        await tester.tap(aedesOption);
        await tester.pumpAndSettle();
        expect(find.textContaining('सही उत्तर! (Correct!)'), findsOneWidget);

        // Tap 1-Tap Palika IT Officer Escalation button
        final itBtn = find.byKey(const Key('one_tap_palika_it_feedback_button'));
        await tester.ensureVisible(itBtn);
        await tester.pumpAndSettle();
        await tester.tap(itBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('palika_it_feedback_receipt_text')),
          findsOneWidget,
        );

        // Logout & Login as Palika Health Chief (+9779851000003) -> test 1-Tap GIOMS Outbreak Brief
        await tester.tap(find.byKey(const Key('logout_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('nepal_phone_input')),
          '+9779851000003',
        );
        await tester.ensureVisible(find.byKey(const Key('request_otp_button')));
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        final briefBtn = find.byKey(
          const Key('generate_ward_outbreak_brief_button'),
        );
        await tester.ensureVisible(briefBtn);
        await tester.pumpAndSettle();
        await tester.tap(briefBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('gioms_outbreak_brief_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('immutable_audit_chain_card')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '9. Hybrid Auth & Zero-Cost Email Flow: FCHV Onboarding Banner & 3-State ProfileView Email OTP Verification',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        // Confirm LoginScreen has +977 Phone input ONLY and zero email login button
        expect(find.byKey(const Key('nepal_phone_input')), findsOneWidget);
        expect(find.textContaining('Email Login'), findsNothing);

        // Login as FCHV (+9779841000001)
        await tester.ensureVisible(find.byKey(const Key('request_otp_button')));
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        // Verify one-time non-blocking dismissible banner is shown on FCHV home screen
        expect(
          find.byKey(const Key('fchv_email_onboarding_banner')),
          findsOneWidget,
        );
        expect(
          find.text(
            'To receive Palika alerts and reports for free, please link your email address in Settings.',
          ),
          findsOneWidget,
        );

        // Tap "Settings" on the banner to open ProfileView (`/profile`)
        await tester.tap(
          find.byKey(const Key('open_profile_settings_from_banner_button')),
        );
        await tester.pumpAndSettle();

        // State 1 (No Email): "Add Official Email for Alerts"
        expect(find.byKey(const Key('profile_view')), findsOneWidget);
        expect(
          find.byKey(const Key('state1_no_email_section')),
          findsOneWidget,
        );
        expect(find.text('Add Official Email for Alerts'), findsOneWidget);

        // Enter official email and tap Link Email -> transitions to State 2 (Unverified Amber + Verify Now)
        await tester.enterText(
          find.byKey(const Key('official_email_input')),
          'sita.fchv@kmc.gov.np',
        );
        await tester.tap(find.byKey(const Key('link_email_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('state2_unverified_email_badge')),
          findsOneWidget,
        );
        expect(find.text('sita.fchv@kmc.gov.np'), findsOneWidget);
        expect(find.text('Verify Now'), findsOneWidget);

        // Tap "Verify Now" -> opens OTP entry bottom sheet
        await tester.tap(find.byKey(const Key('verify_email_now_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('email_otp_bottom_sheet_input')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('email_otp_bottom_sheet_input')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('confirm_email_otp_button')));
        await tester.pumpAndSettle();

        // State 3 (Verified): Contained Emerald (#10B981) checkmark badge
        expect(
          find.byKey(const Key('state3_verified_emerald_badge')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Verified • Zero-Cost Email'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '10. Dynamic Spatial Context: Zero Defaulting, Pokhara GPS Resolution, Encrypted Hive Offline Cache & Cascading LocationPicker',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );

        // 1. Zero Defaulting: If GPS permission is denied and no Hive cache exists, location is null
        final deniedLoc = await deps.locationNotifier.resolvePhysicalLocation(
          simulatePermissionDenied: true,
        );
        expect(deniedLoc, isNull);
        expect(
          deps.locationNotifier.state.requiresManualPalikaOnboarding,
          isTrue,
        );

        // 2. Resolve physical location in Pokhara (28.2096, 83.9595) -> never defaults to Kathmandu
        final pokharaLoc = await deps.locationNotifier.resolvePhysicalLocation(
          simulatedLat: 28.2096,
          simulatedLng: 83.9595,
        );
        expect(pokharaLoc, isNotNull);
        expect(pokharaLoc!.compositeWardId, 'NP-P4-D40-40307-W06');
        expect(pokharaLoc.palikaCode, '40307');
        expect(pokharaLoc.palikaNameNp, 'पोखरा महानगरपालिका');
        expect(
          pokharaLoc.dashboardHeaderLabel,
          'Current Location: Ward 6, Pokhara Metro',
        );

        // Verify MapViewModel automatically moved camera bounding box & sorted NHFR hospitals by ST_Distance
        expect(deps.mapViewModel.selectedWard.palikaCode, '40307');
        expect(
          deps.mapViewModel.nearestNhfrHospital!.nhfrCode,
          'NHFR-40307-001',
        );

        // 3. Offline Valley Fallback (e.g. Dolpa/Karnali): restores last resolved composite_ward_id from encrypted Hive storage
        final restoredLoc =
            await deps.locationNotifier.restoreFromEncryptedHiveOfflineCache();
        expect(restoredLoc, isNotNull);
        expect(restoredLoc!.compositeWardId, 'NP-P4-D40-40307-W06');
        expect(deps.locationNotifier.state.isOfflineFallback, isTrue);

        // 4. Render App -> Login -> Verify reactive Dashboard Header & Cascading LocationPicker Modal
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('request_otp_button')));
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Current Location: Ward 6, Pokhara Metro'),
          findsOneWidget,
        );

        // Open Cascading LocationPicker modal (`Province -> District -> Palika -> Ward`)
        await tester.tap(find.byKey(const Key('open_location_picker_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('cascading_location_picker_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('location_picker_province_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('location_picker_district_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('location_picker_palika_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('location_picker_ward_dropdown')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '11. Admins and Municipality Admins access field viewer but cannot add field visit records',
      (WidgetTester tester) async {
        final deps = SovereignAppDependencies.create(
          useInMemoryStorageForTests: true,
        );
        await tester.pumpWidget(NidanIqNepalSovereignApp(dependencies: deps));
        await tester.pumpAndSettle();

        // 1. Authenticate as Federal Admin (+919876543210)
        await tester.enterText(
          find.byKey(const Key('nepal_phone_input')),
          '+919876543210',
        );
        await tester.tap(find.byKey(const Key('request_otp_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('verify_otp_submit_button')));
        await tester.pumpAndSettle();

        // App routes to field viewer dashboard shell
        expect(find.byKey(const Key('fchv_home_view')), findsOneWidget);

        // Submitting field inspection is RESTRICTED:
        expect(
          find.byKey(const Key('admin_inspection_restricted_banner')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('submit_inspection_button')), findsNothing);

        // All other viewer features (status pill, guides, maps, offline switch) remain identical and active
        expect(find.byKey(const Key('offline_status_pill')), findsOneWidget);
        expect(find.byKey(const Key('offline_mode_switch')), findsOneWidget);
      },
    );
  });
}
