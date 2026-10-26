import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// 6-Digit Sparrow SMS / Nepal Telecom OTP Verification Screen.
/// Upon verification, the backend JWT resolves the staff member's statutory role
/// (`fchv`, `ward_health_officer`, `palika_health_chief`, `edcd_nodal`) and `GoRouter`
/// automatically routes to the matching dashboard.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    required this.authViewModel,
    super.key,
  });

  final AuthViewModel authViewModel;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController(text: '208307');

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    final ok = await widget.authViewModel.verifyOtpAndResolveRole(_otpController.text);
    if (ok && mounted) {
      final user = widget.authViewModel.currentUser;
      if (user != null) {
        context.go(user.role.homeRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authViewModel,
      builder: (BuildContext context, Widget? _) {
        final phone = widget.authViewModel.pendingPhone ?? '+9779841000001';
        final error = widget.authViewModel.errorMessage;
        return Scaffold(
          backgroundColor: NepalGovTheme.warmStoneBackground,
          appBar: AppBar(
            title: const Text('OTP प्रमाणीकरण / Verify OTP'),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'मोबाइल नम्बर: $phone',
                            style: NepalGovTheme.monoTelemetry(
                              fontSize: 14,
                              color: NepalGovTheme.darkSlateCard,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sparrow SMS / Nepal Telecom मार्फत प्राप्त ६-अंकको कोड प्रविष्ट गर्नुहोस्।',
                            style: TextStyle(
                              fontSize: 13,
                              color: NepalGovTheme.mutedInk,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('otp_code_input'),
                            controller: _otpController,
                            maxLength: 6,
                            keyboardType: TextInputType.number,
                            style: NepalGovTheme.monoTelemetry(fontSize: 18),
                            decoration: const InputDecoration(
                              labelText: '६-अंकको OTP कोड (6-Digit OTP)',
                              prefixIcon: Icon(Icons.lock_clock_outlined),
                            ),
                          ),
                          if (error != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              error,
                              style: const TextStyle(
                                color: NepalGovTheme.outbreakCrimson,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            key: const Key('verify_otp_submit_button'),
                            onPressed: widget.authViewModel.isLoading
                                ? null
                                : _handleVerifyOtp,
                            icon: const Icon(Icons.verified_user_outlined, size: 18),
                            label: const Text('प्रमाणीकरण गर्नुहोस् / Verify & Enter Dashboard'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
