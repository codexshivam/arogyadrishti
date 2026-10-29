import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/domain_models.dart';
import '../../services/location_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/copilot_chat_viewmodel.dart';
import '../../viewmodels/map_viewmodel.dart';
import '../../viewmodels/rrt_fleet_viewmodel.dart';
import '../../viewmodels/surveillance_viewmodel.dart';
import '../../views/auth/login_screen.dart';
import '../../views/auth/otp_verify_screen.dart';
import '../../views/copilot/gemma_chat_screen.dart';
import '../../views/dashboard/dashboard_shell.dart';
import '../../views/dashboard/edcd_nodal_view.dart';
import '../../views/dashboard/fchv_home_view.dart';
import '../../views/dashboard/palika_chief_view.dart';
import '../../views/dashboard/ward_officer_view.dart';
import '../../views/fleet/rrt_dispatch_screen.dart';
import '../../views/map/gis_map_screen.dart';
import '../../views/profile/profile_view.dart';
import '../../views/scan/ai_vision_screen.dart';

/// Builds the Sovereign Nepal RBAC `GoRouter` with strict JWT role-based route guards.
/// - Unauthenticated users are routed to `/login`.
/// - Authenticated users on `/login` or `/verify-otp` are automatically routed to `user.role.homeRoute`.
/// - Deep-linking into another role's dashboard or `/ulv-override` is blocked and redirected to `user.role.homeRoute`.
GoRouter createNepalSovereignRouter({
  required AuthViewModel authViewModel,
  required SurveillanceViewModel surveillanceViewModel,
  required MapViewModel mapViewModel,
  required RrtFleetViewModel rrtFleetViewModel,
  required CopilotChatViewModel copilotChatViewModel,
  UserLocationStateNotifier? locationNotifier,
  String initialLocation = '/login',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authViewModel,
    redirect: (BuildContext context, GoRouterState state) {
      final path = state.uri.path;
      final user = authViewModel.currentUser;
      final isAuthScreen = path == '/login' || path == '/verify-otp';

      if (user == null) {
        return isAuthScreen ? null : '/login';
      }

      if (isAuthScreen || path == '/') {
        return user.role.homeRoute;
      }

      // Role-Based Route Guards (Prevent Cross-Role Deep-Link Escalation)
      if (path.startsWith('/dashboard/fchv') &&
          user.role != NepalStaffRole.fchv &&
          user.role != NepalStaffRole.fieldVisitor &&
          user.role != NepalStaffRole.admin &&
          user.role != NepalStaffRole.municipalityAdmin) {
        return user.role.homeRoute;
      }
      if (path.startsWith('/dashboard/ward-officer') &&
          user.role != NepalStaffRole.wardHealthOfficer) {
        return user.role.homeRoute;
      }
      if ((path.startsWith('/dashboard/palika-chief') ||
              path.startsWith('/ulv-override')) &&
          user.role != NepalStaffRole.palikaHealthChief) {
        return user.role.homeRoute;
      }
      if (path.startsWith('/dashboard/edcd-nodal') &&
          user.role != NepalStaffRole.edcdNodal) {
        return user.role.homeRoute;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) => LoginScreen(
          authViewModel: authViewModel,
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (BuildContext context, GoRouterState state) => OtpVerifyScreen(
          authViewModel: authViewModel,
        ),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return DashboardShell(
            authViewModel: authViewModel,
            currentPath: state.uri.path,
            locationNotifier: locationNotifier,
            child: child,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard/fchv',
            builder: (BuildContext context, GoRouterState state) => FchvHomeView(
              authViewModel: authViewModel,
              surveillanceViewModel: surveillanceViewModel,
            ),
          ),
          GoRoute(
            path: '/dashboard/ward-officer',
            builder: (BuildContext context, GoRouterState state) =>
                WardOfficerView(
              mapViewModel: mapViewModel,
              rrtFleetViewModel: rrtFleetViewModel,
            ),
          ),
          GoRoute(
            path: '/dashboard/palika-chief',
            builder: (BuildContext context, GoRouterState state) =>
                PalikaChiefView(
              authViewModel: authViewModel,
              mapViewModel: mapViewModel,
              rrtFleetViewModel: rrtFleetViewModel,
            ),
          ),
          GoRoute(
            path: '/ulv-override',
            builder: (BuildContext context, GoRouterState state) =>
                PalikaChiefView(
              authViewModel: authViewModel,
              mapViewModel: mapViewModel,
              rrtFleetViewModel: rrtFleetViewModel,
            ),
          ),
          GoRoute(
            path: '/dashboard/edcd-nodal',
            builder: (BuildContext context, GoRouterState state) => EdcdNodalView(
              mapViewModel: mapViewModel,
            ),
          ),
          GoRoute(
            path: '/scan',
            builder: (BuildContext context, GoRouterState state) =>
                AiVisionScreen(
              surveillanceViewModel: surveillanceViewModel,
            ),
          ),
          GoRoute(
            path: '/map',
            builder: (BuildContext context, GoRouterState state) => GisMapScreen(
              mapViewModel: mapViewModel,
            ),
          ),
          GoRoute(
            path: '/fleet',
            builder: (BuildContext context, GoRouterState state) =>
                RrtDispatchScreen(
              rrtFleetViewModel: rrtFleetViewModel,
            ),
          ),
          GoRoute(
            path: '/copilot',
            builder: (BuildContext context, GoRouterState state) =>
                GemmaChatScreen(
              copilotViewModel: copilotChatViewModel,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (BuildContext context, GoRouterState state) => ProfileView(
              authViewModel: authViewModel,
            ),
          ),
        ],
      ),
    ],
  );
}
