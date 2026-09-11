import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Modal dialog providing the primary SIH 2026 evaluator workflow.
/// Allows judges and evaluators to test and review 3 statutory Legal Metrology scenarios
/// with zero friction and instant access to AI analysis, font size validation, and evidence.
class JudgeDemoDialog extends StatelessWidget {
  const JudgeDemoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const JudgeDemoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge & title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD97706)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text(
                            'SIH 2026 EVALUATOR MODE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.neutral500),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text(
                  'LM-TRACE Statutory Verification Scenarios',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a pre-configured legal scenario below to inspect OCR extraction, Rule 7 Table-I font measurements, and automated violation evidence.',
                  style: TextStyle(fontSize: 13, color: AppColors.neutral600),
                ),
                const SizedBox(height: 24),

                // 3 Standard Scenarios
                _buildScenarioCard(
                  context,
                  badge: 'SCENARIO 1',
                  badgeColor: AppColors.passGreen,
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.passGreen,
                  title: 'Fully Compliant Package',
                  commodity: 'ABC Premium Basmati Rice (5 kg)',
                  description:
                      'All Rule 6 mandatory declarations detected. Rule 7 numeral height (3.2 mm) exceeds Table-I minimum (2.5 mm). Adequate contrast (88%). Inspection score: 96.5%.',
                  ruleTags: ['Rule 6 (Declarations)', 'Rule 7 (Table-I Heights)', 'Rule 9 (Contrast)'],
                  statusText: 'COMPLIANT • 96.5%',
                  statusColor: AppColors.passGreen,
                  inspectionId: 'ins-demo-001',
                ),
                const SizedBox(height: 14),

                _buildScenarioCard(
                  context,
                  badge: 'SCENARIO 2',
                  badgeColor: AppColors.reviewAmber,
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.reviewAmber,
                  title: 'Missing Statutory Declaration',
                  commodity: 'XYZ Herbal Shampoo (200 ml)',
                  description:
                      'Rule 6(1)(h) Non-Compliance: Consumer care telephone number absent from label (email only). Inspection score: 82.0%. Flagged for supervisor review.',
                  ruleTags: ['Rule 6(1)(h) Consumer Care', 'Rule 11 Unit Symbols'],
                  statusText: 'NEEDS REVIEW • 82.0%',
                  statusColor: AppColors.reviewAmber,
                  inspectionId: 'ins-demo-002',
                ),
                const SizedBox(height: 14),

                _buildScenarioCard(
                  context,
                  badge: 'SCENARIO 3',
                  badgeColor: AppColors.violationRed,
                  icon: Icons.error_outline,
                  iconColor: AppColors.violationRed,
                  title: 'Font Size & Importer Address Defect',
                  commodity: 'Luxe Parisian Glow Serum (50 ml)',
                  description:
                      'Rule 6(1)(b) & Rule 7 Table-I Non-Compliance: Missing complete Indian registered importer address. Net quantity numeral height (1.42 mm) fails required 2.0 mm threshold.',
                  ruleTags: ['Rule 7 Table-I Under-Height', 'Rule 6(1)(b) Importer Address'],
                  statusText: 'VIOLATION • 64.0%',
                  statusColor: AppColors.violationRed,
                  inspectionId: 'ins-demo-003',
                ),
                const SizedBox(height: 24),

                // Live workspace scanner option
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: AppColors.secondaryBlue, size: 28),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test With Live Scanner / Custom Package',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Capture your own package surfaces or load synthetic demo packs to test the full OCR + Legal Metrology pipeline from scratch.',
                              style: TextStyle(fontSize: 12, color: AppColors.neutral700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                        label: const Text('Open Scanner', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/scanner');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard(
    BuildContext context, {
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String commodity,
    required String description,
    required List<String> ruleTags,
    required String statusText,
    required Color statusColor,
    required String inspectionId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.neutral900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Target Product: $commodity',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral600, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ruleTags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.neutral300),
                            ),
                            child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.neutral700)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: const BorderSide(color: AppColors.primaryNavy),
                ),
                icon: const Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryNavy),
                label: const Text(
                  'Launch Scenario Audit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/inspections/$inspectionId');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
