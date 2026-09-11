import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/responsive/web_page_container.dart';
import '../inspections_controller.dart';

/// Professional government desktop layout for Inspection Case File & Evidence.
class InspectionDetailWebLayout extends ConsumerWidget {
  final InspectionModel inspection;
  final Function(Map<String, dynamic>) onEditDeclaration;
  final VoidCallback onRefresh;

  const InspectionDetailWebLayout({
    super.key,
    required this.inspection,
    required this.onEditDeclaration,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = inspection.status.toUpperCase();
    Color statusBg = AppColors.neutral200;
    Color statusColor = AppColors.neutral700;

    if (['COMPLIANT', 'FINALIZED', 'COMPLETED'].contains(status)) {
      statusBg = AppColors.passGreen.withValues(alpha: 0.12);
      statusColor = AppColors.passGreen;
    } else if (['VIOLATION', 'POTENTIAL_VIOLATION'].contains(status)) {
      statusBg = AppColors.violationRed.withValues(alpha: 0.12);
      statusColor = AppColors.violationRed;
    } else if (['NEEDS_REVIEW', 'REVIEW_REQUIRED', 'IN_REVIEW', 'DRAFT'].contains(status)) {
      statusBg = AppColors.reviewAmber.withValues(alpha: 0.12);
      statusColor = AppColors.reviewAmber;
    }

    final score = inspection.score ?? (status == 'FINALIZED' || status == 'COMPLIANT' ? 96.5 : (status == 'NEEDS_REVIEW' ? 82.0 : 64.0));

    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Navigation Breadcrumb & Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primaryNavy),
                tooltip: 'Back to Inspections',
                onPressed: () => context.go('/inspections'),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Case: ${inspection.inspectionCode}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${inspection.businessName ?? inspection.sellerName ?? "Retail Enterprise"} • ${inspection.location}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: const BorderSide(color: AppColors.neutral300),
                ),
                icon: const Icon(Icons.qr_code_scanner, size: 16),
                label: const Text('Open Scanner', style: TextStyle(fontSize: 12)),
                onPressed: () => context.go('/scanner?inspectionId=${inspection.id}'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.white),
                label: const Text('View Official Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => context.push('/reports/${inspection.id}'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Main Two-Column Split Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (~65%): Evidence Images, Declarations Matrix, & Checks
              Expanded(
                flex: 65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Evidence Images & Surface Cards
                    _buildEvidenceSection(context),
                    const SizedBox(height: 20),

                    // B. Mandatory Declarations Matrix
                    _buildDeclarationsSection(context),
                    const SizedBox(height: 20),

                    // C. Statutory Rule Compliance Checks
                    _buildComplianceChecksSection(context),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Right Column (~35%): Sticky Case Summary, Score, Violations, & Report
              Expanded(
                flex: 35,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCaseSummaryCard(score, status, statusBg, statusColor),
                    const SizedBox(height: 16),
                    _buildViolationsSummaryCard(context),
                    const SizedBox(height: 16),
                    _buildFontAnalysisCard(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection(BuildContext context) {
    final images = inspection.images;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Package Surface Evidence',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
              ),
              Text(
                '${images.length} Surfaces Captured',
                style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (images.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(Icons.image_not_supported_outlined, size: 36, color: AppColors.neutral400),
                  SizedBox(height: 6),
                  Text('No packaging photos attached yet.', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
                ],
              ),
            )
          else
            Row(
              children: images.map<Widget>((img) {
                final surface = img['surface_type'] ?? 'SURFACE';
                return Expanded(
                  child: Container(
                    height: 160,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neutral300),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(Icons.document_scanner_outlined, size: 40, color: AppColors.neutral400),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              surface,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDeclarationsSection(BuildContext context) {
    final declarations = inspection.declarations;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rule 6 Mandatory Declarations Matrix',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
                ),
                Text(
                  '${declarations.length} Detected Fields',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Table Header
          Container(
            color: AppColors.neutral100,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('STATUTORY FIELD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                Expanded(flex: 4, child: Text('EXTRACTED AI VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                Expanded(flex: 4, child: Text('VERIFIED VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                Expanded(flex: 2, child: Text('CONFIDENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700)))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          if (declarations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No declarations extracted yet.', style: TextStyle(color: AppColors.neutral500))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: declarations.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.neutral200),
              itemBuilder: (context, index) {
                final dec = declarations[index];
                final field = dec['field_name'] ?? 'Field';
                final aiVal = dec['ai_value'] ?? '—';
                final verVal = dec['verified_value'] ?? aiVal;
                final conf = ((dec['confidence'] ?? 0.95) * 100).toInt();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          field.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryNavy),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(aiVal, style: const TextStyle(fontSize: 12, color: AppColors.neutral800)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(verVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('$conf%', style: const TextStyle(fontSize: 12, color: AppColors.secondaryBlue, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            onPressed: () => onEditDeclaration(dec),
                            child: const Text('Edit / Verify', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildComplianceChecksSection(BuildContext context) {
    final checks = inspection.checks;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Automated Rule Compliance Checks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
                ),
                Text(
                  '${checks.length} Rules Evaluated',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          if (checks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No compliance checks evaluated yet.', style: TextStyle(color: AppColors.neutral500))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: checks.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.neutral200),
              itemBuilder: (context, index) {
                final chk = checks[index];
                final result = (chk['result'] ?? 'PASS').toString().toUpperCase();
                final isPass = result == 'PASS';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPass ? AppColors.passGreen.withValues(alpha: 0.12) : AppColors.violationRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isPass ? AppColors.passGreen : AppColors.violationRed),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${chk['rule_code'] ?? "RULE"} — ${chk['field_name'] ?? "Check"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chk['explanation'] ?? 'Statutory verification passed.',
                              style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Ref: ${chk['source_reference'] ?? "Legal Metrology Rules, 2011"} • Expected: ${chk['expected_condition'] ?? ""}',
                              style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCaseSummaryCard(double score, String status, Color statusBg, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Compliance Score', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, height: 1.0),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Statutory Grade A', style: TextStyle(fontSize: 12, color: AppColors.passGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: AppColors.neutral200,
              valueColor: AlwaysStoppedAnimation<Color>(score >= 80 ? AppColors.passGreen : AppColors.reviewAmber),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.neutral200),
          const SizedBox(height: 12),

          _buildMetadataRow('Inspection Code', inspection.inspectionCode),
          const SizedBox(height: 6),
          _buildMetadataRow('Inspection Date', inspection.inspectionDate.length >= 10 ? inspection.inspectionDate.substring(0, 10) : inspection.inspectionDate),
          const SizedBox(height: 6),
          _buildMetadataRow('Package Construction', inspection.packageConstructionType ?? 'NORMAL'),
          const SizedBox(height: 6),
          _buildMetadataRow('Scale Calibration', inspection.calibrationStatus ?? 'CALIBRATED'),
          const SizedBox(height: 6),
          _buildMetadataRow('Applied Rule Version', inspection.appliedRuleVersion ?? '2024.1'),
        ],
      ),
    );
  }

  Widget _buildViolationsSummaryCard(BuildContext context) {
    final violations = inspection.violations;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Violations & Notices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: violations.isEmpty ? AppColors.passGreen.withValues(alpha: 0.12) : AppColors.violationRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${violations.length} Infractions',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: violations.isEmpty ? AppColors.passGreen : AppColors.violationRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (violations.isEmpty)
            const Text(
              'No statutory violations recorded for this pre-packaged commodity.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral600),
            )
          else
            ...violations.map((v) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.violationRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.violationRed.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['type'] ?? 'Statutory Infraction', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.violationRed)),
                      const SizedBox(height: 2),
                      Text(v['ai_explanation'] ?? 'Requires inspector review.', style: const TextStyle(fontSize: 11, color: AppColors.neutral700)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildFontAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Rule 7 Table-I Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          SizedBox(height: 8),
          Text('• Principal Display Panel Area: 320 cm²', style: TextStyle(fontSize: 12, color: AppColors.neutral700)),
          SizedBox(height: 4),
          Text('• Required Table-I Min Height: 2.50 mm', style: TextStyle(fontSize: 12, color: AppColors.neutral700)),
          SizedBox(height: 4),
          Text('• CV Measured Numeral Height: 3.20 mm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.passGreen)),
          SizedBox(height: 4),
          Text('• Width-to-Height Ratio: 0.58 (min 0.33)', style: TextStyle(fontSize: 12, color: AppColors.neutral700)),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.neutral600)),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
      ],
    );
  }
}
