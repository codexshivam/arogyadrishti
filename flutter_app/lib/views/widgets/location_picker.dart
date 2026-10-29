import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';

/// Cascading Administrative Location Selector (`Province -> District -> Palika -> Ward`)
/// in bilingual English and Nepali Devanagari (`प्रदेश -> जिल्ला -> पालिका -> वडा`).
/// Bound directly to `UserLocationStateNotifier` and enforces the **Zero Defaulting** onboarding flow.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    required this.locationNotifier,
    this.isModal = false,
    super.key,
  });

  final UserLocationStateNotifier locationNotifier;
  final bool isModal;

  /// Opens the Cascading Location Picker in a clean modal bottom sheet.
  static Future<void> showModal(
    BuildContext context, {
    required UserLocationStateNotifier locationNotifier,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NepalGovTheme.elevatedPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: LocationPicker(
            locationNotifier: locationNotifier,
            isModal: true,
          ),
        );
      },
    );
  }

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late int _selectedProvinceCode;
  late int _selectedDistrictCode;
  late String _selectedPalikaCode;
  late String _selectedCompositeWardId;

  @override
  void initState() {
    super.initState();
    final current = widget.locationNotifier.currentLocation ??
        NepalAdminHierarchyCatalog.allReferenceWards.first;
    _selectedProvinceCode = current.provinceCode;
    _selectedDistrictCode = current.districtCode;
    _selectedPalikaCode = current.palikaCode;
    _selectedCompositeWardId = current.compositeWardId;
  }

  List<ResolvedWardLocation> get _allWards =>
      NepalAdminHierarchyCatalog.allReferenceWards;

  List<MapEntry<int, String>> get _provinces {
    final seen = <int, String>{};
    for (final w in _allWards) {
      seen[w.provinceCode] = '${w.provinceNameNp} (${w.provinceName})';
    }
    return seen.entries.toList();
  }

  List<MapEntry<int, String>> get _districtsForProvince {
    final seen = <int, String>{};
    for (final w in _allWards) {
      if (w.provinceCode == _selectedProvinceCode) {
        seen[w.districtCode] = '${w.districtNameNp} (${w.districtName})';
      }
    }
    return seen.entries.toList();
  }

  List<MapEntry<String, String>> get _palikasForDistrict {
    final seen = <String, String>{};
    for (final w in _allWards) {
      if (w.provinceCode == _selectedProvinceCode &&
          w.districtCode == _selectedDistrictCode) {
        seen[w.palikaCode] = '${w.palikaNameNp} (${w.palikaName})';
      }
    }
    return seen.entries.toList();
  }

  List<ResolvedWardLocation> get _wardsForPalika {
    return _allWards
        .where((ResolvedWardLocation w) =>
            w.provinceCode == _selectedProvinceCode &&
            w.districtCode == _selectedDistrictCode &&
            w.palikaCode == _selectedPalikaCode)
        .toList();
  }

  void _onProvinceChanged(int? provinceCode) {
    if (provinceCode == null) return;
    final firstInProvince = _allWards.firstWhere(
      (ResolvedWardLocation w) => w.provinceCode == provinceCode,
    );
    setState(() {
      _selectedProvinceCode = provinceCode;
      _selectedDistrictCode = firstInProvince.districtCode;
      _selectedPalikaCode = firstInProvince.palikaCode;
      _selectedCompositeWardId = firstInProvince.compositeWardId;
    });
  }

  void _onDistrictChanged(int? districtCode) {
    if (districtCode == null) return;
    final firstInDistrict = _allWards.firstWhere(
      (ResolvedWardLocation w) =>
          w.provinceCode == _selectedProvinceCode &&
          w.districtCode == districtCode,
    );
    setState(() {
      _selectedDistrictCode = districtCode;
      _selectedPalikaCode = firstInDistrict.palikaCode;
      _selectedCompositeWardId = firstInDistrict.compositeWardId;
    });
  }

  void _onPalikaChanged(String? palikaCode) {
    if (palikaCode == null) return;
    final firstInPalika = _allWards.firstWhere(
      (ResolvedWardLocation w) => w.palikaCode == palikaCode,
    );
    setState(() {
      _selectedPalikaCode = palikaCode;
      _selectedCompositeWardId = firstInPalika.compositeWardId;
    });
  }

  void _onWardChanged(String? compositeWardId) {
    if (compositeWardId == null) return;
    setState(() {
      _selectedCompositeWardId = compositeWardId;
    });
  }

  Future<void> _applySelection() async {
    await widget.locationNotifier.selectManualWard(_selectedCompositeWardId);
    if (widget.isModal && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provinces = _provinces;
    final districts = _districtsForProvince;
    final palikas = _palikasForDistrict;
    final wards = _wardsForPalika;

    return Card(
      key: const Key('cascading_location_picker_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: NepalGovTheme.royalNepalBlue, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.location_searching_rounded,
                  color: NepalGovTheme.royalNepalBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select Your Palika • आफ्नो पालिका र वडा छान्नुहोस्',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: NepalGovTheme.darkSlateCard,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('detect_gps_pokhara_button'),
                  onPressed: () async {
                    await widget.locationNotifier.resolvePhysicalLocation(
                      simulatedLat: 28.2096,
                      simulatedLng: 83.9595,
                    );
                    if (widget.isModal && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('GPS'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Zero Defaulting Policy: Province -> District -> Palika -> Ward (प्रदेश -> जिल्ला -> पालिका -> वडा)',
              style: NepalGovTheme.monoTelemetry(
                fontSize: 11.5,
                color: NepalGovTheme.mutedInk,
              ),
            ),
            const SizedBox(height: 12),
            // 1. Province Dropdown
            DropdownButtonFormField<int>(
              key: const Key('location_picker_province_dropdown'),
              isExpanded: true,
              initialValue: _selectedProvinceCode,
              decoration: const InputDecoration(
                labelText: '1. Province / प्रदेश',
                isDense: true,
              ),
              items: provinces
                  .map(
                    (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onProvinceChanged,
            ),
            const SizedBox(height: 10),
            // 2. District Dropdown
            DropdownButtonFormField<int>(
              key: const Key('location_picker_district_dropdown'),
              isExpanded: true,
              initialValue: _selectedDistrictCode,
              decoration: const InputDecoration(
                labelText: '2. District / जिल्ला',
                isDense: true,
              ),
              items: districts
                  .map(
                    (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onDistrictChanged,
            ),
            const SizedBox(height: 10),
            // 3. Palika Dropdown
            DropdownButtonFormField<String>(
              key: const Key('location_picker_palika_dropdown'),
              isExpanded: true,
              initialValue: _selectedPalikaCode,
              decoration: const InputDecoration(
                labelText: '3. Palika (Local Level) / पालिका',
                isDense: true,
              ),
              items: palikas
                  .map(
                    (MapEntry<String, String> entry) =>
                        DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onPalikaChanged,
            ),
            const SizedBox(height: 10),
            // 4. Ward Dropdown
            DropdownButtonFormField<String>(
              key: const Key('location_picker_ward_dropdown'),
              isExpanded: true,
              initialValue: _selectedCompositeWardId,
              decoration: const InputDecoration(
                labelText: '4. Ward / वडा नं.',
                isDense: true,
              ),
              items: wards
                  .map(
                    (ResolvedWardLocation w) => DropdownMenuItem<String>(
                      value: w.compositeWardId,
                      child: Text(
                        'वडा ${w.wardNo} - ${w.localityNameNp} (Ward ${w.wardNo} ${w.localityName})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onWardChanged,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('location_picker_apply_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NepalGovTheme.royalNepalBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _applySelection,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Apply Spatial Context • स्थान लागू गर्नुहोस्',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
