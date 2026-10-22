import 'dart:async';

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

  bool _sendingOtp = false;
  bool _verifying = false;
  bool _otpSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  String? _lastDispatchedPhone;
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;

  @override
  void dispose() {
    _countdownTimer?.cancel();
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

  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _resendCountdown = 0);
        timer.cancel();
      }
    });
  }

  Future<bool> _isStaffRegistered(String rawDigits) async {
    // Fast path: authorized staff contacts in Chandigarh MCC
    const preAuthorizedPhones = {
      '9915549458', // Shivam Yadav (State Nodal Vector Control Officer)
      '9501588795', // Rahul Chaudhary (Zonal Vector Surveillance Officer)
      '9815011018', // Ishwor Chaudhary (Field Epidemiologist)
      '9815011027', // Aman Yadav (Sub-District Vector Officer)
      '9815022001', // Dr. Suman Singh (Director Health Services / MOH MCC)
      '9815022002', // Dr. Parmjit Singh (State IDSP Epidemiologist, GMSH-16)
      '9815022003', // Dr. Inderjit Kaur (NCVBDC Nodal Officer)
    };
    if (preAuthorizedPhones.contains(rawDigits)) return true;

    try {
      final res = await ref.read(apiClientProvider).verifyStaff(
            uid: 'precheck_$rawDigits',
            phone: '+91$rawDigits',
          );
      if (res['status'] == 'STAFF_VERIFIED' || res.containsKey('officer_profile')) {
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  String _extractTenDigitPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits;
  }

  void _selectAuthorizedOfficer(String phone, String name) {
    setState(() {
      _phoneController.text = phone;
      _lastDispatchedPhone = phone;
      _otpSent = true;
      const pin = '123456';
      for (var i = 0; i < 6; i++) {
        _otpControllers[i].text = pin[i];
      }
    });
    _startResendTimer();
    showArogyaToast(
      context,
      title: 'Officer Selected: $name',
      message: 'Mobile +91 $phone & PIN 123456 ready. Tap Verify to enter portal.',
    );
  }

  Future<void> _sendOtp({bool forceResend = false}) async {
    final rawDigits = _extractTenDigitPhone(_phoneController.text);
    if (rawDigits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_sendingOtp) return;
    setState(() => _sendingOtp = true);

    // Verify staff registration in 3_Staff_Directory BEFORE sending OTP
    final isRegistered = await _isStaffRegistered(rawDigits);
    if (!isRegistered) {
      if (mounted) {
        setState(() => _sendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not registered'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _lastDispatchedPhone = rawDigits;
    });

    try {
      if (kIsWeb) {
        _webConfirmationResult =
            await FirebaseAuth.instance.signInWithPhoneNumber('+91$rawDigits');
        if (!mounted) return;
        setState(() {
          _sendingOtp = false;
          _otpSent = true;
        });
        _startResendTimer();
        _otpFocusNodes[0].requestFocus();
        showArogyaToast(
          context,
          title: 'OTP Dispatched',
          message: '6-digit verification code sent to +91 $rawDigits.',
        );
      } else {
        final completer = Completer<void>();
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: '+91$rawDigits',
          timeout: const Duration(seconds: 60),
          forceResendingToken: forceResend ? _resendToken : null,
          verificationCompleted: (PhoneAuthCredential credential) async {
            final autoCode = credential.smsCode;
            if (autoCode != null && autoCode.length == 6 && mounted) {
              for (var i = 0; i < 6; i++) {
                _otpControllers[i].text = autoCode[i];
              }
            }
            try {
              final userCred =
                  await FirebaseAuth.instance.signInWithCredential(credential);
              if (!completer.isCompleted) completer.complete();
              if (mounted) {
                setState(() => _sendingOtp = false);
                await _completeOfficerSignIn(
                  rawDigits: rawDigits,
                  firebaseUser: userCred.user,
                );
              }
            } catch (_) {
              if (!completer.isCompleted) completer.complete();
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            debugPrint('Phone verification note: [${e.code}] ${e.message}');
            if (rawDigits == '9915549458' || rawDigits == '9501588795') {
              if (mounted) {
                setState(() {
                  _sendingOtp = false;
                  _otpSent = true;
                });
                _startResendTimer();
                const testPin = '123456';
                for (var i = 0; i < 6; i++) {
                  _otpControllers[i].text = testPin[i];
                }
                showArogyaToast(
                  context,
                  title: 'Authorized Officer Detected',
                  message: 'Pre-authorized PIN (123456) ready. Tap Verify to access portal.',
                );
              }
            } else {
              if (mounted) {
                setState(() => _sendingOtp = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to send verification SMS. Please try again later.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
            if (!completer.isCompleted) completer.complete();
          },
          codeSent: (String verId, int? resendToken) {
            if (mounted) {
              setState(() {
                _verificationId = verId;
                _resendToken = resendToken;
                _sendingOtp = false;
                _otpSent = true;
              });
              _startResendTimer();
              if (rawDigits == '9915549458' || rawDigits == '9501588795') {
                const testPin = '123456';
                for (var i = 0; i < 6; i++) {
                  _otpControllers[i].text = testPin[i];
                }
              }
              _otpFocusNodes[0].requestFocus();
              showArogyaToast(
                context,
                title: 'OTP Dispatched',
                message: (rawDigits == '9915549458' || rawDigits == '9501588795')
                    ? 'Authorized Officer PIN (123456) ready.'
                    : '6-digit verification code sent to +91 $rawDigits.',
              );
            }
            if (!completer.isCompleted) completer.complete();
          },
          codeAutoRetrievalTimeout: (String verId) {
            _verificationId = verId;
            if (!completer.isCompleted) completer.complete();
          },
        );
        await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            if (mounted) setState(() => _sendingOtp = false);
          },
        );
      }
    } catch (e) {
      debugPrint('Auth dispatch note: $e');
      if (!mounted) return;
      setState(() => _sendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send verification code. Please check your connection and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _completeOfficerSignIn({
    required String rawDigits,
    User? firebaseUser,
  }) async {
    String uid = firebaseUser?.uid ?? 'officer_$rawDigits';

    Map<String, dynamic> profile = <String, dynamic>{};
    try {
      final candidateDocIds = [
        uid,
        'officer_$rawDigits',
        '+91$rawDigits',
        rawDigits,
      ];
      for (final docId in candidateDocIds) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .get();
        if (snap.exists && snap.data() != null) {
          profile = snap.data()!;
          break;
        }
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

    // Default pre-authorized profiles for rapid testing
    if (profile.isEmpty) {
      if (rawDigits == '9915549458') {
        profile = {
          'name': 'Shivam Yadav',
          'phone': '+919915549458',
          'email': 'academyxshivam@gmail.com',
          'role': 'NODAL_OFFICER',
          'assigned_lgd_code': '0404400017',
          'ward_village': 'Ward 17: Sector 22, Sector 23',
          'district': 'Chandigarh',
          'state': 'Chandigarh',
          'district_rep_name': 'Dr. Suman Singh (Director Health Services / MOH MCC)',
          'district_rep_phone': '+919815022001',
          'district_rep_email': 'academyxshivam@gmail.com',
        };
      } else if (rawDigits == '9501588795') {
        profile = {
          'name': 'Rahul Chaudhary',
          'phone': '+919501588795',
          'email': 'chaudharyraul07@gmail.com',
          'role': 'NODAL_OFFICER',
          'assigned_lgd_code': '0404400019',
          'ward_village': 'Ward 19: Industrial Area Phase II, Ram Darbar',
          'district': 'Chandigarh',
          'state': 'Chandigarh',
          'district_rep_name': 'Dr. Parmjit Singh (State IDSP Epidemiologist, GMSH-16)',
          'district_rep_phone': '+919815022002',
          'district_rep_email': 'academyxshivam@gmail.com',
        };
      }
    }

    // Auto-sync profile to Firestore under user.uid
    if (firebaseUser != null && profile.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set(profile, SetOptions(merge: true));
      } catch (_) {}
    }

    ref.read(activeWardProvider.notifier).setOfficerSession(
          uid: uid,
          name: (profile['name'] ?? firebaseUser?.displayName ?? 'Field Officer').toString(),
          phone: '+91 $rawDigits',
          email: (profile['email'] ?? firebaseUser?.email ?? 'officer@arogya.gov.in').toString(),
          lgdCode: (profile['assigned_lgd_code'] ?? '0404400017').toString(),
          wardName: profile['ward_village'] != null
              ? '${profile['ward_village']}, ${profile['district'] ?? ''}'
              : 'Chandigarh UT',
        );

    if (!mounted) return;
    setState(() => _verifying = false);
    context.go('/home');
  }

  Future<void> _verifyAndAccessPortal() async {
    final rawDigits = _extractTenDigitPhone(_phoneController.text);
    final otpCode = _otpControllers.map((c) => c.text.trim()).join();
    if (rawDigits.length < 10 || otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your 10-digit mobile number and 6-digit OTP code.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _verifying = true);

    final isRegistered = await _isStaffRegistered(rawDigits);
    if (!isRegistered) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not registered'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
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
      } else if (otpCode != '582419' && otpCode != '123456') {
        await _sendOtp();
        if (!mounted) return;
        setState(() => _verifying = false);
        return;
      }

      await _completeOfficerSignIn(
        rawDigits: rawDigits,
        firebaseUser: firebaseUser,
      );
    } catch (e) {
      // Allow pre-authorized testing code fallback (123456 / 582419) for registered test workers
      if ((rawDigits == '9915549458' || rawDigits == '9501588795') &&
          (otpCode == '123456' || otpCode == '582419')) {
        await _completeOfficerSignIn(rawDigits: rawDigits);
        return;
      }
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code. Please check the OTP and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
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
                        // Authorized Officer Quick-Select Chips
                        Text(
                          'Pre-Authorized Officers',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: ArogyaTheme.slateMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _selectAuthorizedOfficer('9915549458', 'Shivam Yadav'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _phoneController.text.contains('9915549458')
                                          ? ArogyaTheme.primaryCrimson
                                          : const Color(0xFFFECACA),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.verified_user_rounded, size: 14, color: ArogyaTheme.primaryCrimson),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Shivam Yadav',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: ArogyaTheme.slateHeading,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        '+91 99155 49458',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: ArogyaTheme.primaryCrimsonDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _selectAuthorizedOfficer('9501588795', 'Rahul Chaudhary'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _phoneController.text.contains('9501588795')
                                          ? ArogyaTheme.primaryCrimson
                                          : const Color(0xFFFECACA),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.shield_rounded, size: 14, color: ArogyaTheme.primaryCrimson),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Rahul Chaudhary',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: ArogyaTheme.slateHeading,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        '+91 95015 88795',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: ArogyaTheme.primaryCrimsonDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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
                                  onChanged: (value) {
                                    final digits = _extractTenDigitPhone(value);
                                    if (_otpSent && digits != _lastDispatchedPhone) {
                                      setState(() {
                                        _otpSent = false;
                                        _resendCountdown = 0;
                                      });
                                      _countdownTimer?.cancel();
                                    }
                                  },
                                  onSubmitted: (_) {
                                    if (!_otpSent) {
                                      _sendOtp();
                                    } else {
                                      _verifyAndAccessPortal();
                                    }
                                  },
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
                              if (_otpSent)
                                IconButton(
                                  tooltip: 'Change Mobile Number',
                                  onPressed: () {
                                    setState(() {
                                      _otpSent = false;
                                      _resendCountdown = 0;
                                    });
                                    _countdownTimer?.cancel();
                                    _phoneFocusNode.requestFocus();
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

                        // Send OTP Button (Visible when OTP has not been sent yet)
                        if (!_otpSent) ...[
                          const SizedBox(height: 16),
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
                              onPressed: _sendingOtp ? null : () => _sendOtp(),
                              icon: _sendingOtp
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _sendingOtp ? 'Checking Registration...' : 'Send OTP',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // OTP Section (Revealed when user clicks on Send OTP)
                        if (_otpSent) ...[
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

                          // Resend OTP Countdown / Action Row
                          if (_resendCountdown > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: ArogyaTheme.slateMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Resend code in $_resendCountdown seconds',
                                      style: const TextStyle(
                                        color: ArogyaTheme.slateMuted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: _sendingOtp ? null : () => _sendOtp(forceResend: true),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: ArogyaTheme.primaryCrimsonDark,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Resend Code',
                                        style: TextStyle(
                                          color: ArogyaTheme.primaryCrimsonDark,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),

                          // Primary CTA Button: Verify & Access Portal
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
                        ],
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
