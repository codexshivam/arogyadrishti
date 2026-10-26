import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../viewmodels/copilot_chat_viewmodel.dart';

/// Bilingual Nepali (`नेपाली`) / Maithili / Bhojpuri / Tharu / Newari / English
/// Sovereign Gemma 4 31B Copilot Screen with expandable tool execution trace pills.
class GemmaChatScreen extends StatefulWidget {
  const GemmaChatScreen({
    required this.copilotViewModel,
    super.key,
  });

  final CopilotChatViewModel copilotViewModel;

  @override
  State<GemmaChatScreen> createState() => _GemmaChatScreenState();
}

class _GemmaChatScreenState extends State<GemmaChatScreen> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _promptController.text;
    _promptController.clear();
    await widget.copilotViewModel.sendPrompt(text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.copilotViewModel,
      builder: (BuildContext context, Widget? _) {
        final vm = widget.copilotViewModel;
        return Column(
          key: const Key('gemma_chat_screen'),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: NepalGovTheme.darkSlateCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Gemma 4 31B सार्वभौम सह-चालक (IDMC Singha Durbar)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: vm.selectedLanguage,
                    dropdownColor: NepalGovTheme.darkSlateCard,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    underline: const SizedBox.shrink(),
                    items: CopilotChatViewModel.supportedLanguages.entries
                        .map(
                          (MapEntry<String, String> e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? code) {
                      if (code != null) {
                        vm.setLanguage(code);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vm.messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final msg = vm.messages[index];
                  return Align(
                    alignment: msg.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? NepalGovTheme.darkSlateCard
                            : NepalGovTheme.elevatedPaper,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: NepalGovTheme.borderStone),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            msg.textNe,
                            style: TextStyle(
                              color: msg.isUser
                                  ? Colors.white
                                  : NepalGovTheme.darkSlateCard,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!msg.isUser) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              msg.textEn,
                              style: const TextStyle(
                                color: NepalGovTheme.mutedInk,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          if (msg.toolTraces.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: msg.toolTraces.map((ToolTraceModel t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NepalGovTheme.warmStoneBackground,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: NepalGovTheme.borderStone,
                                    ),
                                  ),
                                  child: Text(
                                    '⚙ ${t.toolName}',
                                    style: NepalGovTheme.monoTelemetry(
                                      fontSize: 11,
                                      color: NepalGovTheme.royalNepalBlue,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('copilot_prompt_input'),
                      controller: _promptController,
                      decoration: const InputDecoration(
                        hintText:
                            'वडा १७ को खोज र नष्ट गर अभियान वा Bti मात्रा सोध्नुहोस्...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('copilot_send_button'),
                    onPressed: _send,
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
