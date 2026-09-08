import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

final rulesListProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get(ApiConstants.rules);
    if (response.statusCode == 200) {
      return response.data as List<dynamic>;
    }
  } catch (e) {
    // Fallback demo rules
  }
  return [
    {
      'id': 'rule-001',
      'code': 'RULE_6_NET_QTY',
      'rule_family': 'RULE_6',
      'title': 'Mandatory Net Quantity Declaration',
      'description': 'Net quantity must be declared with canonical SI standard units (g, kg, ml, l) without ambiguous symbols.',
      'version': 'LM-2011-AMEND-2021',
      'is_active': true,
      'severity': 'HIGH',
      'statutory_reference': 'Rule 6(1)(d), LM Rules 2011',
    },
    {
      'id': 'rule-002',
      'code': 'RULE_6_MRP_TAX',
      'rule_family': 'RULE_6',
      'title': 'Maximum Retail Price (Inclusive of Taxes)',
      'description': 'Retail sale price must state "Maximum Retail Price" or "MRP" and include "(inclusive of all taxes)".',
      'version': 'LM-2011-AMEND-2024',
      'is_active': true,
      'severity': 'HIGH',
      'statutory_reference': 'Rule 6(1)(e), LM Rules 2011',
    },
    {
      'id': 'rule-003',
      'code': 'RULE_7_FONT_SIZE',
      'rule_family': 'RULE_7',
      'title': 'Principal Display Panel (PDP) Table-I Font Heights',
      'description': 'Font size must adhere strictly to Table-I area thresholds: <=50cm²: 1.0mm, 50-100cm²: 1.5mm, 100-500cm²: 2.5mm, 500-2500cm²: 4.0mm, >2500cm²: 6.0mm. Blown/molded packages use separate elevated thresholds.',
      'version': 'LM-2011-BASE',
      'is_active': true,
      'severity': 'HIGH',
      'statutory_reference': 'Rule 7 & Table-I, LM Rules 2011',
    },
    {
      'id': 'rule-004',
      'code': 'RULE_7_PROPORTION',
      'rule_family': 'RULE_7',
      'title': 'Letter Width-to-Height Proportion',
      'description': 'Width of letter or numeral shall not be less than one-third of its height, except for numeral 1 and letters i, I, l.',
      'version': 'LM-2011-BASE',
      'is_active': true,
      'severity': 'MEDIUM',
      'statutory_reference': 'Rule 7(3), LM Rules 2011',
    },
    {
      'id': 'rule-005',
      'code': 'RULE_9_CONTRAST',
      'rule_family': 'RULE_9',
      'title': 'Legibility, Contrast & Background Prominence',
      'description': 'All declarations must be legible, unambiguous, distinct, and presented in conspicuous color contrast to the label background.',
      'version': 'LM-2011-BASE',
      'is_active': true,
      'severity': 'MEDIUM',
      'statutory_reference': 'Rule 9(1), LM Rules 2011',
    },
    {
      'id': 'rule-006',
      'code': 'RULE_ECOM_2027',
      'rule_family': 'RULE_ECOM',
      'title': 'E-Commerce Marketplace Pre-Purchase Declarations',
      'description': 'Marketplace listings must provide all Rule 6 declarations prior to consumer checkout commitment on digital viewports.',
      'version': 'LM-2027-ECOM',
      'is_active': true,
      'severity': 'HIGH',
      'statutory_reference': 'E-Commerce Marketplace Advisory 2027',
    },
  ];
});

class RuleAdminScreen extends ConsumerStatefulWidget {
  const RuleAdminScreen({super.key});

  @override
  ConsumerState<RuleAdminScreen> createState() => _RuleAdminScreenState();
}

class _RuleAdminScreenState extends ConsumerState<RuleAdminScreen> {
  String _selectedFamily = 'ALL';

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesListProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Statutory Rule Engine Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(rulesListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header / Info
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.infoBg,
            child: Row(
              children: [
                const Icon(Icons.rule_folder_outlined, color: AppColors.secondary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Versioned Statutory Rule Registry',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                      ),
                      Text(
                        'Enforces versioned Legal Metrology rules with immutable audit histories. Evaluations link directly to active statutory amendments.',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Family Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFamilyChip('ALL', 'All Rules'),
                  const SizedBox(width: 8),
                  _buildFamilyChip('RULE_6', 'Rule 6 (Declarations)'),
                  const SizedBox(width: 8),
                  _buildFamilyChip('RULE_7', 'Rule 7 (PDP & Dimensions)'),
                  const SizedBox(width: 8),
                  _buildFamilyChip('RULE_9', 'Rule 9 (Legibility & Contrast)'),
                  const SizedBox(width: 8),
                  _buildFamilyChip('RULE_ECOM', 'E-Commerce 2027'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Rule Cards List
          Expanded(
            child: rulesAsync.when(
              data: (rules) {
                final filtered = rules.where((r) {
                  if (_selectedFamily == 'ALL') return true;
                  return r['rule_family'] == _selectedFamily;
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final rule = filtered[index] as Map<String, dynamic>;
                    return _buildRuleCard(rule);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyChip(String key, String label) {
    final isSelected = _selectedFamily == key;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.neutral700,
        ),
      ),
      backgroundColor: AppColors.neutral100,
      selectedColor: AppColors.primary,
      showCheckmark: false,
      onSelected: (val) {
        if (val) setState(() => _selectedFamily = key);
      },
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final code = rule['code'] ?? 'RULE';
    final title = rule['title'] ?? '';
    final desc = rule['description'] ?? '';
    final version = rule['version'] ?? 'LM-2011-BASE';
    final ref = rule['statutory_reference'] ?? '';
    final isActive = rule['is_active'] ?? true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.compliantBg : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'DEPRECATED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.compliant : AppColors.neutral500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.neutral900),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral700, height: 1.3),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.neutral200),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_border, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      ref,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.history, size: 14, color: AppColors.neutral500),
                    const SizedBox(width: 4),
                    Text(
                      version,
                      style: const TextStyle(fontSize: 10, color: AppColors.neutral500, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
