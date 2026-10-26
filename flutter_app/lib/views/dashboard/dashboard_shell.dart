import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/location_picker.dart';

/// Adaptive Multi-Role Government Shell (`Scaffold`) with Bikram Sambat Telemetry Header,
/// Reactive Spatial Context Header (`Current Location: Ward X, <Palika>`),
/// Role Badge, Secure Logout Button, and Tactical Navigation Bar.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    required this.authViewModel,
    required this.currentPath,
    required this.child,
    this.locationNotifier,
    super.key,
  });

  final AuthViewModel authViewModel;
  final String currentPath;
  final Widget child;
  final UserLocationStateNotifier? locationNotifier;

  int _resolveSelectedIndex(String path) {
    if (path.startsWith('/scan')) {
      return 1;
    }
    if (path.startsWith('/map')) {
      return 2;
    }
    if (path.startsWith('/fleet')) {
      return 3;
    }
    if (path.startsWith('/copilot')) {
      return 4;
    }
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    final user = authViewModel.currentUser;
    final homeRoute = user?.role.homeRoute ?? '/dashboard/fchv';
    switch (index) {
      case 0:
        context.go(homeRoute);
      case 1:
        context.go('/scan');
      case 2:
        context.go('/map');
      case 3:
        context.go('/fleet');
      case 4:
        context.go('/copilot');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      authViewModel,
      ?locationNotifier,
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (BuildContext context, Widget? _) {
        final user = authViewModel.currentUser;
        final selectedIndex = _resolveSelectedIndex(currentPath);
        final resolvedLoc = locationNotifier?.currentLocation;
        final locationHeaderLabel = resolvedLoc?.dashboardHeaderLabel ??
            'Current Location: Ward 17, Kathmandu Metro';

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user?.role.labelNeEn ?? 'नेपाल सरकार | NidanIQ',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: NepalGovTheme.darkSlateCard,
                  ),
                ),
                Text(
                  key: const Key('dashboard_resolved_location_header'),
                  '$locationHeaderLabel • ${user?.bsAdOfficialLabel ?? '२०८३ कार्तिक ९ | 2026-10-26'}',
                  style: NepalGovTheme.monoTelemetry(
                    fontSize: 11,
                    color: NepalGovTheme.mutedInk,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (locationNotifier != null)
                IconButton(
                  key: const Key('open_location_picker_button'),
                  tooltip:
                      'Select Palika / Ward Context (प्रदेश -> जिल्ला -> पालिका -> वडा)',
                  onPressed: () {
                    LocationPicker.showModal(
                      context,
                      locationNotifier: locationNotifier!,
                    );
                  },
                  icon: const Icon(
                    Icons.location_on_outlined,
                    color: NepalGovTheme.royalNepalBlue,
                  ),
                ),
              IconButton(
                key: const Key('profile_settings_button'),
                tooltip:
                    'Settings & Communication Preferences (प्रोफाइल र इमेल सेटिङ)',
                onPressed: () {
                  context.go('/profile');
                },
                icon: const Icon(
                  Icons.manage_accounts_outlined,
                  color: NepalGovTheme.royalNepalBlue,
                ),
              ),
              IconButton(
                key: const Key('logout_button'),
                tooltip: 'लगआउट / Secure Logout (Purge Keystore)',
                onPressed: () async {
                  locationNotifier?.clearOnLogout();
                  await authViewModel.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: NepalGovTheme.outbreakCrimson,
                ),
              ),
            ],
          ),
          body: SafeArea(child: child),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            backgroundColor: NepalGovTheme.elevatedPaper,
            onDestinationSelected: (int idx) =>
                _onDestinationSelected(context, idx),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'गृह / Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.camera_enhance_outlined),
                selectedIcon: Icon(Icons.camera_enhance_rounded),
                label: 'PaliGemma',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'GIS नक्सा',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded),
                label: 'RRT भ्यान',
              ),
              NavigationDestination(
                icon: Icon(Icons.psychology_outlined),
                selectedIcon: Icon(Icons.psychology_rounded),
                label: 'Gemma 4',
              ),
            ],
          ),
        );
      },
    );
  }
}
