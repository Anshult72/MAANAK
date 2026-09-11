import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/responsive/web_page_container.dart';
import '../../auth/auth_controller.dart';
import '../../inspections/inspections_controller.dart';
import '../../web/judge_demo_dialog.dart';
import '../dashboard_screen.dart';

/// Professional government enterprise desktop dashboard for LM-TRACE.
class DashboardWebLayout extends ConsumerStatefulWidget {
  const DashboardWebLayout({super.key});

  @override
  ConsumerState<DashboardWebLayout> createState() => _DashboardWebLayoutState();
}

class _DashboardWebLayoutState extends ConsumerState<DashboardWebLayout> {
  String _tableFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final inspectionsState = ref.watch(inspectionsProvider);

    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome & Primary Action Context Card
          _buildWelcomeHeader(context, user),
          const SizedBox(height: 20),

          // 2. 4 Stat Cards in a row
          summaryAsync.when(
            data: (summary) => _buildStatCards(summary),
            loading: () => _buildStatCardsSkeleton(),
            error: (err, stack) => _buildStatCardsFallback(inspectionsState.inspections),
          ),
          const SizedBox(height: 24),

          // 3. Middle Section: 65% Activity Overview / 35% Compliance Breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Overview & Trend Analysis (~65%)
              Expanded(
                flex: 65,
                child: _buildActivityOverviewCard(summaryAsync, inspectionsState),
              ),
              const SizedBox(width: 20),

              // Right: Compliance Breakdown by Rule Family (~35%)
              Expanded(
                flex: 35,
                child: _buildComplianceBreakdownCard(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Recent Inspections Desktop Table
          _buildRecentInspectionsTable(context, inspectionsState),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryNavy,
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome back, ${user?.fullName ?? "Ramesh Verma"}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user?.role ?? 'INSPECTOR',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${user?.department ?? "Legal Metrology Department"} • Zone: ${user?.zone ?? "New Delhi Central Zone"} • Operational Portal',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: const BorderSide(color: Color(0xFFF59E0B)),
              backgroundColor: const Color(0xFFFEF3C7),
            ),
            icon: const Icon(Icons.bolt, size: 16, color: Color(0xFFD97706)),
            label: const Text(
              'Judge Demo',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
            ),
            onPressed: () => JudgeDemoDialog.show(context),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text(
              '+ New Inspection',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () => context.push('/new-inspection'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(Map<String, dynamic> summary) {
    final audited = summary['total_audited'] ?? 54;
    final compRate = (summary['compliance_rate'] as num?)?.toDouble() ?? 72.4;
    final violations = summary['violations_flagged'] ?? summary['total_violations'] ?? 15;
    final pending = summary['pending_review'] ?? 8;

    return Row(
      children: [
        Expanded(
          child: _buildSingleStatCard(
            title: 'Total Audited',
            value: '$audited',
            subtitle: '+12 cases this week',
            icon: Icons.assignment_turned_in_outlined,
            iconColor: AppColors.secondaryBlue,
            trendPositive: true,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSingleStatCard(
            title: 'Compliance Rate',
            value: '${compRate.toStringAsFixed(1)}%',
            subtitle: 'Rule 6 & 7 verified',
            icon: Icons.verified_outlined,
            iconColor: AppColors.passGreen,
            trendPositive: compRate >= 70,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSingleStatCard(
            title: 'Violations Flagged',
            value: '$violations',
            subtitle: 'Non-compliant packages',
            icon: Icons.gavel_outlined,
            iconColor: AppColors.violationRed,
            trendPositive: false,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSingleStatCard(
            title: 'Pending Review',
            value: '$pending',
            subtitle: 'Awaiting inspector sign-off',
            icon: Icons.pending_actions_outlined,
            iconColor: AppColors.reviewAmber,
            trendPositive: null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCardsSkeleton() {
    return Row(
      children: List.generate(
        4,
        (index) => Expanded(
          child: Container(
            height: 130,
            margin: EdgeInsets.only(right: index < 3 ? 14 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardsFallback(List<InspectionModel> list) {
    final audited = list.isNotEmpty ? list.length : 54;
    final violations = list.where((i) => ['VIOLATION', 'POTENTIAL_VIOLATION'].contains(i.status.toUpperCase())).length;
    final compliant = list.where((i) => ['COMPLIANT', 'FINALIZED'].contains(i.status.toUpperCase())).length;
    final rate = list.isNotEmpty ? (compliant / list.length) * 100 : 72.4;

    return _buildStatCards({
      'total_audited': audited,
      'compliance_rate': rate,
      'violations_flagged': violations > 0 ? violations : 15,
      'pending_review': 8,
    });
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool? trendPositive,
  }) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
              height: 1.1,
            ),
          ),
          Row(
            children: [
              if (trendPositive != null)
                Icon(
                  trendPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13,
                  color: trendPositive ? AppColors.passGreen : AppColors.violationRed,
                ),
              if (trendPositive != null) const SizedBox(width: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityOverviewCard(
    AsyncValue<Map<String, dynamic>> summaryAsync,
    InspectionState inspectionsState,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                'Inspection Activity & Commodity Spread',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              Row(
                children: [
                  _buildLegendIndicator('Compliant', AppColors.passGreen),
                  const SizedBox(width: 12),
                  _buildLegendIndicator('Under Review', AppColors.reviewAmber),
                  const SizedBox(width: 12),
                  _buildLegendIndicator('Violation', AppColors.violationRed),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Commodity category spread bars
          _buildCategoryBar('Packaged Food (Basmati, Atta, Grains)', 24, 0.75),
          const SizedBox(height: 12),
          _buildCategoryBar('Edible Oils & Fats (Mustard, Ghee, Refined)', 14, 0.65),
          const SizedBox(height: 12),
          _buildCategoryBar('Cosmetics & Personal Care (Serums, Shampoo)', 9, 0.44),
          const SizedBox(height: 12),
          _buildCategoryBar('General Merchandise & Baby Foods', 7, 0.85),
          const SizedBox(height: 16),

          // Operational notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 16, color: AppColors.neutral600),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rule 7 Table-I font-height verification active on all calibrated physical inspections. Scale accuracy threshold: 2.0 px/mm.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.neutral700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String label, int total, double complianceRate) {
    final compPercent = (complianceRate * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral800)),
            Text('$total Audited • $compPercent% Compliant', style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(
                flex: compPercent,
                child: Container(height: 7, color: AppColors.passGreen),
              ),
              Expanded(
                flex: (100 - compPercent),
                child: Container(height: 7, color: AppColors.violationRed.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendIndicator(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
      ],
    );
  }

  Widget _buildComplianceBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statutory Rule Health',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rule enforcement compliance distribution',
            style: TextStyle(fontSize: 11, color: AppColors.neutral500),
          ),
          const SizedBox(height: 18),

          _buildRuleHealthRow('Rule 6 Mandatory Declarations', '84%', 0.84, AppColors.passGreen),
          const Divider(height: 20, color: AppColors.neutral200),
          _buildRuleHealthRow('Rule 7 Table-I PDP Font Height', '68%', 0.68, AppColors.reviewAmber),
          const Divider(height: 20, color: AppColors.neutral200),
          _buildRuleHealthRow('Rule 9 Readability & Contrast', '92%', 0.92, AppColors.passGreen),
          const Divider(height: 20, color: AppColors.neutral200),
          _buildRuleHealthRow('Rule 6(11) Unit Sale Price (USP)', '76%', 0.76, AppColors.passGreen),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 9),
                side: const BorderSide(color: AppColors.neutral300),
              ),
              onPressed: () => context.go('/rules'),
              child: const Text('View Rule Engine Registry →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleHealthRow(String title, String percent, double progress, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral800)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.neutral100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          percent,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildRecentInspectionsTable(BuildContext context, InspectionState state) {
    final inspections = state.inspections;

    final filtered = inspections.where((ins) {
      if (_tableFilter == 'COMPLIANT' && !['COMPLETED', 'COMPLIANT', 'FINALIZED'].contains(ins.status.toUpperCase())) {
        return false;
      }
      if (_tableFilter == 'VIOLATIONS' && !['POTENTIAL_VIOLATION', 'VIOLATION'].contains(ins.status.toUpperCase())) {
        return false;
      }
      if (_tableFilter == 'REVIEW' && !['REVIEW_REQUIRED', 'IN_REVIEW', 'NEEDS_REVIEW', 'DRAFT'].contains(ins.status.toUpperCase())) {
        return false;
      }
      return true;
    }).take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Text(
                  'Recent Inspection Cases',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${inspections.length} total)',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                ),
                const Spacer(),
                // Filter chips
                _buildTableFilterChip('ALL', 'All Cases'),
                const SizedBox(width: 6),
                _buildTableFilterChip('COMPLIANT', 'Compliant'),
                const SizedBox(width: 6),
                _buildTableFilterChip('REVIEW', 'Needs Review'),
                const SizedBox(width: 6),
                _buildTableFilterChip('VIOLATIONS', 'Violations'),
                const SizedBox(width: 14),
                TextButton(
                  onPressed: () => context.go('/inspections'),
                  child: const Text('View All Registry →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Data Table Header
          Container(
            color: AppColors.neutral100,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('CASE ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600))),
                Expanded(flex: 3, child: Text('ESTABLISHMENT / TRADER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600))),
                Expanded(flex: 3, child: Text('LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600))),
                Expanded(flex: 2, child: Text('INSPECTION TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600))),
                Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral600)))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Data Rows
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'No inspection cases match selected filter "$_tableFilter".',
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.neutral200),
              itemBuilder: (context, index) {
                final ins = filtered[index];
                return _buildTableRow(context, ins);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTableFilterChip(String key, String label) {
    final isSelected = _tableFilter == key;
    return InkWell(
      onTap: () => setState(() => _tableFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.secondaryBlue : AppColors.neutral300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.neutral700,
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, InspectionModel ins) {
    final status = ins.status.toUpperCase();
    Color statusBg = AppColors.neutral200;
    Color statusText = AppColors.neutral700;

    if (['COMPLIANT', 'FINALIZED', 'COMPLETED'].contains(status)) {
      statusBg = AppColors.passGreen.withValues(alpha: 0.12);
      statusText = AppColors.passGreen;
    } else if (['VIOLATION', 'POTENTIAL_VIOLATION'].contains(status)) {
      statusBg = AppColors.violationRed.withValues(alpha: 0.12);
      statusText = AppColors.violationRed;
    } else if (['NEEDS_REVIEW', 'REVIEW_REQUIRED', 'IN_REVIEW', 'DRAFT'].contains(status)) {
      statusBg = AppColors.reviewAmber.withValues(alpha: 0.12);
      statusText = AppColors.reviewAmber;
    }

    final dateStr = ins.inspectionDate.length >= 10 ? ins.inspectionDate.substring(0, 10) : ins.inspectionDate;

    return InkWell(
      onTap: () => context.push('/inspections/${ins.id}'),
      hoverColor: AppColors.neutral50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                ins.inspectionCode,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.primaryNavy),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                ins.businessName ?? ins.sellerName ?? 'Retail Enterprise',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                ins.location,
                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                ins.inspectionType,
                style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusText),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 13),
                  label: const Text('View Case', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => context.push('/inspections/${ins.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
