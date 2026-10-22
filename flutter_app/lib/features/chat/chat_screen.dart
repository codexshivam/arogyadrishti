import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/services/firestore_sync.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

/// Screen 2: ChatScreen (`/chat`) — Multilingual Gemma 4 / Vertex AI Officer Copilot (`Dr. Arogya`).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[
    <String, dynamic>{
      'role': 'assistant',
      'sender': 'Dr. Arogya',
      'time': '10:41 AM',
      'text': 'Greetings! How can I assist you today?',
      'tool_cards': <Map<String, dynamic>>[],
    },
    <String, dynamic>{
      'role': 'user',
      'time': '10:42 AM',
      'text':
          'Found 14 discarded tires with stagnant rainwater behind Community Center, Ward 14. 6 contain active pupae/larvae. What is the immediate protocol?',
    },
    <String, dynamic>{
      'role': 'assistant',
      'sender': 'Dr. Arogya',
      'time': '10:42 AM',
      'text':
          'Multimodal vision & NCVBDC Vector Surveillance Skill executed for your sector:',
      'tool_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'card_type': 'ENTOMOLOGICAL_INDICES',
          'title': 'Actionable Field Protocol',
          'metrics': <String, dynamic>{
            'container_index_pct': 42.8,
            'breteau_index': 34.0,
            'house_index_pct': 14.2,
            'who_risk_tier': 'High Risk Tier 1',
          },
        },
        <String, dynamic>{
          'card_type': 'VISION_RESULT',
          'title': 'Visual Identification Result',
          'metrics': <String, dynamic>{
            'confidence_pct': 98.2,
            'species': 'Aedes aegypti (Stegomyia)',
            'summary':
                'Multimodal vision verified Aedes aegypti IV-instar larvae. Prominent siphon tube angle detected. Immediate pyriproxyfen or temephos application advised.',
          },
        },
      ],
    },
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();

    final wardState = ref.read(activeWardProvider);
    setState(() {
      _sending = true;
      _messages.add(<String, dynamic>{
        'role': 'user',
        'time': 'Now',
        'text': text,
      });
    });

    try {
      final res = await ref.read(apiClientProvider).sendAgentChat(
            uid: wardState.officerUid,
            message: text,
            wardVillage: wardState.wardName.split(',').first.trim(),
            lgdCode: wardState.lgdCode,
            latitude: wardState.latitude,
            longitude: wardState.longitude,
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(<String, dynamic>{
          'role': 'assistant',
          'sender': 'Dr. Arogya (${res['model_used'] ?? 'Gemma 4'})',
          'time': 'Now',
          'text': (res['reply_text'] ?? '').toString(),
          'tool_cards': (res['tool_cards'] as List<dynamic>? ?? <dynamic>[])
              .cast<Map<String, dynamic>>(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(<String, dynamic>{
          'role': 'assistant',
          'sender': 'Dr. Arogya (Offline Skill Cache)',
          'time': 'Now',
          'text':
              'NCVBDC Standard Protocol for ${wardState.wardName}:\n• Apply Temephos 50% EC @ 1 ppm (1 ml per 1,000 L) in overhead tanks/coolers.\n• Broadcast Bti Granules @ 5–10 g/m² in open drains.\n• Schedule 100m perimeter ULV Pyrethrum 2% fogging within 24h.',
          'tool_cards': <Map<String, dynamic>>[],
        });
      });
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
        initialWard: wardState.wardName.split(',').first,
        initialLat: wardState.latitude,
        initialLng: wardState.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ArogyaTopShellBar(activeTabIndex: 1),
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
                          gradient: ArogyaTheme.crimsonHeaderGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          (msg['text'] ?? '').toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
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
                          color: ArogyaTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ArogyaTheme.borderHairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: ArogyaTheme.primaryCrimson,
                                  child: Icon(
                                    Icons.health_and_safety_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${msg['sender'] ?? 'Dr. Arogya'}  ${msg['time'] ?? ''}',
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                                const AiSparkChip(label: 'Gemma 4 Skill'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (msg['text'] ?? '').toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      for (final card in cards) ...[
                        const SizedBox(height: 10),
                        _buildToolCard(context, card),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Quick Suggestion Chips + Chat Input Bar
            Container(
              color: ArogyaTheme.surfaceWhite,
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
                            'What is the current Breteau Index and satellite risk in my sector?',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(
                            Icons.local_shipping_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'Dispatch Fogging Team',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendPrompt(
                            'Dispatch a fogging van to Sector 22-B immediately',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.translate_rounded, size: 15),
                          label: const Text(
                            'Hindi Dosage (Temephos)',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => _sendPrompt(
                            'Sector 22-B mein Temephos kitna dalna hai?',
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
                          decoration: const InputDecoration(
                            hintText: 'Ask our AI (English, हिंदी, ਪੰਜਾਬੀ)...',
                            prefixIcon: Icon(Icons.mic_none_rounded, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
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
                              : const Icon(Icons.send_rounded, size: 20),
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

  Widget _buildToolCard(BuildContext context, Map<String, dynamic> card) {
    final type = (card['card_type'] ?? '').toString();
    final metrics =
        (card['metrics'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    if (type == 'VISION_RESULT') {
      return Card(
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
                      color: ArogyaTheme.primaryCrimson,
                      fontSize: 12.5,
                    ),
                  ),
                  TriageBadge(
                    label: '${metrics['confidence_pct'] ?? 98.2}% Confidence',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.biotech_rounded,
                      color: Color(0xFF38BDF8),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (metrics['species'] ?? 'Aedes aegypti (Stegomyia)')
                            .toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (metrics['summary'] ?? '').toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                    ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openDispatchModal('REQUEST_VAN'),
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Dispatch Fogging Unit'),
              ),
            ],
          ),
        ),
      );
    }

    final ci = metrics['container_index_pct'] ?? 42.8;
    final bi = metrics['breteau_index'] ?? 34.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: ArogyaTheme.primaryCrimson,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (card['title'] ?? 'Actionable Field Protocol').toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ArogyaTheme.primaryCrimson,
                      fontSize: 12.5,
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
                color: ArogyaTheme.triageRedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Container Index (CI) & Breteau Index (BI)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: ArogyaTheme.triageRedText,
                    ),
                  ),
                  Text(
                    'CI $ci% · BI $bi — High Risk Tier 1',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ArogyaTheme.triageRedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. Physical Source Reduction: Drain stagnant water immediately; puncture or store discarded tires under a covered shed within 24 hours.\n'
              '2. Chemical Larvicidal Treatment: Apply Temephos 50% EC @ 1 ppm (1 ml per 1,000 L) or Bti Granules (5–10 g/m² water surface area).\n'
              '3. 100m Perimeter Surveillance: Schedule ULV Pyrethrum 2% thermal fogging across adjacent residential households.',
              style: TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openDispatchModal('SEND_ALERT'),
              icon: const Icon(
                Icons.notifications_active_outlined,
                size: 16,
                color: ArogyaTheme.primaryCrimson,
              ),
              label: const Text('Alert Ward Supervisor'),
            ),
          ],
        ),
      ),
    );
  }
}
