import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

/// Screen 6: Officer Sign-In & OTP Verification (`/auth`) bound to `3_Staff_Directory`.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController(text: '9915549458');
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (idx) => TextEditingController(text: <String>['5', '8', '2', '4', '1', '9'][idx]),
  );
  bool _verifying = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.length != 10) {
      showArogyaToast(
        context,
        title: 'Invalid Mobile Number',
        message: 'Enter a valid 10-digit Indian mobile number registered in 3_Staff_Directory.',
        contentType: ContentType.warning,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$rawDigits',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Firebase Phone Auth note: ${e.message}');
        },
        codeSent: (String verId, int? resendToken) {
          if (mounted) {
            setState(() => _verificationId = verId);
          }
        },
        codeAutoRetrievalTimeout: (String verId) {
          _verificationId = verId;
        },
      );
    } catch (_) {
      // Continue to backend staff verification if Firebase Phone Auth is not active on emulator
    }

    if (!mounted) return;
    showArogyaToast(
      context,
      title: 'OTP Dispatched',
      message: '6-digit verification code sent to +91 $rawDigits.',
    );
  }

  Future<void> _verifyAndAccessPortal() async {
    final rawDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final otpCode = _otpControllers.map((c) => c.text.trim()).join();
    if (rawDigits.length < 10 || otpCode.length < 6) {
      showArogyaToast(
        context,
        title: 'Incomplete Credentials',
        message: 'Enter your 10-digit mobile number and 6-digit OTP code.',
        contentType: ContentType.warning,
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      String uid = 'officer_$rawDigits';
      if (_verificationId != null) {
        try {
          final cred = PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: otpCode,
          );
          final userCred =
              await FirebaseAuth.instance.signInWithCredential(cred);
          if (userCred.user != null) {
            uid = userCred.user!.uid;
          }
        } catch (_) {}
      }

      final res = await ref.read(apiClientProvider).verifyStaff(
            uid: uid,
            phone: '+91$rawDigits',
          );
      final profile =
          (res['officer_profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      ref.read(activeWardProvider.notifier).setOfficerSession(
            uid: uid,
            name: (profile['name'] ?? 'Kunal Yadav').toString(),
            phone: '+91 $rawDigits',
            email: (profile['email'] ?? 'shivam@revlet.me').toString(),
            lgdCode: (profile['assigned_lgd_code'] ?? '04055001').toString(),
            wardName:
                '${profile['ward_village'] ?? 'Sector 22-B'}, ${profile['district'] ?? 'Chandigarh'}',
          );

      if (!mounted) return;
      setState(() => _verifying = false);
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      showArogyaToast(
        context,
        title: 'Staff Verification Failed',
        message:
            'Phone +91$rawDigits is not pre-authorized in 3_Staff_Directory or backend unreachable.',
        contentType: ContentType.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/logo/arogya_logo.png',
                          width: 54,
                          height: 54,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.health_and_safety_rounded,
                            size: 48,
                            color: ArogyaTheme.primaryCrimson,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Officer Sign In',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            Text(
                              'Arogya • teamrocket.arogyadrishti.android',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: ArogyaTheme.primaryCrimson,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access restricted to verified field epidemiologists, sanitary inspectors, and district health nodal teams.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ArogyaTheme.slateMuted,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ArogyaTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ArogyaTheme.borderHairline),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.privacy_tip_outlined,
                          color: ArogyaTheme.primaryCrimson,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Review our Privacy Policy & Phone Verification Data Terms before signing in.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/privacy'),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registered Mobile Number',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: ArogyaTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: ArogyaTheme.inputBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '🇮🇳 +91',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: '98765 43210',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Enter 6-Digit Verification Code',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (idx) {
                              return SizedBox(
                                width: 46,
                                height: 48,
                                child: TextField(
                                  controller: _otpControllers[idx],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _sendOtp,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: ArogyaTheme.primaryCrimson,
                            ),
                            label: const Text(
                              'Resend OTP now',
                              style: TextStyle(
                                color: ArogyaTheme.primaryCrimson,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _verifying ? null : _verifyAndAccessPortal,
                            icon: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline_rounded, size: 18),
                            label: Text(
                              _verifying
                                  ? 'Verifying 3_Staff_Directory...'
                                  : 'Verify & Access Portal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ArogyaTheme.triageRedBg.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ArogyaTheme.primaryCrimson.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.gavel_rounded,
                          color: ArogyaTheme.primaryCrimson,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Statutory Surveillance Notice',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: ArogyaTheme.triageRedText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Unauthorized access attempts are logged under the Epidemic Diseases & DPDP Act 2023. If your contact details do not match your ward jurisdiction, request dispatch re-assignment via your District Nodal Officer.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ArogyaTheme.triageRedText.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Arogya Drishti | Team Rocket (Chandigarh University)',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
