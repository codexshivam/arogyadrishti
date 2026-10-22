import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/services/firestore_sync.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/centers/centers_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/privacy/privacy_policy_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/support/support_screen.dart';
import 'features/vans/vans_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await FirestoreSyncService.configureOfflinePersistence(
      firebaseInitialized: true,
    );
  } catch (_) {
    // Runs with FastAPI Cloud Run backend when Firebase client options are not injected on desktop tests
  }
  runApp(const ProviderScope(child: ArogyaDrishtiApp()));
}

final GoRouter arogyaRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/stats',
      builder: (context, state) => const StatsScreen(),
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) => const MapScreen(),
    ),
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
    GoRoute(
      path: '/vans',
      builder: (context, state) => const VansScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanScreen(),
    ),
  ],
);

class ArogyaDrishtiApp extends StatelessWidget {
  const ArogyaDrishtiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Arogya — Arogya Drishti Vector Surveillance DPI',
      debugShowCheckedModeBanner: false,
      theme: ArogyaTheme.lightTheme(),
      routerConfig: arogyaRouter,
    );
  }
}
