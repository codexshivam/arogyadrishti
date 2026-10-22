import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plump_icons/plump_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

/// State representation for Home Screen Command Center
class HomeState {
  final bool isSyncing;
  final int pendingWriteCount;
  final String locationSearchQuery;

  const HomeState({
    this.isSyncing = false,
    this.pendingWriteCount = 0,
    this.locationSearchQuery = '',
  });

  HomeState copyWith({
    bool? isSyncing,
    int? pendingWriteCount,
    String? locationSearchQuery,
  }) {
    return HomeState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingWriteCount: pendingWriteCount ?? this.pendingWriteCount,
      locationSearchQuery: locationSearchQuery ?? this.locationSearchQuery,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel() : super(const HomeState());

  void setSyncing(bool val) => state = state.copyWith(isSyncing: val);
  void setPendingWriteCount(int count) =>
      state = state.copyWith(pendingWriteCount: count);
  void setSearchQuery(String q) =>
      state = state.copyWith(locationSearchQuery: q);
}

final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((
  ref,
) {
  return HomeViewModel();
});

/// Screen 1: HomeScreen (`/home`) — Primary Command Center for frontline health workers
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _housesInspectedController = TextEditingController();
  final _housesPositiveController = TextEditingController();
  final _containersCheckedController = TextEditingController();
  final _containersPositiveController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String _selectedWardLgd = '0404400014';
  String _selectedWardName = 'Ward 14 – Dhanas';
  String _selectedTreatment = 'Temephos 50% EC Applied';
  String _searchFilter = '';

  bool _locating = false;
  bool _savingLog = false;
  List<Map<String, dynamic>> _availableWards = [];

  static const List<String> _treatments = <String>[
    'Temephos 50% EC Applied',
    'Bti Granules',
    'Pyrethrum Spray',
    'Source Drained',
    'None',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();

    final ward = ref.read(activeWardProvider);
    if (ward.lgdCode.isNotEmpty) {
      _selectedWardLgd = ward.lgdCode;
      _selectedWardName = ward.wardName;
    }
    _loadAvailableWards();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _housesInspectedController.dispose();
    _housesPositiveController.dispose();
    _containersCheckedController.dispose();
    _containersPositiveController.dispose();
    super.dispose();
  }

  String _getEffectiveUid() {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid.isNotEmpty) {
      return authUser.uid;
    }
    final wardState = ref.read(activeWardProvider);
    if (wardState.officerPhone.isNotEmpty) {
      final clean = wardState.officerPhone.replaceAll(RegExp(r'\D'), '');
      return 'user_$clean';
    }
    return 'user_9915549458';
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING,';
    if (hour < 17) return 'GOOD AFTERNOON,';
    return 'GOOD EVENING,';
  }

  Future<void> _loadAvailableWards() async {
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.fetchLocationsWards();
      final wardsList = (resp['wards'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (wardsList.isNotEmpty && mounted) {
        setState(() {
          _availableWards = wardsList;
          final match = wardsList.firstWhere(
            (w) => w['lgd_code'] == _selectedWardLgd,
            orElse: () => wardsList.first,
          );
          _selectedWardLgd = match['lgd_code'].toString();
          _selectedWardName = match['ward_name'].toString();
        });
        return;
      }
    } catch (_) {}

    try {
      final snap = await FirebaseFirestore.instance
          .collection('wards')
          .orderBy('ward_no')
          .limit(40)
          .get();
      final wardList = snap.docs.map((d) {
        final data = d.data();
        return {
          'lgd_code': d.id,
          'ward_name': (data['ward_name'] ?? d.id).toString(),
          'lat': (data['lat'] as num?)?.toDouble() ?? 30.7675,
          'lng': (data['lng'] as num?)?.toDouble() ?? 76.7460,
        };
      }).toList();

      if (wardList.isNotEmpty && mounted) {
        setState(() {
          _availableWards = wardList;
          _selectedWardLgd = wardList.first['lgd_code'].toString();
          _selectedWardName = wardList.first['ward_name'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _resolveCurrentGpsWard() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        String wardLabel = 'Sector 22-B, Chandigarh';
        try {
          final placemarks = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
          if (placemarks.isNotEmpty) {
            final pm = placemarks.first;
            final sub = (pm.subLocality ?? pm.locality ?? 'Sector 22-B').trim();
            final city = (pm.locality ?? pm.administrativeArea ?? 'Chandigarh')
                .trim();
            wardLabel = '$sub, $city';
          }
        } catch (_) {}

        ref
            .read(activeWardProvider.notifier)
            .updateWard(
              lgdCode: _selectedWardLgd,
              wardName: wardLabel,
              district: 'Chandigarh',
              latitude: pos.latitude,
              longitude: pos.longitude,
            );

        setState(() {
          _selectedWardName = wardLabel;
        });
      }
    } catch (_) {
      ref
          .read(activeWardProvider.notifier)
          .updateWard(
            lgdCode: '0404400017',
            wardName: 'Sector 22-B, Chandigarh',
            district: 'Chandigarh',
            latitude: 30.7333,
            longitude: 76.7794,
          );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _openDispatchModal(String actionType) {
    final wardState = ref.read(activeWardProvider);
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActionDispatchBottomSheet(
        actionType: actionType,
        initialWard: _selectedWardName,
        initialLat: wardState.latitude,
        initialLng: wardState.longitude,
      ),
    );
  }

  void _openAccountDetailsSheet(Map<String, dynamic> currentProfile) {
    final uid = _getEffectiveUid();
    final wardState = ref.read(activeWardProvider);
    final nameCtrl = TextEditingController(
      text:
          currentProfile['name']?.toString() ??
          (wardState.officerName.isNotEmpty
              ? wardState.officerName
              : 'Shivam Yadav'),
    );
    final emailCtrl = TextEditingController(
      text:
          currentProfile['email']?.toString() ??
          (wardState.officerEmail.isNotEmpty
              ? wardState.officerEmail
              : 'academyxshivam@gmail.com'),
    );
    final phoneCtrl = TextEditingController(
      text:
          currentProfile['phone']?.toString() ??
          (wardState.officerPhone.isNotEmpty
              ? wardState.officerPhone
              : '+91 99155 49458'),
    );
    final wardCtrl = TextEditingController(
      text: currentProfile['assigned_ward']?.toString() ?? _selectedWardName,
    );
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Update Account Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Government Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: wardCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Ward / Jurisdiction',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                final newName = nameCtrl.text.trim();
                                final newEmail = emailCtrl.text.trim();
                                final newPhone = phoneCtrl.text.trim();
                                final newWard = wardCtrl.text.trim();
                                final initial = newName.isNotEmpty
                                    ? newName[0].toUpperCase()
                                    : 'S';

                                final updatePayload = {
                                  'name': newName,
                                  'email': newEmail,
                                  'phone': newPhone,
                                  'assigned_ward': newWard,
                                  'avatar_initials': initial,
                                  'updated_at': FieldValue.serverTimestamp(),
                                };

                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .set(
                                        updatePayload,
                                        SetOptions(merge: true),
                                      );

                                  await ref
                                      .read(apiClientProvider)
                                      .updateUserProfile(uid, {
                                        'name': newName,
                                        'email': newEmail,
                                        'phone': newPhone,
                                        'assigned_ward': newWard,
                                      });

                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account details updated successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  setSheetState(() => saving = false);
                                }
                              },
                        child: Skeletonizer(
                          enabled: saving,
                          child: const Text(
                            'Save Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = _getEffectiveUid();
      try {
        await ref.read(apiClientProvider).logout(uid: uid);
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/auth');
    } catch (_) {
      if (mounted) context.go('/auth');
    }
  }

  Future<void> _saveFieldInspectionLog() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final hInsp = int.tryParse(_housesInspectedController.text.trim()) ?? 0;
    final hPos = int.tryParse(_housesPositiveController.text.trim()) ?? 0;
    final cChk = int.tryParse(_containersCheckedController.text.trim()) ?? 0;
    final cPos = int.tryParse(_containersPositiveController.text.trim()) ?? 0;

    final hi = (hPos / hInsp) * 100.0;
    final ci = (cPos / cChk) * 100.0;
    final bi = (cPos / hInsp) * 100.0;
    final wardState = ref.read(activeWardProvider);

    setState(() => _savingLog = true);
    ref.read(homeViewModelProvider.notifier).setSyncing(true);

    try {
      if (FirestoreSyncService.isFirebaseReady) {
        await FirebaseFirestore.instance.collection('field_logs').add({
          'officer_uid': wardState.officerUid,
          'officer_name': wardState.officerName,
          'lgd_code': _selectedWardLgd,
          'ward_village': _selectedWardName,
          'larvicidal_treatment': _selectedTreatment,
          'houses_inspected': hInsp,
          'houses_positive': hPos,
          'containers_checked': cChk,
          'containers_positive': cPos,
          'computed_hi': double.parse(hi.toStringAsFixed(2)),
          'computed_ci': double.parse(ci.toStringAsFixed(2)),
          'computed_bi': double.parse(bi.toStringAsFixed(2)),
          'latitude': wardState.latitude,
          'longitude': wardState.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await ref
          .read(apiClientProvider)
          .submitFieldLog(
            officerUid: wardState.officerUid,
            officerName: wardState.officerName,
            lgdCode: _selectedWardLgd,
            wardVillage: _selectedWardName,
            larvicidalTreatment: _selectedTreatment,
            housesInspected: hInsp,
            housesPositive: hPos,
            containersChecked: cChk,
            containersPositive: cPos,
            latitude: wardState.latitude,
            longitude: wardState.longitude,
          );

      _housesInspectedController.clear();
      _housesPositiveController.clear();
      _containersCheckedController.clear();
      _containersPositiveController.clear();

      if (!mounted) return;
      setState(() => _savingLog = false);
      ref.read(homeViewModelProvider.notifier).setSyncing(false);

      showArogyaToast(
        context,
        title: 'Inspection Synced',
        message:
            'HI: ${hi.toStringAsFixed(1)}% · CI: ${ci.toStringAsFixed(1)}% · BI: ${bi.toStringAsFixed(1)} recorded to Central Health Registry.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingLog = false);
      ref.read(homeViewModelProvider.notifier).setSyncing(false);
      showArogyaToast(
        context,
        title: 'Inspection Queued Offline',
        message:
            'HI: ${hi.toStringAsFixed(1)}% · CI: ${ci.toStringAsFixed(1)}% · BI: ${bi.toStringAsFixed(1)} queued for auto-sync.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardState = ref.watch(activeWardProvider);
    final uid = _getEffectiveUid();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ArogyaTopShellBar(activeTabIndex: 0),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              color: const Color(0xFF8B0000),
              onRefresh: () async {
                await _loadAvailableWards();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Component A: Top Profile Card (#8B0000 Crimson Theme)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final userData = snapshot.data?.data() ?? {};
                        final officerName =
                            userData['name']?.toString() ??
                            wardState.officerName;
                        final officerPhone =
                            userData['phone']?.toString() ??
                            wardState.officerPhone;
                        final assignedJurisdiction =
                            userData['assigned_ward']?.toString() ??
                            'Chandigarh UT';

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: ArogyaTheme.crimsonHeaderGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x248B0000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getTimeBasedGreeting(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  letterSpacing: 1.1,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                officerName.isNotEmpty
                                    ? officerName
                                    : 'Officer',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                assignedJurisdiction,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                officerPhone.isNotEmpty
                                    ? officerPhone
                                    : '+91 99155 49458',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.12),
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white38,
                                        ),
                                        minimumSize: const Size.fromHeight(38),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _openAccountDetailsSheet(userData),
                                      child: const Text(
                                        'Account Settings',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.12),
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white38,
                                        ),
                                        minimumSize: const Size.fromHeight(38),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: _handleLogout,
                                      child: const Text(
                                        'Log Out',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Component B: Geospatial Location Bar & GPS Resolver
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Color(0xFF8B0000),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Location: $_selectedWardName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8B0000),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) {
                                      setState(() {
                                        _searchFilter = val;
                                      });
                                    },
                                    onSubmitted: (val) {
                                      if (val.trim().isNotEmpty) {
                                        setState(() {
                                          _selectedWardName = val.trim();
                                          _searchFilter = '';
                                        });
                                        ref
                                            .read(
                                              homeViewModelProvider.notifier,
                                            )
                                            .setSearchQuery(val.trim());
                                      }
                                    },
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      suffixIcon: _searchFilter.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                                color: Color(0xFF64748B),
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(
                                                  () => _searchFilter = '',
                                                );
                                              },
                                            )
                                          : null,
                                      hintText:
                                          'Search city, sector, or ward...',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: _locating
                                    ? null
                                    : _resolveCurrentGpsWard,
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFFCDD2),
                                    ),
                                  ),
                                  child: Skeletonizer(
                                    enabled: _locating,
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.my_location_rounded,
                                          size: 15,
                                          color: Color(0xFF8B0000),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Current',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF8B0000),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_searchFilter.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x140F172A),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Builder(
                                  builder: (context) {
                                    final query = _searchFilter
                                        .trim()
                                        .toLowerCase();
                                    final matches = _availableWards.where((w) {
                                      final name = (w['ward_name'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                      final lgd = (w['lgd_code'] ?? '')
                                          .toString();
                                      return name.contains(query) ||
                                          lgd.contains(query);
                                    }).toList();

                                    if (matches.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: Text(
                                            'No locations found for "$_searchFilter"',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: matches.length,
                                      separatorBuilder: (_, _) => const Divider(
                                        height: 1,
                                        color: Color(0xFFF1F5F9),
                                      ),
                                      itemBuilder: (context, idx) {
                                        final match = matches[idx];
                                        final wardName =
                                            match['ward_name']?.toString() ??
                                            '';
                                        final lgd =
                                            match['lgd_code']?.toString() ?? '';
                                        final lat =
                                            (match['lat'] as num?)
                                                ?.toDouble() ??
                                            30.7333;
                                        final lng =
                                            (match['lng'] as num?)
                                                ?.toDouble() ??
                                            76.7794;

                                        return ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          leading: const Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                            color: Color(0xFF8B0000),
                                          ),
                                          title: Text(
                                            wardName,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          subtitle: Text(
                                            'LGD: $lgd',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedWardLgd = lgd;
                                              _selectedWardName = wardName;
                                              _searchFilter = '';
                                              _searchController.clear();
                                            });
                                            ref
                                                .read(
                                                  activeWardProvider.notifier,
                                                )
                                                .updateWard(
                                                  lgdCode: lgd,
                                                  wardName: wardName,
                                                  district: 'Chandigarh',
                                                  latitude: lat,
                                                  longitude: lng,
                                                );
                                            ref
                                                .read(
                                                  homeViewModelProvider
                                                      .notifier,
                                                )
                                                .setSearchQuery(wardName);
                                            FocusScope.of(context).unfocus();
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Component C: Quick Action Cards (Scan, Request Van, Send Alert)
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionTile(
                            plumpIcon: PlumpIcons.irisScanSolid,
                            label: 'Scan',
                            onTap: () => context.push('/scan'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickActionTile(
                            plumpIcon: PlumpIcons.firefighterTruckSolid,
                            label: 'Request Van',
                            onTap: () => _openDispatchModal('REQUEST_VAN'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickActionTile(
                            plumpIcon: PlumpIcons.notificationAlertSolid,
                            label: 'Send Alert',
                            onTap: () => _openDispatchModal('SEND_ALERT'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Component D: Field Vector Inspection Form Card (Offline-First)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey<String>(_selectedWardLgd),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.assignment_turned_in_outlined,
                                      color: Color(0xFF8B0000),
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Field Vector Inspection Form',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Dropdown Row: Ward + Treatment
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Village / Ward',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          DropdownButtonFormField<String>(
                                            value: _selectedWardLgd.isNotEmpty
                                                ? _selectedWardLgd
                                                : null,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            items: _availableWards.map((w) {
                                              return DropdownMenuItem<String>(
                                                value: w['lgd_code'].toString(),
                                                child: Text(
                                                  w['ward_name'].toString(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                final match = _availableWards
                                                    .firstWhere(
                                                      (w) =>
                                                          w['lgd_code']
                                                              .toString() ==
                                                          v,
                                                      orElse: () => {
                                                        'ward_name': v,
                                                      },
                                                    );
                                                setState(() {
                                                  _selectedWardLgd = v;
                                                  _selectedWardName =
                                                      match['ward_name']
                                                          .toString();
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Larvicidal Treatment',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          DropdownButtonFormField<String>(
                                            value: _selectedTreatment,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            items: _treatments.map((t) {
                                              return DropdownMenuItem<String>(
                                                value: t,
                                                child: Text(
                                                  t,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                setState(
                                                  () => _selectedTreatment = v,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Inputs: Houses Inspected & Houses Positive
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricFormField(
                                        label: 'Houses Inspected',
                                        controller: _housesInspectedController,
                                        hintText: 'e.g. 50',
                                        validator: (val) {
                                          final n = int.tryParse(
                                            val?.trim() ?? '',
                                          );
                                          if (n == null || n <= 0)
                                            return 'Enter > 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricFormField(
                                        label: 'Houses Positive',
                                        controller: _housesPositiveController,
                                        hintText: 'e.g. 3',
                                        validator: (val) {
                                          final n = int.tryParse(
                                            val?.trim() ?? '',
                                          );
                                          final tot =
                                              int.tryParse(
                                                _housesInspectedController.text
                                                    .trim(),
                                              ) ??
                                              0;
                                          if (n == null || n < 0)
                                            return 'Invalid';
                                          if (n > tot)
                                            return 'Exceeds inspected';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Inputs: Containers Checked & Containers Positive
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricFormField(
                                        label: 'Containers Checked',
                                        controller:
                                            _containersCheckedController,
                                        hintText: 'e.g. 120',
                                        validator: (val) {
                                          final n = int.tryParse(
                                            val?.trim() ?? '',
                                          );
                                          if (n == null || n <= 0)
                                            return 'Enter > 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricFormField(
                                        label: 'Containers Positive',
                                        controller:
                                            _containersPositiveController,
                                        hintText: 'e.g. 5',
                                        validator: (val) {
                                          final n = int.tryParse(
                                            val?.trim() ?? '',
                                          );
                                          final tot =
                                              int.tryParse(
                                                _containersCheckedController
                                                    .text
                                                    .trim(),
                                              ) ??
                                              0;
                                          if (n == null || n < 0)
                                            return 'Invalid';
                                          if (n > tot) return 'Exceeds checked';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Save & Sync Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B0000),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _savingLog
                                        ? null
                                        : _saveFieldInspectionLog,
                                    icon: const Icon(
                                      Icons.save_outlined,
                                      size: 18,
                                    ),
                                    label: Skeletonizer(
                                      enabled: _savingLog,
                                      child: Text(
                                        _savingLog
                                            ? 'Computing HI/CI/BI & Syncing...'
                                            : 'Save & Sync Inspection',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Component E: More Services Grid (Vans, Centers, Support)
                    const Center(
                      child: Text(
                        'MORE SERVICES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionTile(
                            plumpIcon: PlumpIcons.busSolid,
                            label: 'Vans',
                            onTap: () => context.push('/vans'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickActionTile(
                            plumpIcon: PlumpIcons.hospitalSignSquareSolid,
                            label: 'Centers',
                            onTap: () => context.push('/centers'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickActionTile(
                            plumpIcon: PlumpIcons.userProtectionCheckSolid,
                            label: 'Support',
                            onTap: () => context.push('/support'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.plumpIcon,
    required this.label,
    required this.onTap,
  });

  final PlumpIconData plumpIcon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            constraints: const BoxConstraints(minHeight: 74),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlumpIcon(
                  widget.plumpIcon,
                  color: const Color(0xFF8B0000),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricFormField extends StatelessWidget {
  const _MetricFormField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
