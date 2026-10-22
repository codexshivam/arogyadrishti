import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/arogya_shared_widgets.dart';

/// Publicly accessible Pre-Authentication Privacy Policy & Terms of Service Screen (`/privacy`)
/// Designed for Google Cloud / Firebase Phone Auth Brand Verification & DPDP Act 2023 compliance.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: ArogyaTheme.whiteSystemUiOverlay,
        backgroundColor: ArogyaTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo/arogya_logo.png',
                width: 32,
                height: 32,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.shield_rounded,
                  color: ArogyaTheme.primaryCrimson,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Arogya — Privacy Policy & Terms',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ArogyaTheme.slateHeading,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/auth'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Officer Sign In'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Brand Identity & Verification Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ArogyaTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ArogyaTheme.borderHairline),
              boxShadow: ArogyaTheme.ambientElevation,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/logo/arogya_logo.png',
                        width: 64,
                        height: 64,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.health_and_safety_rounded,
                          size: 56,
                          color: ArogyaTheme.primaryCrimson,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StatusPillChip(
                            label: 'PUBLIC PRE-AUTH DISCLOSURE',
                            color: ArogyaSpacing.riskSafe,
                            icon: Icons.verified_user_rounded,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Arogya (Arogya Drishti DPI)',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Android Package ID: teamrocket.arogyadrishti.android',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ArogyaTheme.primaryCrimson,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Arogya Drishti ("Arogya") is a Vector-Borne Disease Surveillance Digital Public Infrastructure (DPI) platform developed by Team Rocket (Chandigarh University) aligned with National Center for Vector Borne Diseases Control (NCVBDC), Integrated Health Information Platform (IHIP), and India\'s Digital Personal Data Protection (DPDP) Act 2023.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _PolicySectionCard(
            number: '1',
            title: 'Phone Number & OTP Verification Data Usage',
            body:
                '• Purpose of Collection: When an authorized ASHA worker, Auxiliary Nurse Midwife (ANM), Sanitary Inspector, or Medical Officer signs in via Firebase Phone Authentication (+91 mobile number and 6-digit SMS OTP), the phone number is used strictly for identity verification and role-based access control (RBAC) against the official Staff Directory.\n'
                '• No Marketing or Third-Party Sharing: Phone numbers and authentication tokens are never sold, rented, or shared with third-party advertisers. SMS verification is processed exclusively via Google Firebase Authentication.',
          ),
          const SizedBox(height: 12),

          _PolicySectionCard(
            number: '2',
            title: 'DPDP Act 2023 & Indian Data Sovereignty (asia-south1)',
            body:
                '• Strict Regional Pinning: All application backends (Google Cloud Run), databases (Cloud Firestore Native), and object storage buckets (Google Cloud Storage) are physically hosted in Mumbai, India (asia-south1).\n'
                '• Automated PII Scrubbing: Breeding-site inspection photographs uploaded by field staff are processed in memory through Google Cloud Vision & PIL redaction to blur human faces and vehicle registration plates and strip EXIF device metadata prior to cloud storage.\n'
                '• Citizen Data Minimization: The platform prohibits collection of citizen Aadhaar numbers, PAN numbers, or patient names in entomological field logs.',
          ),
          const SizedBox(height: 12),

          _PolicySectionCard(
            number: '3',
            title: 'Location & Camera Permissions Disclosure',
            body:
                '• GPS Coordinates: Foreground location is used solely to tag ward Local Government Directory (LGD) codes, query Google Earth Engine (GEE) micro-climate indices, and compute Google Maps Routes API v2 fogging van dispatch paths.\n'
                '• Camera Access: Used only when a field officer initiates an AI breeding-site scan to detect stagnant water containers and larval habitats.',
          ),
          const SizedBox(height: 12),

          _PolicySectionCard(
            number: '4',
            title: 'Data Retention, Revocation & Grievance Redressal Officer',
            body:
                '• Account & Data Deletion: Authorized officers may request immediate revocation of their phone authentication profile or correction of directory records by contacting their District Nodal Officer or the Data Protection Officer below.\n'
                '• Data Protection & Grievance Officer: Shivam Yadav (Team Rocket — Chandigarh University) • Email: shivam@revlet.me • Project ID: teamrocketnp (asia-south1).',
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () => context.go('/auth'),
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Proceed to Officer Phone Verification (/auth)'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _PolicySectionCard({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArogyaTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ArogyaTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: ArogyaTheme.triageRedBg,
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ArogyaTheme.primaryCrimson,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
