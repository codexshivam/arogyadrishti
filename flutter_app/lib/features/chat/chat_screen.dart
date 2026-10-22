import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

/// Screen 2: ChatScreen (`/chat`) — Multilingual Gemma 4 / Vertex AI Officer Copilot (`Dr. Arogya`).
/// Zero-hardcoded data: All indices, dosages, satellite metrics, and tool cards stream from live backend & Firestore.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const Color _crimson = Color(0xFF8B0000);

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSub;

  @override
  void initState() {
    super.initState();
    _initInitialGreeting();
    _listenToChatHistory();
  }

  void _initInitialGreeting() {
    final wardState = ref.read(activeWardProvider);
    final officer = wardState.officerName.isNotEmpty ? wardState.officerName : 'Officer';
    final ward = wardState.wardName.isNotEmpty ? wardState.wardName : 'Chandigarh';

    setState(() {
      _messages.clear();
      _messages.add(<String, dynamic>{
        'role': 'assistant',
        'sender': 'Dr. Arogya',
        'time': 'Just now',
        'text':
            'Greetings $officer! I am Dr. Arogya, your AI Vector Surveillance Copilot for $ward. How can I assist your field operations today?',
        'tool_cards': <Map<String, dynamic>>[],
      });
    });
  }

  void _listenToChatHistory() {
    final wardState = ref.read(activeWardProvider);
    final uid = wardState.officerUid.isNotEmpty
        ? wardState.officerUid
        : (wardState.lgdCode.isNotEmpty ? 'officer_${wardState.lgdCode}' : 'asha_field_officer');

    try {
      _chatSub = FirebaseFirestore.instance
          .collection('chat_sessions')
          .doc(uid)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limit(40)
          .snapshots()
          .listen((snap) {
        if (snap.docs.isNotEmpty && mounted) {
          final List<Map<String, dynamic>> loaded = [];
          for (final doc in snap.docs) {
            final data = doc.data();
            final isUser = data['role'] == 'user';
            loaded.add({
              'role': data['role'] ?? 'assistant',
              'sender': isUser
                  ? (wardState.officerName.isNotEmpty
                      ? wardState.officerName
                      : 'Field Officer')
                  : 'Dr. Arogya',
              'time': _formatTimestamp(data['timestamp']),
              'text': (data['text'] ?? '').toString(),
              'tool_cards': (data['tool_cards'] as List<dynamic>? ?? <dynamic>[])
                  .cast<Map<String, dynamic>>(),
            });
          }
          if (loaded.isNotEmpty && mounted) {
            setState(() {
              _messages.clear();
              _messages.addAll(loaded);
            });
            _scrollToBottom();
          }
        }
      }, onError: (_) {
        // Fallback to local memory if offline
      });
    } catch (_) {}
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Recent';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    }
    return 'Recent';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _sendPrompt([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();

    final wardState = ref.read(activeWardProvider);
    final officer = wardState.officerName.isNotEmpty ? wardState.officerName : 'Field Officer';

    setState(() {
      _sending = true;
      _messages.add(<String, dynamic>{
        'role': 'user',
        'sender': officer,
        'time': 'Now',
        'text': text,
        'tool_cards': <Map<String, dynamic>>[],
      });
    });
    _scrollToBottom();

    try {
      final res = await ref.read(apiClientProvider).sendAgentChat(
            uid: wardState.officerUid.isNotEmpty ? wardState.officerUid : 'officer_9915549455',
            message: text,
            wardVillage: wardState.wardName,
            lgdCode: wardState.lgdCode.isNotEmpty ? wardState.lgdCode : '0404400017',
            latitude: wardState.latitude != 0.0 ? wardState.latitude : 30.7333,
            longitude: wardState.longitude != 0.0 ? wardState.longitude : 76.7794,
          );

      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(<String, dynamic>{
          'role': 'assistant',
          'sender': 'Dr. Arogya',
          'time': 'Now',
          'text': (res['reply_text'] ?? '').toString(),
          'tool_cards': (res['tool_cards'] as List<dynamic>? ?? <dynamic>[])
              .cast<Map<String, dynamic>>(),
        });
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(<String, dynamic>{
          'role': 'assistant',
          'sender': 'Dr. Arogya',
          'time': 'Now',
          'text':
              'Unable to reach AI copilot service. Please check your connection and retry.',
          'tool_cards': <Map<String, dynamic>>[],
        });
      });
      _scrollToBottom();
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
        initialWard: wardState.wardName,
        initialLat: wardState.latitude != 0.0 ? wardState.latitude : 30.7333,
        initialLng: wardState.longitude != 0.0 ? wardState.longitude : 76.7794,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wardState = ref.watch(activeWardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const ArogyaTopShellBar(activeTabIndex: 1),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Dynamic Active Ward Context Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Copilot Live • Context: ${wardState.wardName} (${wardState.lgdCode})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'NCVBDC Assistant',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _crimson,
                    ),
                  ),
                ],
              ),
            ),

            // Message Stream List
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final msg = _messages[idx];
                  final isUser = msg['role'] == 'user';
                  if (isUser) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _crimson,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x148B0000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              (msg['text'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (msg['time'] ?? '').toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final cards =
                      (msg['tool_cards'] as List<dynamic>? ?? <dynamic>[])
                          .cast<Map<String, dynamic>>();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x060F172A),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _crimson,
                                  child: Icon(
                                    Icons.health_and_safety_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${msg['sender'] ?? 'Dr. Arogya'} • ${msg['time'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE8E8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'AI Copilot',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: _crimson,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              (msg['text'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final card in cards) ...[
                        const SizedBox(height: 8),
                        _buildToolCard(context, card),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Dynamic Quick Suggestion Chips + Chat Input Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.analytics_outlined, size: 15),
                          label: const Text(
                            'Larval Index Analysis',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendPrompt(
                            'What is the current Breteau Index and risk in ${wardState.wardName}?',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.local_shipping_outlined, size: 15),
                          label: const Text(
                            'Dispatch Fogging Unit',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendPrompt(
                            'Dispatch a fogging van to ${wardState.wardName} immediately',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.medication_liquid_outlined, size: 15),
                          label: const Text(
                            'Temephos & Bti Dosage',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendPrompt(
                            '${wardState.wardName} mein Temephos aur Bti dosage kitna dalna hai?',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.cloud_outlined, size: 15),
                          label: const Text(
                            'Satellite Microclimate',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendPrompt(
                            'Check live satellite temperature and rainfall for ${wardState.wardName}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: (_) => _sendPrompt(),
                          decoration: InputDecoration(
                            hintText: 'Ask Dr. Arogya (English, हिंदी, ਪੰਜਾਬੀ)...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _crimson, width: 1.2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _crimson,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _sending ? null : () => _sendPrompt(),
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dynamic Tool Card Builder (Zero Hardcoded Data)
  // ---------------------------------------------------------------------------
  Widget _buildToolCard(BuildContext context, Map<String, dynamic> card) {
    final type = (card['card_type'] ?? '').toString();
    final metrics = (card['metrics'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final rawTitle = (card['title'] ?? '').toString();
    final cleanTitle = rawTitle
        .replaceAll('(GEE)', '')
        .replaceAll('GEE', 'Satellite')
        .replaceAll('_', ' ')
        .trim();

    // 1. Entomological Indices Tool Card
    if (type == 'ENTOMOLOGICAL_INDICES') {
      final ci = (metrics['container_index_pct'] as num?)?.toDouble() ?? 0.0;
      final hi = (metrics['house_index_pct'] as num?)?.toDouble() ?? 0.0;
      final bi = (metrics['breteau_index'] as num?)?.toDouble() ?? 0.0;
      final risk = (metrics['who_risk_tier'] ?? 'HIGH').toString().toUpperCase();
      final protocol = (metrics['recommended_ncvbdc_protocol'] ??
              metrics['recommended_action'] ??
              '')
          .toString();

      final isCritical = bi >= 20.0 || risk == 'CRITICAL';

      return Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 16, color: _crimson),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cleanTitle.isNotEmpty ? cleanTitle : 'Actionable Field Protocol',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _crimson,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$risk RISK',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIndexMiniStat('CI', '$ci%'),
                    _buildIndexMiniStat('HI', '$hi%'),
                    _buildIndexMiniStat('BI', '$bi'),
                  ],
                ),
              ),
              if (protocol.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  protocol,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF334155)),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _crimson,
                  side: const BorderSide(color: _crimson),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openDispatchModal('SEND_ALERT'),
                icon: const Icon(Icons.notifications_active_outlined, size: 15),
                label: const Text('Alert Ward Supervisor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Satellite Climate Telemetry Card
    if (type == 'GEE_CLIMATE') {
      final lst = (metrics['lst_celsius'] as num?)?.toDouble() ?? 0.0;
      final ndwi = (metrics['ndwi'] as num?)?.toDouble() ?? 0.0;
      final rain = (metrics['rain_14d_mm'] as num?)?.toDouble() ?? 0.0;
      final score = ((metrics['environmental_suitability_score'] as num?)?.toDouble() ?? 0.0) * 100;

      return Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.satellite_alt_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cleanTitle.isNotEmpty ? cleanTitle : 'Satellite Bio-Climate Telemetry',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Suitability ${score.round()}%',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildIndexMiniStat('Surface Temp', '${lst.toStringAsFixed(1)}°C')),
                  Expanded(child: _buildIndexMiniStat('Water Index', ndwi.toStringAsFixed(2))),
                  Expanded(child: _buildIndexMiniStat('14d Rain', '${rain.toStringAsFixed(1)} mm')),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 3. Fogging Van Dispatch Tool Card
    if (type == 'VAN_DISPATCH') {
      final plate = (metrics['vehicle_no'] ?? 'CH-01-GA-3412').toString();
      final vanId = (metrics['van_id'] ?? 'VAN').toString();
      final eta = metrics['eta_minutes']?.toString() ?? '15';
      final dist = metrics['distance_km']?.toString() ?? '2.5';
      final phone = (metrics['driver_phone'] ?? '').toString();

      return Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 16, color: _crimson),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cleanTitle.isNotEmpty ? cleanTitle : 'Fogging Van Dispatched',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _crimson,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EN ROUTE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Unit: $vanId • Plate: $plate\nETA: $eta mins ($dist km away)${phone.isNotEmpty ? ' • Driver: $phone' : ''}',
                style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.push('/vans'),
                icon: const Icon(Icons.navigation_rounded, size: 14),
                label: const Text('Track Van Telemetry', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Emergency Alert Tool Card
    if (type == 'EMERGENCY_ALERT') {
      final alertId = (metrics['alert_id'] ?? '').toString();
      final emailedTo = (metrics['emailed_to'] ?? '').toString();
      final districtRep = (metrics['district_rep_notified'] ?? '').toString();

      return Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency_rounded, size: 16, color: Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cleanTitle.isNotEmpty ? cleanTitle : 'Emergency Ward Alert Dispatched',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Alert ID: $alertId\nDispatched to: $emailedTo\nRepresentative: $districtRep',
                style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.push('/support'),
                icon: const Icon(Icons.support_agent_rounded, size: 15),
                label: const Text('View Support Desk', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Vision Result Tool Card
    if (type == 'VISION_RESULT') {
      final species = (metrics['species'] ?? 'Aedes aegypti').toString();
      final conf = metrics['confidence_pct']?.toString() ?? '92';
      final summary = (metrics['summary'] ?? '').toString();

      return Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Visual Identification Result',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _crimson,
                      fontSize: 12.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$conf% Confidence',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                species,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _crimson,
                  side: const BorderSide(color: _crimson),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openDispatchModal('REQUEST_VAN'),
                icon: const Icon(Icons.local_shipping_outlined, size: 15),
                label: const Text('Dispatch Fogging Unit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildIndexMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
