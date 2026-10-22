import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/widgets/arogya_shared_widgets.dart';
import 'legal_viewer_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loggingOut = false;

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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out?',
        ),
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

    setState(() => _loggingOut = true);
    try {
      final uid = _getEffectiveUid();
      try {
        await ref.read(apiClientProvider).logout(uid: uid);
      } catch (_) {}

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      context.go('/auth');
    } catch (_) {
      if (mounted) {
        context.go('/auth');
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    final uid = _getEffectiveUid();
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('settings')
          .set({key: value}, SetOptions(merge: true));

      await ref.read(apiClientProvider).updateUserPreferences(
        uid,
        {key: value},
      );
    } catch (_) {}
  }

  void _openEditProfileSheet(Map<String, dynamic> currentProfile) {
    final uid = _getEffectiveUid();
    final wardState = ref.read(activeWardProvider);
    final nameCtrl = TextEditingController(
      text: currentProfile['name']?.toString() ??
          (wardState.officerName.isNotEmpty ? wardState.officerName : 'Shivam Yadav'),
    );
    final emailCtrl = TextEditingController(
      text: currentProfile['email']?.toString() ??
          (wardState.officerEmail.isNotEmpty ? wardState.officerEmail : 'academyxshivam@gmail.com'),
    );
    final phoneCtrl = TextEditingController(
      text: currentProfile['phone']?.toString() ??
          (wardState.officerPhone.isNotEmpty ? wardState.officerPhone : '+91 99155 49458'),
    );
    final wardCtrl = TextEditingController(
      text: currentProfile['assigned_ward']?.toString() ?? wardState.wardName,
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
                                final initial =
                                    newName.isNotEmpty ? newName[0].toUpperCase() : 'S';

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
                                      .set(updatePayload, SetOptions(merge: true));

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
                                        content: Text('Account details updated successfully'),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  setSheetState(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Details',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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

  void _openNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alert Severity Thresholds',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the minimum alert level that triggers push & SMS vector alarms:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            _buildThresholdTile('Critical Only (>20 Breteau Index)', true),
            _buildThresholdTile('High & Outbreak (>10 Breteau Index)', true),
            _buildThresholdTile('Routine Weekly Surveillance Reports', false),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdTile(String title, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: active ? const Color(0xFF8B0000) : const Color(0xFF94A3B8),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _getEffectiveUid();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ArogyaTopShellBar(activeTabIndex: 4),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() ?? {};
          final officerName =
              userData['name']?.toString() ?? 'Shivam Yadav';
          final avatarInitial = (userData['avatar_initials']?.toString().isNotEmpty ?? false)
              ? userData['avatar_initials'].toString()[0].toUpperCase()
              : (officerName.isNotEmpty ? officerName[0].toUpperCase() : 'S');

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('preferences')
                .doc('settings')
                .snapshots(),
            builder: (context, prefSnap) {
              final prefData = prefSnap.data?.data() ?? {};
              final pushEnabled =
                  prefData['push_notifications_enabled'] as bool? ?? true;
              final emailEnabled =
                  prefData['email_notifications_enabled'] as bool? ?? true;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('app_config')
                    .doc('metadata')
                    .snapshots(),
                builder: (context, metaSnap) {
                  final metaData = metaSnap.data?.data() ?? {};
                  final appVersion =
                      metaData['app_version']?.toString() ?? 'v1.0.0';

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // Component A: Officer Profile Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B0000),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F8B0000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: Text(
                                avatarInitial,
                                style: const TextStyle(
                                  color: Color(0xFF8B0000),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                officerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF8B0000),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _openEditProfileSheet(userData),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text(
                                'Account Settings',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // NOTIFICATIONS Section
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'NOTIFICATIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Component B: Notifications Section Card
                      Container(
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
                          children: [
                            // 1. Push Notifications
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Color(0xFF8B0000),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Push Notifications',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'High-priority outbreak & dispatch alerts',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: pushEnabled,
                                    activeColor: const Color(0xFF8B0000),
                                    activeTrackColor: const Color(0xFFFFCDD2),
                                    onChanged: (val) => _updatePreference(
                                      'push_notifications_enabled',
                                      val,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 58,
                              color: Color(0xFFF1F5F9),
                            ),

                            // 2. Email Notifications
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.mail_outline_rounded,
                                      color: Color(0xFF475569),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Email Notifications',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Weekly IDSP summary digests & reports',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: emailEnabled,
                                    activeColor: const Color(0xFF8B0000),
                                    activeTrackColor: const Color(0xFFFFCDD2),
                                    onChanged: (val) => _updatePreference(
                                      'email_notifications_enabled',
                                      val,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 58,
                              color: Color(0xFFF1F5F9),
                            ),

                            // 3. Notification Settings
                            InkWell(
                              onTap: _openNotificationSettings,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.tune_rounded,
                                        color: Color(0xFF475569),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Notification Settings',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // LEGAL & ABOUT Section
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'LEGAL & ABOUT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Component C: Legal & About Section Card
                      Container(
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
                          children: [
                            // 1. Privacy Policy
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LegalViewerScreen(
                                      title: 'Privacy Policy',
                                      documentType: 'privacy',
                                    ),
                                  ),
                                );
                              },
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.shield_outlined,
                                        color: Color(0xFF475569),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 58,
                              color: Color(0xFFF1F5F9),
                            ),

                            // 2. Terms of Service
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LegalViewerScreen(
                                      title: 'Terms of Service',
                                      documentType: 'terms',
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.description_outlined,
                                        color: Color(0xFF475569),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 58,
                              color: Color(0xFFF1F5F9),
                            ),

                            // 3. Open Source Licenses
                            InkWell(
                              onTap: () {
                                showLicensePage(
                                  context: context,
                                  applicationName: 'Arogya Drishti',
                                  applicationVersion: appVersion,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.code_rounded,
                                        color: Color(0xFF475569),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Open Source Licenses',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 58,
                              color: Color(0xFFF1F5F9),
                            ),

                            // 4. About Arogya Drishti
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFF475569),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'About Arogya Drishti',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    appVersion,
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Component D: Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEBEE),
                            foregroundColor: const Color(0xFFB71C1C),
                            elevation: 0,
                            side: const BorderSide(
                              color: Color(0xFFFFCDD2),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loggingOut ? null : _handleLogout,
                          icon: _loggingOut
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFB71C1C),
                                  ),
                                )
                              : const Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                  color: Color(0xFFB71C1C),
                                ),
                          label: Text(
                            _loggingOut ? 'Logging out...' : 'Logout',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Component E: Footer
                      Center(
                        child: Column(
                          children: const [
                            Text(
                              'Arogya Drishti • Team Rocket',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Google Developer Groups Chandigarh',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
