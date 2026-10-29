import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Zero-UI Role Selection Login Screen for MoHP / EDCD Teku / 753 Palikas.
/// Strictly accepts ONLY a `+977` Nepali mobile number — NO role dropdowns or radio buttons.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authViewModel,
    super.key,
  });

  final AuthViewModel authViewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(
    text: '+9779841000001',
  );

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    final ok = await widget.authViewModel.requestOtp(_phoneController.text);
    if (ok && mounted) {
      context.go('/verify-otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authViewModel,
      builder: (BuildContext context, Widget? _) {
        final error = widget.authViewModel.errorMessage;
        return Scaffold(
          backgroundColor: NepalGovTheme.warmStoneBackground,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NepalGovTheme.darkSlateCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NepalGovTheme.outbreakCrimson,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'नेपाल सरकार | GoN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '२०८३ कार्तिक ९ BS',
                                    overflow: TextOverflow.ellipsis,
                                    style: NepalGovTheme.monoTelemetry(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'स्वास्थ्य तथा जनसंख्या मन्त्रालय\nइपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा (EDCD Teku)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'NidanIQ Sovereign Vector Surveillance & Early Warning DPI',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const Text(
                                'कर्मचारी प्रमाणीकरण (Staff Authentication)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: NepalGovTheme.darkSlateCard,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'आफ्नो दर्ता भएको मोबाइल नम्बर (+977 / +91) प्रविष्ट गर्नुहोस्।',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: NepalGovTheme.mutedInk,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                key: const Key('nepal_phone_input'),
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: NepalGovTheme.monoTelemetry(fontSize: 15),
                                decoration: const InputDecoration(
                                  labelText: 'मोबाइल नम्बर (+977 / +91 Mobile Number)',
                                  hintText: '+919876543210 or +9779841000001',
                                  prefixIcon: Icon(Icons.phone_android_rounded),
                                ),
                              ),
                              if (error != null) ...<Widget>[
                                const SizedBox(height: 12),
                                Container(
                                  key: const Key('login_error_banner'),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: NepalGovTheme.outbreakCrimson.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: NepalGovTheme.outbreakCrimson,
                                    ),
                                  ),
                                  child: Text(
                                    error,
                                    style: const TextStyle(
                                      color: NepalGovTheme.outbreakCrimson,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                key: const Key('request_otp_button'),
                                onPressed: widget.authViewModel.isLoading
                                    ? null
                                    : _handleRequestOtp,
                                icon: const Icon(Icons.sms_outlined, size: 18),
                                label: const Text('OTP पठाउनुहोस् / Request 6-Digit OTP'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Data Sovereignty: Hosted on Integrated Data Management Center (IDMC Singha Durbar) • Individual Privacy Act 2075',
                        textAlign: TextAlign.center,
                        style: NepalGovTheme.monoTelemetry(
                          fontSize: 11,
                          color: NepalGovTheme.mutedInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
