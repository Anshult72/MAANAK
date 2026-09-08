import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

final supervisorDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get("${ApiConstants.dashboard}/supervisor");
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
  } catch (e) {
    // Fallback demo data
  }
  return {
    'team_metrics': {
      'total_inspections': 48,
      'passed': 38,
      'review_pending': 6,
      'confirmed_violations': 4,
      'repeat_offenders': 2
    },
    'escalations': [
      {
        'inspection_code': 'INS-2026-00103',
        'trader': 'Metro Cash & Carry Wholesale',
        'reason': 'Multi-pack unit sale price omitted across 12 SKUs (Rule 6(1)(k))',
        'severity': 'HIGH',
        'assigned_inspector': 'Inspector Sharma',
      },
      {
        'inspection_code': 'INS-2026-00089',
        'trader': 'Heritage Fresh Supermarket',
        'reason': 'Shrinkflation & Font reduction below 2.5mm Table-I threshold',
        'severity': 'CRITICAL',
        'assigned_inspector': 'Inspector Verma',
      }
    ],
    'repeat_offenders': [
      {'name': 'Apex Packaged Foods Ltd', 'infractions': 3, 'last_incident': '2026-02-14'},
      {'name': 'Sunrise Oils & Grains', 'infractions': 2, 'last_incident': '2026-01-28'},
    ]
  };
});

class SupervisorScreen extends ConsumerWidget {
  const SupervisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supAsync = ref.watch(supervisorDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Supervisor & Enforcement Oversight'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(supervisorDashboardProvider),
          ),
        ],
      ),
      body: supAsync.when(
        data: (data) {
          final metrics = data['team_metrics'] as Map<String, dynamic>? ?? {};
          final escalations = (data['escalations'] as List?) ?? [];
          final repeats = (data['repeat_offenders'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supervisor Info Banner
                _buildSupervisorBanner(),
                const SizedBox(height: 16),

                // Team Performance Grid
                _buildTeamMetricsGrid(metrics),
                const SizedBox(height: 20),

                // Priority Escalations
                const Text(
                  'Critical Escalations & Seizure Memos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pending legal notices and compounding recommendations requiring supervisory approval.',
                  style: TextStyle(fontSize: 11, color: AppColors.neutral600),
                ),
                const SizedBox(height: 10),

                ...escalations.map((esc) => _buildEscalationTile(context, esc)),
                const SizedBox(height: 20),

                // Repeat Offenders Registry
                const Text(
                  'Repeat Offenders Registry (High Scrutiny)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                _buildRepeatOffendersCard(repeats),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSupervisorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Legal Metrology Enforcement Command',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  'Jurisdiction: Northern Regional Zone (NCT of Delhi & Haryana)',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMetricsGrid(Map<String, dynamic> metrics) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: [
        _buildStatCard('Zone Total Audits', '${metrics['total_inspections'] ?? 48}', AppColors.primary),
        _buildStatCard('Compliant Filings', '${metrics['passed'] ?? 38}', AppColors.compliant),
        _buildStatCard('Supervisor Reviews', '${metrics['review_pending'] ?? 6}', AppColors.review),
        _buildStatCard('Enforcement Notices', '${metrics['confirmed_violations'] ?? 4}', AppColors.violation),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.neutral600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildEscalationTile(BuildContext context, dynamic esc) {
    final e = esc as Map<String, dynamic>;
    final isCritical = e['severity'] == 'CRITICAL';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isCritical ? AppColors.violation : AppColors.neutral300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e['inspection_code'] ?? 'INS-000',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCritical ? AppColors.violationBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e['severity'] ?? 'HIGH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCritical ? AppColors.violation : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              e['trader'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.neutral800),
            ),
            const SizedBox(height: 4),
            Text(
              e['reason'] ?? '',
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Investigator: ${e['assigned_inspector'] ?? 'Officer'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
                ),
                TextButton(
                  onPressed: () => context.push('/inspections'),
                  child: const Text('Review Docket', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatOffendersCard(List<dynamic> repeats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: repeats.map((r) {
          final item = r as Map<String, dynamic>;
          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.violationBg,
              child: Icon(Icons.flag_outlined, size: 14, color: AppColors.violation),
            ),
            title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text('Last Incident: ${item['last_incident']}', style: const TextStyle(fontSize: 10)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.violationBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item['infractions']} Violations',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.violation),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
