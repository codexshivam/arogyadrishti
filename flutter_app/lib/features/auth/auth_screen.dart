import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

/// Screen 6: Welcome / Officer Sign-In & OTP Verification (`/auth`).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.length != 10) {
      showArogyaToast(
        context,
        title: 'Invalid Mobile Number',
        message: 'Enter a valid 10-digit Indian mobile number.',
        contentType: ContentType.warning,
      );
      return;
    }

    try {
      if (kIsWeb) {
        _webConfirmationResult =
            await FirebaseAuth.instance.signInWithPhoneNumber('+91$rawDigits');
      } else {
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
      }
    } catch (e) {
      debugPrint('Phone auth dispatch note: $e');
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
      User? firebaseUser;

      if (kIsWeb) {
        _webConfirmationResult ??=
            await FirebaseAuth.instance.signInWithPhoneNumber('+91$rawDigits');
        final userCred = await _webConfirmationResult!.confirm(otpCode);
        firebaseUser = userCred.user;
      } else if (_verificationId != null) {
        final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otpCode,
        );
        final userCred =
            await FirebaseAuth.instance.signInWithCredential(cred);
        firebaseUser = userCred.user;
      }

      if (firebaseUser != null) {
        uid = firebaseUser.uid;
      }

      Map<String, dynamic> profile = <String, dynamic>{};
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (snap.exists && snap.data() != null) {
          profile = snap.data()!;
        }
      } catch (_) {}

      if (profile.isEmpty) {
        try {
          final res = await ref.read(apiClientProvider).verifyStaff(
                uid: uid,
                phone: '+91$rawDigits',
              );
          profile = (res['officer_profile'] as Map<String, dynamic>?) ??
              <String, dynamic>{};
        } catch (_) {}
      }

      ref.read(activeWardProvider.notifier).setOfficerSession(
            uid: uid,
            name: (profile['name'] ?? firebaseUser?.displayName ?? '').toString(),
            phone: '+91 $rawDigits',
            email: (profile['email'] ?? firebaseUser?.email ?? '').toString(),
            lgdCode: (profile['assigned_lgd_code'] ?? '').toString(),
            wardName: profile['ward_village'] != null
                ? '${profile['ward_village']}, ${profile['district'] ?? ''}'
                : '',
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
            'Invalid OTP or phone +91$rawDigits is not pre-authorized ($e).',
        contentType: ContentType.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArogyaTheme.backgroundCanvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: ArogyaTheme.slateHeading,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access restricted to verified field epidemiologists, sanitary inspectors, and district health nodal teams.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ArogyaTheme.slateMuted,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Main White Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: ArogyaTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registered Mobile Number',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),

                        // Unified Mobile Input Container
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '🇮🇳 +91',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: ArogyaTheme.slateHeading,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                                color: ArogyaTheme.slateMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocusNode,
                                  keyboardType: TextInputType.phone,
                                  onSubmitted: (_) => _sendOtp(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: ArogyaTheme.slateHeading,
                                    letterSpacing: 0.4,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '98765 43210',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit / Send OTP',
                                onPressed: () {
                                  if (_phoneController.text.trim().length >= 10) {
                                    _sendOtp();
                                  } else {
                                    _phoneFocusNode.requestFocus();
                                  }
                                },
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 19,
                                  color: ArogyaTheme.slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        Text(
                          'Enter 6-Digit Verification Code',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),

                        // 6 OTP Boxes
                        Row(
                          children: List.generate(6, (idx) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: idx < 5 ? 8 : 0,
                                ),
                                child: SizedBox(
                                  height: 52,
                                  child: TextField(
                                    controller: _otpControllers[idx],
                                    focusNode: _otpFocusNodes[idx],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    onChanged: (val) {
                                      if (val.isNotEmpty && idx < 5) {
                                        _otpFocusNodes[idx + 1].requestFocus();
                                      } else if (val.isEmpty && idx > 0) {
                                        _otpFocusNodes[idx - 1].requestFocus();
                                      }
                                    },
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: ArogyaTheme.slateHeading,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '•',
                                      hintStyle: const TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Resend OTP row
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: _sendOtp,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: ArogyaTheme.slateMuted,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Resend OTP now',
                                  style: TextStyle(
                                    color: ArogyaTheme.primaryCrimsonDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Primary CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ArogyaTheme.primaryCrimson,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
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
                                : const Icon(Icons.lock_rounded, size: 18),
                            label: Text(
                              _verifying
                                  ? 'Verifying...'
                                  : 'Verify & Access Portal',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Privacy Policy & Terms of Services text
                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: ArogyaTheme.slateMuted,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'By signing into ArogyaDrishti app, you agree to our\n',
                                ),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    color: ArogyaTheme.primaryCrimsonDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => context.push('/privacy'),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Terms of Services',
                                  style: const TextStyle(
                                    color: ArogyaTheme.primaryCrimsonDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => context.push('/privacy'),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Statutory Surveillance Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.gavel_rounded,
                          color: ArogyaTheme.primaryCrimson,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Statutory Surveillance Notice',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: ArogyaTheme.triageRedText,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Unauthorized access attempts are logged under the Epidemic Diseases & IT Acts. If your contact details do not match your ward jurisdiction, request dispatch re-assignment via your District Nodal Officer.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: ArogyaTheme.triageRedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Trouble signing in? | Helpdesk: 1800-11-VECTOR
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      InkWell(
                        onTap: () => context.push('/support'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 15,
                              color: ArogyaTheme.slateMuted,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Trouble signing in?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ArogyaTheme.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/support'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.support_agent_rounded,
                              size: 15,
                              color: ArogyaTheme.primaryCrimsonDark,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Helpdesk: 1800-11-VECTOR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ArogyaTheme.primaryCrimsonDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Arogya Drishti | Team Rocket (Chandigarh University)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ArogyaTheme.slateMuted,
                          ),
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
