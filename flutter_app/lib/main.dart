import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/network/dio_client.dart';
import 'core/router/router.dart';
import 'core/storage/secure_hive_storage.dart';
import 'core/theme/app_theme.dart';
import 'services/location_service.dart';
import 'services/offline_sync_queue.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/copilot_chat_viewmodel.dart';
import 'viewmodels/map_viewmodel.dart';
import 'viewmodels/rrt_fleet_viewmodel.dart';
import 'viewmodels/surveillance_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = SovereignAppDependencies.create();
  runApp(NidanIqNepalSovereignApp(dependencies: container));
}

/// Dependency Container for NidanIQ Nepal Sovereign Government Field Application.
class SovereignAppDependencies {
  SovereignAppDependencies({
    required this.storage,
    required this.dioClient,
    required this.offlineQueueService,
    required this.locationNotifier,
    required this.authViewModel,
    required this.surveillanceViewModel,
    required this.mapViewModel,
    required this.rrtFleetViewModel,
    required this.copilotChatViewModel,
    required this.router,
  });

  factory SovereignAppDependencies.create({
    bool useInMemoryStorageForTests = false,
  }) {
    final storage = SecureSovereignStorage(
      useInMemoryForTests: useInMemoryStorageForTests,
    );
    final dioClient = SovereignDioClient(storage: storage);
    final offlineQueueService = OfflineSyncQueueService(
      storage: storage,
      dioClient: dioClient,
    );
    final authViewModel = AuthViewModel(
      storage: storage,
      dioClient: dioClient,
    );
    final surveillanceViewModel = SurveillanceViewModel(
      offlineQueueService: offlineQueueService,
      dioClient: dioClient,
    );
    final mapViewModel = MapViewModel();
    final locationNotifier = UserLocationStateNotifier(
      storage: storage,
      dioClient: dioClient,
      onLocationChanged: mapViewModel.applyResolvedSpatialContext,
    );
    final rrtFleetViewModel = RrtFleetViewModel();
    final copilotChatViewModel = CopilotChatViewModel();

    final router = createNepalSovereignRouter(
      authViewModel: authViewModel,
      surveillanceViewModel: surveillanceViewModel,
      mapViewModel: mapViewModel,
      rrtFleetViewModel: rrtFleetViewModel,
      copilotChatViewModel: copilotChatViewModel,
      locationNotifier: locationNotifier,
    );

    return SovereignAppDependencies(
      storage: storage,
      dioClient: dioClient,
      offlineQueueService: offlineQueueService,
      locationNotifier: locationNotifier,
      authViewModel: authViewModel,
      surveillanceViewModel: surveillanceViewModel,
      mapViewModel: mapViewModel,
      rrtFleetViewModel: rrtFleetViewModel,
      copilotChatViewModel: copilotChatViewModel,
      router: router,
    );
  }

  final SecureSovereignStorage storage;
  final SovereignDioClient dioClient;
  final OfflineSyncQueueService offlineQueueService;
  final UserLocationStateNotifier locationNotifier;
  final AuthViewModel authViewModel;
  final SurveillanceViewModel surveillanceViewModel;
  final MapViewModel mapViewModel;
  final RrtFleetViewModel rrtFleetViewModel;
  final CopilotChatViewModel copilotChatViewModel;
  final GoRouter router;
}

/// Root Flutter Application Widget for NidanIQ Nepal Sovereign Vector Surveillance DPI.
class NidanIqNepalSovereignApp extends StatelessWidget {
  const NidanIqNepalSovereignApp({
    required this.dependencies,
    super.key,
  });

  final SovereignAppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NidanIQ — स्वास्थ्य तथा जनसंख्या मन्त्रालय (MoHP / EDCD Nepal)',
      debugShowCheckedModeBanner: false,
      theme: NepalGovTheme.buildTheme(),
      routerConfig: dependencies.router,
    );
  }
}
