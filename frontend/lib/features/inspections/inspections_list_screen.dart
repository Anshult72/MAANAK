import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import 'inspections_controller.dart';
import 'widgets/inspections_list_web_layout.dart';

class InspectionsListScreen extends ConsumerStatefulWidget {
  const InspectionsListScreen({super.key});

  @override
  ConsumerState<InspectionsListScreen> createState() => _InspectionsListScreenState();
}

class _InspectionsListScreenState extends ConsumerState<InspectionsListScreen> {
  String _filter = 'ALL';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inspectionsProvider.notifier).fetchInspections();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isWebDesktop(context)) {
      return const InspectionsListWebLayout();
    }

    final state = ref.watch(inspectionsProvider);

    List<InspectionModel> filtered = state.inspections.where((ins) {
      if (_filter == 'COMPLIANT' && !['COMPLETED', 'COMPLIANT'].contains(ins.status.toUpperCase())) {
        return false;
      }
      if (_filter == 'VIOLATIONS' && !['POTENTIAL_VIOLATION', 'VIOLATION'].contains(ins.status.toUpperCase())) {
        return false;
      }
      if (_filter == 'REVIEW' && !['REVIEW_REQUIRED', 'IN_REVIEW', 'DRAFT'].contains(ins.status.toUpperCase())) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesCode = ins.inspectionCode.toLowerCase().contains(q);
        final matchesLoc = ins.location.toLowerCase().contains(q);
        final matchesSeller = (ins.sellerName ?? ins.businessName ?? '').toLowerCase().contains(q);
        return matchesCode || matchesLoc || matchesSeller;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Inspections Registry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(inspectionsProvider.notifier).fetchInspections(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by case ID, establishment, or location...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Cases (${state.inspections.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('VIOLATIONS', 'Violations Flagged', color: AppColors.violation),
                      const SizedBox(width: 8),
                      _buildFilterChip('REVIEW', 'Pending Review', color: AppColors.review),
                      const SizedBox(width: 8),
                      _buildFilterChip('COMPLIANT', 'Compliant', color: AppColors.compliant),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // List View
          Expanded(
            child: state.isLoading && state.inspections.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppColors.neutral400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No records matching "$_searchQuery"'
                                  : 'No inspections found in this category',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ins = filtered[index];
                          return _buildInspectionTile(context, ins);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Inspection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/new-inspection'),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? color}) {
    final isSelected = _filter == filterKey;
    final chipColor = color ?? AppColors.primary;

    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.neutral700,
        ),
      ),
      backgroundColor: AppColors.neutral100,
      selectedColor: chipColor,
      showCheckmark: false,
      onSelected: (val) {
        if (val) setState(() => _filter = filterKey);
      },
    );
  }

  Widget _buildInspectionTile(BuildContext context, InspectionModel ins) {
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
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/inspections/${ins.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        ins.inspectionCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                  Text(
                    ins.inspectionDate.split('T').first,
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral400),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ins.businessName ?? ins.sellerName ?? 'Retail Goods Inspection',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ins.location,
                      style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildBadge(ins.inspectionType, Icons.category_outlined),
                      if (ins.packageConstructionType != null)
                        _buildBadge(
                          ins.packageConstructionType == 'BLOWN_FORMED_MOLDED' ? 'Molded/Blown' : 'Standard Pack',
                          Icons.inventory_2_outlined,
                        ),
                    ],
                  ),
                  Row(
                    children: const [
                      Text(
                        'Audit Details',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.secondary),
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

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.neutral600),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(fontSize: 10, color: AppColors.neutral700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
