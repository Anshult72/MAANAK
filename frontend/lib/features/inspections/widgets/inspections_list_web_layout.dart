import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/responsive/web_page_container.dart';
import '../inspections_controller.dart';

/// Desktop enterprise data table layout for Inspections Registry.
class InspectionsListWebLayout extends ConsumerStatefulWidget {
  const InspectionsListWebLayout({super.key});

  @override
  ConsumerState<InspectionsListWebLayout> createState() => _InspectionsListWebLayoutState();
}

class _InspectionsListWebLayoutState extends ConsumerState<InspectionsListWebLayout> {
  String _statusFilter = 'ALL';
  String _typeFilter = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionsProvider);
    final allInspections = state.inspections;

    final filtered = allInspections.where((ins) {
      // Status filter
      final s = ins.status.toUpperCase();
      if (_statusFilter == 'COMPLIANT' && !['COMPLIANT', 'COMPLETED', 'FINALIZED'].contains(s)) {
        return false;
      }
      if (_statusFilter == 'VIOLATION' && !['VIOLATION', 'POTENTIAL_VIOLATION'].contains(s)) {
        return false;
      }
      if (_statusFilter == 'REVIEW' && !['REVIEW_REQUIRED', 'IN_REVIEW', 'NEEDS_REVIEW', 'DRAFT'].contains(s)) {
        return false;
      }

      // Type filter
      if (_typeFilter != 'ALL' && ins.inspectionType.toUpperCase() != _typeFilter) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesCode = ins.inspectionCode.toLowerCase().contains(q);
        final matchesLoc = ins.location.toLowerCase().contains(q);
        final matchesSeller = (ins.sellerName ?? ins.businessName ?? '').toLowerCase().contains(q);
        return matchesCode || matchesLoc || matchesSeller;
      }

      return true;
    }).toList();

    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Page Header & Primary Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Inspections Registry',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review, manage, and verify statutory Legal Metrology inspection case records',
                    style: TextStyle(fontSize: 13, color: AppColors.neutral600),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      side: const BorderSide(color: AppColors.neutral300),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                    onPressed: () => ref.read(inspectionsProvider.notifier).fetchInspections(),
                  ),
                  const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 20),

          // 2. Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search case ID, trader establishment, or site address...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.neutral400),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.neutral500),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.neutral300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.neutral300),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 16),

                // Status Filter Chips
                Wrap(
                  spacing: 6,
                  children: [
                    _buildFilterPill('ALL', 'All (${allInspections.length})'),
                    _buildFilterPill('COMPLIANT', 'Compliant'),
                    _buildFilterPill('REVIEW', 'Needs Review'),
                    _buildFilterPill('VIOLATION', 'Violations'),
                  ],
                ),
                const SizedBox(width: 16),

                // Inspection Type Filter Dropdown
                DropdownButton<String>(
                  value: _typeFilter,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.neutral800, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Inspection Types')),
                    DropdownMenuItem(value: 'PHYSICAL', child: Text('Physical Package')),
                    DropdownMenuItem(value: 'ONLINE_LISTING', child: Text('E-Commerce Listing')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _typeFilter = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Desktop Table Container
          Container(
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
                // Table Column Headers
                Container(
                  color: AppColors.neutral100,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text('CASE ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 3, child: Text('ESTABLISHMENT / TRADER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 3, child: Text('LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 2, child: Text('INSPECTION TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 2, child: Text('PACKAGE TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 2, child: Text('AUDIT DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700)))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.neutral200),

                // Table Rows or Empty State
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.folder_open, size: 44, color: AppColors.neutral400),
                          const SizedBox(height: 10),
                          const Text('No inspection cases match your filter criteria.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
                          const SizedBox(height: 4),
                          const Text('Try clearing search terms or selecting "All Cases".', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _statusFilter = 'ALL';
                                _typeFilter = 'ALL';
                              });
                            },
                            child: const Text('Reset Filters'),
                          ),
                        ],
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

                // Table Footer / Counts
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    border: Border(top: BorderSide(color: AppColors.neutral200, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Showing ${filtered.length} of ${allInspections.length} recorded cases',
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                      ),
                      const Spacer(),
                      const Text(
                        'LM-TRACE Regulatory Inspection Database',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String key, String label) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                ins.businessName ?? ins.sellerName ?? 'Enterprise',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
              child: Text(
                ins.packageType ?? 'RECTANGULAR',
                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 16, color: AppColors.secondaryBlue),
                      tooltip: 'Open in Scanner',
                      onPressed: () => context.go('/scanner?inspectionId=${ins.id}'),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 12),
                      label: const Text('View Case', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => context.push('/inspections/${ins.id}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
