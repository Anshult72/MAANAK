import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/responsive/web_page_container.dart';
import '../rule_admin_screen.dart';

/// Desktop enterprise layout for Statutory Rule Engine Registry.
class RuleAdminWebLayout extends ConsumerStatefulWidget {
  const RuleAdminWebLayout({super.key});

  @override
  ConsumerState<RuleAdminWebLayout> createState() => _RuleAdminWebLayoutState();
}

class _RuleAdminWebLayoutState extends ConsumerState<RuleAdminWebLayout> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'DECLARATIONS',
    'PDP_FONT_SIZE',
    'MRP',
    'OTHER',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRuleDetailsDialog(Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rule['code'] ?? 'RULE',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rule['title'] ?? 'Rule Specifications',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Statutory Reference: ${rule['statutory_reference'] ?? "Legal Metrology Rules, 2011"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 8),
                Text(
                  rule['description'] ?? '',
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral700, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text('Enforcement Parameters & Thresholds:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rule['parameters']?.toString() ?? 'Default deterministic evaluation rules.',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.neutral800),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesListProvider(_selectedCategory));

    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Statutory Rule Engine Registry',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Versioned rules and automated legal algorithms under Legal Metrology (Packaged Commodities) Rules, 2011',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral600),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: const BorderSide(color: AppColors.neutral300),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Rules', style: TextStyle(fontSize: 12)),
                onPressed: () => ref.refresh(rulesListProvider(_selectedCategory)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Filter Bar (Category Pills + Search)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                // Category Pills
                Wrap(
                  spacing: 6,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    String label = cat.replaceAll('_', ' ');
                    if (cat == 'ALL') label = 'All Rules';
                    if (cat == 'PDP_FONT_SIZE') label = 'PDP & Font Size (Rule 7)';
                    if (cat == 'DECLARATIONS') label = 'Declarations (Rule 6)';
                    if (cat == 'MRP') label = 'MRP & USP';

                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.secondaryBlue : AppColors.neutral100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isSelected ? AppColors.secondaryBlue : AppColors.neutral300),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.neutral700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Spacer(),

                // Search Input
                SizedBox(
                  width: 320,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search rules by code, title, or reference...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.neutral400),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.neutral500),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.neutral300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.neutral300)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Rules Table
          rulesAsync.when(
            data: (rules) {
              final filtered = rules.where((r) {
                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                final code = (r['code'] ?? '').toString().toLowerCase();
                final title = (r['title'] ?? '').toString().toLowerCase();
                final refStr = (r['statutory_reference'] ?? '').toString().toLowerCase();
                return code.contains(q) || title.contains(q) || refStr.contains(q);
              }).toList();

              return Container(
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
                child: Column(
                  children: [
                    // Header Row
                    Container(
                      color: AppColors.neutral100,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: const [
                          Expanded(flex: 2, child: Text('RULE CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 4, child: Text('TITLE & STATUTORY REFERENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('VERSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('COVERAGE STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700)))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.neutral200),

                    // Rows
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text('No statutory rules match your search.', style: TextStyle(color: AppColors.neutral500)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.neutral200),
                        itemBuilder: (context, index) {
                          final rule = filtered[index];
                          final code = rule['code'] ?? 'RULE-00${index + 1}';
                          final title = rule['title'] ?? 'Rule Specification';
                          final refStr = rule['statutory_reference'] ?? 'Legal Metrology Rules, 2011';
                          final category = rule['category'] ?? 'General';
                          final version = rule['version'] ?? '2024.1';
                          final coverage = rule['coverage_status'] ?? 'FULLY_IMPLEMENTED';

                          return InkWell(
                            onTap: () => _showRuleDetailsDialog(rule),
                            hoverColor: AppColors.neutral50,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      code,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.neutral900)),
                                        const SizedBox(height: 2),
                                        Text(refStr, style: const TextStyle(fontSize: 11.5, color: AppColors.neutral600)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(category, style: const TextStyle(fontSize: 12, color: AppColors.neutral700)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('v$version', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral700)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, size: 14, color: AppColors.passGreen),
                                        const SizedBox(width: 4),
                                        Text(
                                          coverage == 'FULLY_IMPLEMENTED' ? 'Full Engine' : 'Assisted',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.passGreen),
                                        ),
                                      ],
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
                                        icon: const Icon(Icons.tune, size: 13),
                                        label: const Text('View Logic', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        onPressed: () => _showRuleDetailsDialog(rule),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Center(child: Text('Error loading rules: $err')),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
