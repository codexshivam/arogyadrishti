import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/services/firestore_sync.dart';
import 'core/services/telemetry_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/centers/centers_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/privacy/privacy_policy_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/legal_viewer_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/support/support_screen.dart';
import 'features/vans/vans_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(ArogyaTheme.whiteSystemUiOverlay);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize Firebase App Check for Android Play Integrity & debug provider
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.deviceCheck,
      );
    }
    await FirestoreSyncService.configureOfflinePersistence(
      firebaseInitialized: true,
    );
    await ArogyaTelemetryService.initialize();
  } catch (_) {
    // Runs with FastAPI Cloud Run backend when Firebase client options are not injected on desktop tests
  }
  runApp(const ProviderScope(child: ArogyaDrishtiApp()));
}

/// Converts a Stream into a Listenable for GoRouter refresh notifications.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

Stream<User?> _safeAuthStream() {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return const Stream<User?>.empty();
  }
}

bool _isUserAuthenticated() {
  try {
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

final GoRouter arogyaRouter = GoRouter(
  initialLocation: '/auth',
  refreshListenable: GoRouterRefreshStream(_safeAuthStream()),
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = _isUserAuthenticated();
    final String path = state.uri.path;
    final bool isPublicRoute =
        path == '/auth' ||
        path == '/privacy' ||
        path == '/privacy-policy' ||
        path == '/terms' ||
        path == '/terms-of-service' ||
        path == '/support';

    // Strict Zero-Trust Security Gate:
    // If not authenticated, unprivileged users are never allowed on protected screens.
    if (!loggedIn && !isPublicRoute) {
      return '/auth';
    }

    // If already verified/authenticated and navigating to /auth, redirect to /home.
    if (loggedIn && path == '/auth') {
      return '/home';
    }

    return null;
  },
  observers: <NavigatorObserver>[
    ArogyaTelemetryService.createNavigationObserver(),
  ],
  routes: [
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const LegalViewerScreen(
        title: 'Privacy Policy',
        documentType: 'privacy',
      ),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const LegalViewerScreen(
        title: 'Terms of Service',
        documentType: 'terms',
      ),
    ),
    GoRoute(
      path: '/terms-of-service',
      builder: (context, state) => const LegalViewerScreen(
        title: 'Terms of Service',
        documentType: 'terms',
      ),
    ),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const SupportScreen(),
    ),
    GoRoute(
      path: '/centers',
      builder: (context, state) => const CentersScreen(),
    ),
    GoRoute(path: '/vans', builder: (context, state) => const VansScreen()),
    GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
  ],
);

class ArogyaDrishtiApp extends ConsumerStatefulWidget {
  const ArogyaDrishtiApp({super.key});

  @override
  ConsumerState<ArogyaDrishtiApp> createState() => _ArogyaDrishtiAppState();
}

class _ArogyaDrishtiAppState extends ConsumerState<ArogyaDrishtiApp> {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenAuthAndHydrate();
  }

  void _listenAuthAndHydrate() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          final current = ref.read(activeWardProvider);
          if (!current.isAuthenticated || current.officerUid != user.uid) {
            Map<String, dynamic> profile = {};
            try {
              final snap = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              if (snap.exists && snap.data() != null) {
                profile = snap.data()!;
              } else {
                final phone = user.phoneNumber ?? '';
                final rawPhone = phone.replaceAll(RegExp(r'\D'), '');
                final last10 = rawPhone.length >= 10
                    ? rawPhone.substring(rawPhone.length - 10)
                    : rawPhone;
                final candidateKeys = ['officer_$last10', '+91$last10', last10];
                for (final k in candidateKeys) {
                  final altSnap = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(k)
                      .get();
                  if (altSnap.exists && altSnap.data() != null) {
                    profile = altSnap.data()!;
                    // Auto-sync profile to user.uid
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .set(profile, SetOptions(merge: true));
                    break;
                  }
                }
              }
            } catch (_) {}

            ref
                .read(activeWardProvider.notifier)
                .setOfficerSession(
                  uid: user.uid,
                  name: (profile['name'] ?? user.displayName ?? 'Field Officer')
                      .toString(),
                  phone: (profile['phone'] ?? user.phoneNumber ?? '')
                      .toString(),
                  email: (profile['email'] ?? user.email ?? '').toString(),
                  lgdCode: (profile['assigned_lgd_code'] ?? '0404400017')
                      .toString(),
                  wardName: profile['ward_village'] != null
                      ? '${profile['ward_village']}, ${profile['district'] ?? ''}'
                      : 'Sector 22-B, Chandigarh',
                );
          }
        } else {
          ref.read(activeWardProvider.notifier).signOut();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ArogyaTheme.whiteSystemUiOverlay,
      child: MaterialApp.router(
        title: 'Arogya Drishti',
        debugShowCheckedModeBanner: false,
        theme: ArogyaTheme.lightTheme(),
        routerConfig: arogyaRouter,
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: ArogyaTheme.whiteSystemUiOverlay,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
