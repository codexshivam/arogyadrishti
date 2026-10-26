import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Staff Profile & Zero-Cost Email Communication Preferences View (`profile_view.dart`).
/// Implements the "Claude Duet" aesthetic (Warm Stone `#F7F6F2`, Slate `#1E2229`, minimal borders)
/// and the 3-State Official Email Verification Flow:
/// - State 1 (No Email): "Add Official Email for Alerts" with text input.
/// - State 2 (Unverified): Amber/orange email badge with "Verify Now" button opening an OTP bottom sheet.
/// - State 3 (Verified): Email with a green Contained Emerald (`#10B981`) checkmark badge.
class ProfileView extends StatefulWidget {
  const ProfileView({
    required this.authViewModel,
    super.key,
  });

  final AuthViewModel authViewModel;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _emailController = TextEditingController(
    text: 'doc@kmc.gov.np',
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLink() async {
    await widget.authViewModel.linkOfficialEmail(_emailController.text);
  }

  void _openVerifyOtpBottomSheet(BuildContext context, String targetEmail) {
    final otpController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NepalGovTheme.elevatedPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'इमेल ओटिपी प्रमाणिकरण (Verify Official Email OTP)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: NepalGovTheme.darkSlateCard,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the 6-digit verification code sent to $targetEmail (valid 15 minutes):',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: NepalGovTheme.mutedInk,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('email_otp_bottom_sheet_input'),
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-Digit Email OTP',
                  hintText: '123456',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                key: const Key('confirm_email_otp_button'),
                onPressed: () async {
                  final ok = await widget.authViewModel
                      .verifyOfficialEmailOtp(otpController.text);
                  if (ok && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NepalGovTheme.containedEmerald,
                ),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Verify Email Code'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authViewModel,
      builder: (BuildContext context, Widget? _) {
        final user = widget.authViewModel.currentUser;
        final email = user?.email;
        final isVerified = user?.isEmailVerified ?? false;
        final err = widget.authViewModel.errorMessage;
        final statusMsg = widget.authViewModel.emailStatusMessage;

        return SingleChildScrollView(
          key: const Key('profile_view'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Accredited Staff Identity Card (Phone Auth Identity)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NepalGovTheme.elevatedPaper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NepalGovTheme.borderStone),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user?.fullNameNe ?? 'सीता महर्जन',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: NepalGovTheme.darkSlateCard,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user?.fullName ?? 'Sita Maharjan'} • ${user?.designation ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: NepalGovTheme.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Primary Identity: +977 SMS OTP (Whitelisted Staff ID: ${user?.id ?? 'staff-fchv-kmc-w17'}) • Palika ${user?.palikaCode ?? '30608'}',
                      style: NepalGovTheme.monoTelemetry(
                        fontSize: 11.5,
                        color: NepalGovTheme.royalNepalBlue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Communication Preferences Section (3-State Email Flow)
              Card(
                key: const Key('communication_preferences_card'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Communication Preferences (सञ्चार तथा सतर्कता सेटिङ)',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: NepalGovTheme.darkSlateCard,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Authentication uses +977 SMS OTP only. System alerts, daily risk reports, and RRT dispatches are delivered at zero SMS cost via Verified Email & In-App Push.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: NepalGovTheme.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // STATE 1: No Email Linked
                      if (email == null || email.isEmpty) ...<Widget>[
                        Container(
                          key: const Key('state1_no_email_section'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NepalGovTheme.warmStoneBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: NepalGovTheme.borderStone),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const Text(
                                'Add Official Email for Alerts',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: NepalGovTheme.darkSlateCard,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: const Key('official_email_input'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Official or Personal Email Address',
                                  hintText: 'officer@kmc.gov.np',
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                key: const Key('link_email_button'),
                                onPressed: _submitEmailLink,
                                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                                label: const Text('Send Verification Code (Email OTP)'),
                              ),
                            ],
                          ),
                        ),
                      ]
                      // STATE 2: Email Linked but Unverified (Amber/Orange + "Verify Now" Bottom Sheet)
                      else if (!isVerified) ...<Widget>[
                        Container(
                          key: const Key('state2_unverified_email_badge'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NepalGovTheme.monsoonAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: NepalGovTheme.monsoonAmber),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: NepalGovTheme.monsoonAmber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: NepalGovTheme.monsoonAmber,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NepalGovTheme.monsoonAmber,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Unverified',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                key: const Key('verify_email_now_button'),
                                onPressed: () =>
                                    _openVerifyOtpBottomSheet(context, email),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NepalGovTheme.monsoonAmber,
                                ),
                                icon: const Icon(Icons.lock_open_rounded, size: 18),
                                label: const Text('Verify Now'),
                              ),
                            ],
                          ),
                        ),
                      ]
                      // STATE 3: Verified Email (Contained Emerald `#10B981` Checkmark Badge)
                      else ...<Widget>[
                        Container(
                          key: const Key('state3_verified_emerald_badge'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NepalGovTheme.containedEmerald
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NepalGovTheme.containedEmerald,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.check_circle_rounded,
                                color: NepalGovTheme.containedEmerald,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: NepalGovTheme.darkSlateCard,
                                      ),
                                    ),
                                    const Text(
                                      'Verified • Zero-Cost Email & In-App Push Alerts Active (#10B981)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: NepalGovTheme.containedEmerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (statusMsg != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          statusMsg,
                          style: NepalGovTheme.monoTelemetry(
                            fontSize: 11.5,
                            color: NepalGovTheme.containedEmerald,
                          ),
                        ),
                      ],
                      if (err != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          err,
                          key: const Key('email_rate_limit_or_error_text'),
                          style: NepalGovTheme.monoTelemetry(
                            fontSize: 11.5,
                            color: NepalGovTheme.outbreakCrimson,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
