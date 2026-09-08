import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../inspections/inspections_controller.dart';

final dashboardSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get('/api/dashboard/summary');
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
  } catch (e) {
    // Return fallback summary if in offline demo
  }
  return {
    'total_inspections': 24,
    'compliance_rate': 87.5,
    'potential_violations': 3,
    'pending_reviews': 2,
    'active_rules_count': 18,
    'recent_changes_detected': 2,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final inspectionsState = ref.watch(inspectionsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MAANAK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Legal Metrology Inspection Platform',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              border: Border.all(color: AppColors.warning),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppColors.warning),
                SizedBox(width: 4),
                Text(
                  'SIH-2026 DEMO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          await ref.read(inspectionsProvider.notifier).fetchInspections();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Bar
              _buildGreetingHeader(authState.user),
              const SizedBox(height: 16),

              // KPI Metric Cards
              summaryAsync.when(
                data: (summary) => _buildKpiGrid(summary),
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                )),
                error: (_, _) => _buildKpiGrid({
                  'total_inspections': 24,
                  'compliance_rate': 87.5,
                  'potential_violations': 3,
                  'pending_reviews': 2,
                }),
              ),
              const SizedBox(height: 20),

              // Quick Action CTAs
              _buildActionCenter(context),
              const SizedBox(height: 20),

              // Intelligence / Product Alert
              _buildComplianceAlertBanner(context),
              const SizedBox(height: 20),

              // Recent Inspections Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Inspections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/inspections'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _buildRecentInspectionsList(context, inspectionsState),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_start_inspection',
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
        label: const Text('New Inspection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/new-inspection'),
      ),
    );
  }

  Widget _buildGreetingHeader(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.badge_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?.fullName ?? 'Officer'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user?.role ?? 'INSPECTOR',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user?.zone ?? 'New Delhi Central Zone',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> summary) {
    final total = summary['total_inspections'] ?? 0;
    final rate = (summary['compliance_rate'] as num?)?.toDouble() ?? 88.0;
    final violations = summary['potential_violations'] ?? 0;
    final pending = summary['pending_reviews'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildKpiCard(
          title: 'Total Audited',
          value: total.toString(),
          icon: Icons.assignment_turned_in_outlined,
          accentColor: AppColors.secondary,
          subtitle: 'Packaged Commodities',
        ),
        _buildKpiCard(
          title: 'Compliance Rate',
          value: '${rate.toStringAsFixed(1)}%',
          icon: Icons.verified_outlined,
          accentColor: AppColors.compliant,
          subtitle: 'Rule 6 & 7 Compliant',
        ),
        _buildKpiCard(
          title: 'Violations Flagged',
          value: violations.toString(),
          icon: Icons.gavel_outlined,
          accentColor: AppColors.violation,
          subtitle: 'Legal Action Notices',
        ),
        _buildKpiCard(
          title: 'Pending Review',
          value: pending.toString(),
          icon: Icons.pending_actions_outlined,
          accentColor: AppColors.review,
          subtitle: 'Human Verification',
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              CircleAvatar(
                radius: 14,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.neutral400,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCenter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational Workflows',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Physical\nPackage',
                  color: AppColors.secondary,
                  onTap: () => context.push('/scanner'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.language,
                  label: 'E-Commerce\nListing',
                  color: Colors.teal.shade700,
                  onTap: () => context.push('/online-listing'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.straighten,
                  label: 'Scale\nCalibration',
                  color: Colors.indigo.shade700,
                  onTap: () => context.push('/calibration'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.fingerprint,
                  label: 'Product\nHistory',
                  color: Colors.purple.shade700,
                  onTap: () => context.push('/products'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceAlertBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Product Change Alert: Heritage A2 Ghee',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Visual redesign detected with Net Quantity font reduced below Rule 7 minimum (1.5mm threshold).',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.neutral700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.neutral600),
            onPressed: () => context.push('/products'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInspectionsList(BuildContext context, InspectionState state) {
    if (state.isLoading && state.inspections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.inspections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 40, color: AppColors.neutral400),
            const SizedBox(height: 8),
            const Text(
              'No inspections on record yet',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Start a physical or e-commerce inspection to audit packaged goods.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/new-inspection'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Start First Inspection'),
            ),
          ],
        ),
      );
    }

    final displayList = state.inspections.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final ins = displayList[index];
        return _buildInspectionCard(context, ins);
      },
    );
  }

  Widget _buildInspectionCard(BuildContext context, InspectionModel ins) {
    Color statusColor;
    Color statusBg;
    String statusLabel;

    switch (ins.status.toUpperCase()) {
      case 'COMPLETED':
      case 'COMPLIANT':
        statusColor = AppColors.compliant;
        statusBg = AppColors.compliantBg;
        statusLabel = 'COMPLIANT';
        break;
      case 'POTENTIAL_VIOLATION':
      case 'VIOLATION':
        statusColor = AppColors.violation;
        statusBg = AppColors.violationBg;
        statusLabel = 'VIOLATION';
        break;
      case 'REVIEW_REQUIRED':
      case 'IN_REVIEW':
        statusColor = AppColors.review;
        statusBg = AppColors.reviewBg;
        statusLabel = 'HITL REVIEW';
        break;
      default:
        statusColor = AppColors.neutral600;
        statusBg = AppColors.neutral100;
        statusLabel = ins.status;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/inspections/${ins.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  ins.inspectionType == 'ONLINE_LISTING' ? Icons.language : Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ins.inspectionCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ins.businessName ?? ins.sellerName ?? 'Packaged Goods Retailer',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ins.location,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neutral400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (ins.score != null)
                    Text(
                      '${(ins.score! * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: ins.score! >= 0.8 ? AppColors.compliant : AppColors.violation,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.neutral400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
