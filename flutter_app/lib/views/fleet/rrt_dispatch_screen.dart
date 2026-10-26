import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../viewmodels/rrt_fleet_viewmodel.dart';

/// `"Khoj Ra Nashta Gar"` (`खोज र नष्ट गर अभियान`) Rapid Response Team (RRT) Fleet Screen.
class RrtDispatchScreen extends StatelessWidget {
  const RrtDispatchScreen({
    required this.rrtFleetViewModel,
    super.key,
  });

  final RrtFleetViewModel rrtFleetViewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rrtFleetViewModel,
      builder: (BuildContext context, Widget? _) {
        final receipt = rrtFleetViewModel.lastDispatchReceipt;
        return ListView(
          key: const Key('rrt_dispatch_screen'),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NepalGovTheme.darkSlateCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'खोज र नष्ट गर द्रुत प्रतिकार्य टोली (RRT Fleet & Bti Logistics)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'EDCD Nepal Statutory Source Reduction • Bti WP & Temephos 50% EC Dispatch',
                    style: NepalGovTheme.monoTelemetry(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (receipt != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NepalGovTheme.containedEmerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NepalGovTheme.containedEmerald),
                ),
                child: Text(
                  receipt,
                  style: NepalGovTheme.monoTelemetry(
                    fontSize: 12,
                    color: NepalGovTheme.darkSlateCard,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...rrtFleetViewModel.units.map((RrtUnitModel unit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              '${unit.vehicleId} (${unit.plateNumber})',
                              style: NepalGovTheme.monoTelemetry(fontSize: 14),
                            ),
                            Text(
                              'ETA ${unit.etaMinutes}m',
                              style: NepalGovTheme.monoTelemetry(
                                fontSize: 12,
                                color: NepalGovTheme.royalNepalBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lead: ${unit.teamLeadNameNe} (${unit.teamLeadName}) • ${unit.driverPhone}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Base Ward: ${unit.baseWardId} • Bti: ${unit.btiStockKg} kg • Temephos: ${unit.temephosStockLiters} L • ${unit.status}',
                          style: NepalGovTheme.monoTelemetry(
                            fontSize: 11.5,
                            color: NepalGovTheme.mutedInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => rrtFleetViewModel.dispatchRrtUnit(
                              vehicleId: unit.vehicleId,
                              targetWardId: 'NP-P3-D27-30608-W17',
                            ),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Dispatch to Ward 17'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
