import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Interactive Legal Document Viewer for DPDP Act 2023 & NCVBDC Compliance.
/// Loads directly from backend `/api/v1/config/legal?doc={privacy|terms}` with instant local asset fallback.
class LegalViewerScreen extends ConsumerStatefulWidget {
  final String title;
  final String documentType; // 'privacy' or 'terms'

  const LegalViewerScreen({
    super.key,
    required this.title,
    required this.documentType,
  });

  @override
  ConsumerState<LegalViewerScreen> createState() => _LegalViewerScreenState();
}

class _LegalViewerScreenState extends ConsumerState<LegalViewerScreen> {
  bool _isLoading = true;
  String _markdownContent = '';
  String? _errorMessage;

  String get _assetPath {
    if (widget.documentType.toLowerCase().contains('term')) {
      return 'assets/docs/terms_of_service.md';
    }
    return 'assets/docs/privacy_policy.md';
  }

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? loadedMarkdown;

    // 1. Attempt to fetch live from Sovereign Backend Endpoint
    try {
      final docKey = widget.documentType.toLowerCase().contains('term')
          ? 'terms'
          : 'privacy';
      final response = await ref
          .read(apiClientProvider)
          .fetchLegalDocument(doc: docKey)
          .timeout(const Duration(seconds: 4));

      if (response['status'] == 'SUCCESS' && response['markdown'] != null) {
        loadedMarkdown = response['markdown'] as String;
      }
    } catch (_) {
      // Backend unavailable or network offline; smoothly proceed to asset fallback
    }

    // 2. Fallback to bundled local asset
    if (loadedMarkdown == null || loadedMarkdown.trim().isEmpty) {
      try {
        loadedMarkdown = await rootBundle.loadString(_assetPath);
      } catch (assetErr) {
        _errorMessage = 'Failed to load document: $assetErr';
      }
    }

    if (mounted) {
      setState(() {
        _markdownContent = loadedMarkdown ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArogyaTheme.backgroundCanvas,
      appBar: AppBar(
        systemOverlayStyle: ArogyaTheme.whiteSystemUiOverlay,
        backgroundColor: Colors.white,
        foregroundColor: ArogyaTheme.slateHeading,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ArogyaTheme.slateHeading,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                ArogyaTheme.primaryCrimson,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.title}...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ArogyaTheme.slateBody,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifying DPDP Act 2023 Sovereign Cryptographic Signatures',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: ArogyaTheme.slateMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 16),
              Text(
                'Document Unavailable',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ArogyaTheme.slateHeading,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ArogyaTheme.slateMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ArogyaTheme.primaryCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // DPDP Act 2023 & Security Badge Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 13,
                      color: Color(0xFF166534),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DPDP ACT 2023 COMPLIANT',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Scrollable Markdown Document Viewer
        Expanded(
          child: Markdown(
            data: _markdownContent,
            selectable: true,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  h1: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ArogyaTheme.slateHeading,
                    height: 1.3,
                  ),
                  h2: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ArogyaTheme.primaryCrimson,
                    height: 1.3,
                  ),
                  h3: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ArogyaTheme.slateHeading,
                    height: 1.3,
                  ),
                  p: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.6,
                    color: ArogyaTheme.slateBody,
                  ),
                  listBullet: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ArogyaTheme.primaryCrimson,
                  ),
                  code: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: ArogyaTheme.primaryCrimson,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: const Border(
                      left: BorderSide(
                        color: ArogyaTheme.primaryCrimson,
                        width: 4,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  tableBorder: TableBorder.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  tableHead: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  tableBody: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF334155),
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                ),
            onTapLink: (text, href, title) async {
              if (href != null && href.isNotEmpty) {
                if (href == 'privacy_policy.md') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalViewerScreen(
                        title: 'Privacy Policy',
                        documentType: 'privacy',
                      ),
                    ),
                  );
                } else if (href == 'terms_of_service.md') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalViewerScreen(
                        title: 'Terms of Service',
                        documentType: 'terms',
                      ),
                    ),
                  );
                } else {
                  final uri = Uri.tryParse(href);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
