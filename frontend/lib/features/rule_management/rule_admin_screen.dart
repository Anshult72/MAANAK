import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

final rulesListProvider = FutureProvider.family<List<dynamic>, String>((ref, category) async {
  final client = ref.watch(apiClientProvider);
  try {
    final query = category == 'ALL' ? '' : '?category=${Uri.encodeComponent(category)}';
    final response = await client.get('${ApiConstants.rules}$query');
    if (response.statusCode == 200 && response.data is List) {
      return response.data as List<dynamic>;
    }
  } catch (e) {
    // Fallback to statutory baseline offline cache
  }

  final statutoryFallback = [
    {
      'id': 'rule-006-decl',
      'code': 'RULE-006-DECL',
      'category': 'DECLARATIONS',
      'title': 'Mandatory Declarations on Pre-Packaged Commodities',
      'description': 'Every pre-packaged commodity must declare commodity identity, net quantity, retail sale price (MRP), manufacturer/packer identity and address, month and year of manufacture, and consumer care details.',
      'statutory_reference': 'Rule 6(1), Legal Metrology (Packaged Commodities) Rules, 2011',
      'version': '2024.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'FULLY_IMPLEMENTED',
      'effective_from': '2011-03-07T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-PCR-2011',
      'parameters': {
        'mandatory_fields': [
          'commodity_name', 'net_quantity', 'mrp',
          'manufacturer_name', 'manufacturer_address',
          'manufacturing_date', 'consumer_care'
        ]
      },
      'evidence_requirements': ['label_front', 'label_back', 'ocr_text_blocks']
    },
    {
      'id': 'rule-007-pdp',
      'code': 'RULE-007-PDP',
      'category': 'PDP_FONT_SIZE',
      'title': 'Principal Display Panel Character & Numeral Height (Table-I)',
      'description': 'Minimum height of any numeral and letter on the principal display panel (PDP) governed by packaging area thresholds. Width must not be less than one-third of height.',
      'statutory_reference': 'Rule 7 & Table-I, Legal Metrology (Packaged Commodities) Rules, 2011',
      'version': '2024.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'FULLY_IMPLEMENTED',
      'effective_from': '2011-03-07T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-PCR-2011',
      'parameters': {
        'table_1_normal': [
          {'max_area_cm2': 50, 'min_numeral_mm': 1.0, 'min_letter_mm': 1.0},
          {'max_area_cm2': 100, 'min_numeral_mm': 1.5, 'min_letter_mm': 1.0},
          {'max_area_cm2': 500, 'min_numeral_mm': 2.5, 'min_letter_mm': 1.5},
          {'max_area_cm2': 2500, 'min_numeral_mm': 4.0, 'min_letter_mm': 2.5},
          {'max_area_cm2': null, 'min_numeral_mm': 6.0, 'min_letter_mm': 4.0}
        ]
      },
      'evidence_requirements': ['pdp_bounding_box', 'pdp_area_cm2', 'char_pixel_measurements', 'scale_calibration']
    },
    {
      'id': 'rule-009-leg',
      'code': 'RULE-009-LEG',
      'category': 'OTHER',
      'title': 'Manner in Which Declarations Shall Be Made (Legibility & Contrast)',
      'description': 'Declarations must be conspicuous, legible, prominent, and distinct from label background. Non-transparent background required for clear readability.',
      'statutory_reference': 'Rule 9(1), Legal Metrology (Packaged Commodities) Rules, 2011',
      'version': '2024.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'FULLY_IMPLEMENTED',
      'effective_from': '2011-03-07T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-PCR-2011',
      'parameters': {'min_contrast': 0.40, 'min_sharpness': 0.35},
      'evidence_requirements': ['cropped_declaration_surface', 'contrast_ratio', 'edge_sharpness_score']
    },
    {
      'id': 'rule-006-usp',
      'code': 'RULE-006-USP',
      'category': 'MRP',
      'title': 'Unit Sale Price Declaration',
      'description': 'Unit sale price must be declared on package as Rs. per g/kg/ml/l/metre or item whenever package contains more than 1 unit.',
      'statutory_reference': 'Rule 6(11), LM (Packaged Commodities) Rules, 2011 (Amended 2021)',
      'version': '2021.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'FULLY_IMPLEMENTED',
      'effective_from': '2022-12-01T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-AMEND-2021',
      'parameters': {'required_format': 'Rs. X per g/ml/number'},
      'evidence_requirements': ['mrp_block', 'unit_sale_price_ocr']
    },
    {
      'id': 'rule-018-mrp',
      'code': 'RULE-018-MRP',
      'category': 'MRP',
      'title': 'Prohibition of Dual MRP and Higher Retail Price',
      'description': 'No person shall declare a different MRP on an identical pre-packaged commodity. Sale above printed MRP is strictly prohibited.',
      'statutory_reference': 'Rule 18(1) & (2), Legal Metrology (Packaged Commodities) Rules, 2011',
      'version': '2017.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'FULLY_IMPLEMENTED',
      'effective_from': '2018-01-01T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-AMEND-2017',
      'parameters': {'prohibit_dual_mrp': true, 'prohibit_sale_above_mrp': true},
      'evidence_requirements': ['printed_mrp_detection', 'dual_pricing_scan']
    },
    {
      'id': 'rule-006-ecom',
      'code': 'RULE-006-ECOM',
      'category': 'E_COMMERCE',
      'title': 'Mandatory Declarations on E-Commerce Marketplaces',
      'description': 'E-commerce entities displaying pre-packaged commodities for retail purchase must display mandatory Rule 6 declarations on digital marketplace listings.',
      'statutory_reference': 'Rule 6(10), Legal Metrology (Packaged Commodities) Rules, 2011',
      'version': '2017.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'FULLY_IMPLEMENTED',
      'effective_from': '2018-01-01T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-AMEND-2017',
      'parameters': {'mandatory_digital_declarations': ['commodity_name', 'mrp', 'net_quantity', 'manufacturer_name', 'consumer_care']},
      'evidence_requirements': ['marketplace_pdp_html', 'screenshot_viewport']
    },
    {
      'id': 'rule-ecom-future-2027',
      'code': 'RULE-ECOM-FUTURE-2027',
      'category': 'E_COMMERCE',
      'title': 'Future E-Commerce Digital Transparency Standard (Scheduled 2027)',
      'description': 'Scheduled advisory requiring high-resolution full 360-degree interactive label viewports on all e-commerce platforms before sale commitment.',
      'statutory_reference': 'Proposed Advisory 2027, DCA Legal Metrology Division',
      'version': '2027.0-DRAFT',
      'version_status': 'SCHEDULED',
      'coverage_status': 'PARTIALLY_IMPLEMENTED',
      'effective_from': '2027-07-01T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-ADVISORY-2027',
      'parameters': {'scheduled_effective_date': '2027-07-01'},
      'evidence_requirements': ['360_view_verification']
    },
    {
      'id': 'rule-006-dec',
      'code': 'RULE-006-DEC',
      'category': 'OTHER',
      'title': 'Prohibition of Deceptive Packaging & Excessive Non-Functional Headspace',
      'description': 'Packaging shall not be designed with deceptive cavities, false bottoms, or non-functional excess headspace that misleads consumers.',
      'statutory_reference': 'Rule 23(1) & Legal Metrology Act Section 36',
      'version': '2011.1',
      'version_status': 'ACTIVE',
      'coverage_status': 'NOT_COVERED',
      'effective_from': '2011-03-07T00:00:00Z',
      'is_active': true,
      'source_document_id': 'DOC-PCR-2011',
      'parameters': {'max_headspace_pct': 20.0},
      'evidence_requirements': ['xray_tomography', 'displacement_volume_test']
    }
  ];

  if (category == 'ALL') return statutoryFallback;
  return statutoryFallback.where((r) {
    final cat = (r['category'] ?? '').toString().toUpperCase();
    if (category == 'DECLARATIONS') return cat == 'DECLARATIONS';
    if (category == 'PDP / FONT SIZE') return cat == 'PDP_FONT_SIZE';
    if (category == 'MRP') return cat == 'MRP';
    if (category == 'E-COMMERCE') return cat == 'E_COMMERCE';
    if (category == 'OTHER') return cat == 'OTHER';
    return true;
  }).toList();
});

class RuleAdminScreen extends ConsumerStatefulWidget {
  const RuleAdminScreen({super.key});

  @override
  ConsumerState<RuleAdminScreen> createState() => _RuleAdminScreenState();
}

class _RuleAdminScreenState extends ConsumerState<RuleAdminScreen> {
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'DECLARATIONS',
    'PDP / FONT SIZE',
    'MRP',
    'E-COMMERCE',
    'OTHER',
  ];

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesListProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Statutory Rule Engine Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Rules',
            onPressed: () => ref.refresh(rulesListProvider(_selectedCategory)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header / Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.infoBg,
            child: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: AppColors.secondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Authoritative Statutory Rule Registry',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Versioned Legal Metrology Act 2009 & Packaged Commodities Rules 2011. Inspections resolve active versions by inspection date.',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral700, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(cat),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Rule Cards List
          Expanded(
            child: rulesAsync.when(
              data: (rules) {
                if (rules.isEmpty) {
                  return const Center(
                    child: Text(
                      'No statutory rules found in this category.',
                      style: TextStyle(color: AppColors.neutral600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rule = rules[index] as Map<String, dynamic>;
                    return _buildRuleCard(rule);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading statutory rules: $e',
                    style: const TextStyle(color: AppColors.violationRed),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String cat) {
    final isSelected = _selectedCategory == cat;
    return FilterChip(
      selected: isSelected,
      label: Text(
        cat,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.neutral700,
        ),
      ),
      backgroundColor: AppColors.neutral100,
      selectedColor: AppColors.primaryNavy,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = cat);
      },
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final code = rule['code'] ?? rule['rule_code'] ?? 'RULE';
    final title = rule['title'] ?? '';
    final desc = rule['description'] ?? '';
    final version = rule['version'] ?? '2024.1';
    final ref = rule['statutory_reference'] ?? rule['statutory_source'] ?? 'LM Rules 2011';
    final category = rule['category'] ?? 'OTHER';
    final status = (rule['version_status'] ?? (rule['is_active'] == true ? 'ACTIVE' : 'SUPERSEDED')).toString().toUpperCase();
    final coverage = (rule['coverage_status'] ?? 'FULLY_IMPLEMENTED').toString().toUpperCase();
    final effectiveFrom = (rule['effective_from'] ?? '').toString().split('T').first;

    return InkWell(
      onTap: () => _showRuleDetailModal(context, rule),
      borderRadius: BorderRadius.circular(10),
      child: Card(
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
              // Top Row: Code + Category + Status Chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 4),

              // Description
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.neutral700, height: 1.3),
              ),
              const SizedBox(height: 10),

              // Coverage Status Badge
              Row(
                children: [
                  _buildCoverageBadge(coverage),
                  const Spacer(),
                  if (effectiveFrom.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.event_available_outlined, size: 13, color: AppColors.neutral500),
                        const SizedBox(width: 4),
                        Text(
                          'Eff: $effectiveFrom',
                          style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.neutral200),
              const SizedBox(height: 8),

              // Footer: Statutory Reference + Version
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_border_rounded, size: 14, color: AppColors.secondaryBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ref,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: AppColors.neutral500),
                      const SizedBox(width: 4),
                      Text(
                        'v$version',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.neutral600,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'ACTIVE':
      case 'APPROVED':
        bg = AppColors.compliantBg;
        fg = AppColors.compliant;
        break;
      case 'SCHEDULED':
        bg = AppColors.aiPurpleLight;
        fg = AppColors.aiPurple;
        break;
      case 'PENDING_REVIEW':
        bg = AppColors.reviewBg;
        fg = AppColors.review;
        break;
      default:
        bg = AppColors.neutral100;
        fg = AppColors.neutral500;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildCoverageBadge(String coverage) {
    IconData icon;
    Color color;
    Color bg;
    String label;

    switch (coverage) {
      case 'FULLY_IMPLEMENTED':
        icon = Icons.check_circle_rounded;
        color = AppColors.passGreen;
        bg = AppColors.passGreenLight;
        label = 'Fully Automated';
        break;
      case 'PARTIALLY_IMPLEMENTED':
        icon = Icons.timelapse_rounded;
        color = AppColors.reviewAmber;
        bg = AppColors.reviewAmberLight;
        label = 'Partially Automated';
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = AppColors.neutral600;
        bg = AppColors.neutral100;
        label = 'Physical Test (Not Covered)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _showRuleDetailModal(BuildContext context, Map<String, dynamic> rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RuleDetailBottomSheet(rule: rule),
    );
  }
}

class _RuleDetailBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> rule;
  const _RuleDetailBottomSheet({required this.rule});

  @override
  ConsumerState<_RuleDetailBottomSheet> createState() => _RuleDetailBottomSheetState();
}

class _RuleDetailBottomSheetState extends ConsumerState<_RuleDetailBottomSheet> {
  List<dynamic>? _versions;
  List<dynamic>? _amendments;
  bool _isLoadingVersions = true;
  bool _isApproving = false;

  @override
  void initState() {
    super.initState();
    _loadRuleMetadata();
  }

  Future<void> _loadRuleMetadata() async {
    final client = ref.read(apiClientProvider);
    final ruleId = widget.rule['id'];
    if (ruleId == null) {
      setState(() => _isLoadingVersions = false);
      return;
    }

    try {
      final vRes = await client.get('${ApiConstants.rules}/$ruleId/versions');
      if (vRes.statusCode == 200 && vRes.data is List) {
        _versions = vRes.data as List<dynamic>;
      }
    } catch (_) {}

    try {
      final aRes = await client.get('${ApiConstants.rules}/$ruleId/amendments');
      if (aRes.statusCode == 200 && aRes.data is List) {
        _amendments = aRes.data as List<dynamic>;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingVersions = false);
    }
  }

  Future<void> _approveVersion(String versionId) async {
    setState(() => _isApproving = true);
    final client = ref.read(apiClientProvider);
    try {
      final res = await client.post('${ApiConstants.rules}/versions/$versionId/approve');
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rule version approved successfully!'),
              backgroundColor: AppColors.passGreen,
            ),
          );
        }
        await _loadRuleMetadata();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve version: $e'),
            backgroundColor: AppColors.violationRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    final code = rule['code'] ?? rule['rule_code'] ?? 'RULE';
    final title = rule['title'] ?? '';
    final desc = rule['description'] ?? '';
    final ref = rule['statutory_reference'] ?? rule['statutory_source'] ?? '';
    final category = rule['category'] ?? 'OTHER';
    final coverage = rule['coverage_status'] ?? 'FULLY_IMPLEMENTED';
    final params = rule['parameters'] as Map<String, dynamic>? ?? {};
    final evidenceReqs = rule['evidence_requirements'] as List<dynamic>? ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.neutral600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Statutory Reference Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.account_balance_rounded, size: 16, color: AppColors.secondaryBlue),
                          SizedBox(width: 6),
                          Text(
                            'Statutory Source Authority',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ref,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutral900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coverage: $coverage',
                        style: const TextStyle(fontSize: 11, color: AppColors.neutral700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                const Text(
                  'Statutory Mandate & Description',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral800, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Parameters breakdown
                if (params.isNotEmpty) ...[
                  const Text(
                    'Operational Rule Parameters',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: params.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.key}: ',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              Expanded(
                                child: Text(
                                  e.value.toString(),
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.neutral800),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Evidence requirements
                if (evidenceReqs.isNotEmpty) ...[
                  const Text(
                    'Required Evidentiary Artifacts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: evidenceReqs.map((req) {
                      return Chip(
                        label: Text(req.toString(), style: const TextStyle(fontSize: 10, color: AppColors.neutral800)),
                        backgroundColor: AppColors.neutral100,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Version History Timeline
                const Text(
                  'Version History & Effective Dates',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                ),
                const SizedBox(height: 8),

                if (_isLoadingVersions)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (_versions != null && _versions!.isNotEmpty)
                  Column(
                    children: _versions!.map((v) {
                      final vMap = v as Map<String, dynamic>;
                      final vId = vMap['id'] ?? '';
                      final vNum = vMap['version'] ?? '1.0';
                      final vLabel = vMap['version_label'] ?? '';
                      final vStatus = vMap['status'] ?? 'ACTIVE';
                      final effFrom = (vMap['effective_from'] ?? '').toString().split('T').first;
                      final effTo = (vMap['effective_to'] ?? '').toString().split('T').first;
                      final isPending = vStatus == 'PENDING_REVIEW' || vStatus == 'SCHEDULED';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.commit_rounded, color: AppColors.secondaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'v$vNum',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                      if (vLabel.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text('($vLabel)', style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
                                      ],
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: vStatus == 'ACTIVE' ? AppColors.compliantBg : AppColors.neutral100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          vStatus,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: vStatus == 'ACTIVE' ? AppColors.compliant : AppColors.neutral700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Effective: $effFrom ${effTo.isNotEmpty ? "to $effTo" : "(open-ended)"}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.neutral600),
                                  ),
                                ],
                              ),
                            ),
                            if (isPending) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _isApproving ? null : () => _approveVersion(vId),
                                child: const Text('Approve'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'No previous amendment versions recorded for this rule.',
                      style: TextStyle(fontSize: 11, color: AppColors.neutral600),
                    ),
                  ),

                // Statutory Amendments Section
                if (_amendments != null && _amendments!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Official Gazette Amendments',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: _amendments!.map((a) {
                      final aMap = a as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.neutral50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aMap['amendment_name'] ?? 'Statutory Amendment',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gazette: ${aMap["gazette_notification_number"] ?? "N/A"} (${(aMap["gazette_date"] ?? "").toString().split("T").first})',
                              style: const TextStyle(fontSize: 11, color: AppColors.secondaryBlue, fontWeight: FontWeight.w600),
                            ),
                            if (aMap['summary'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                aMap['summary'],
                                style: const TextStyle(fontSize: 11, color: AppColors.neutral700),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
