import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

final productHistoryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, productId) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get("${ApiConstants.products}/$productId/history");
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
  } catch (e) {
    // Fallback data for demo
  }
  return {
    'product': {
      'id': productId,
      'brand': 'Heritage Foods',
      'name': 'Heritage Pure Cow Ghee 1L',
      'gtin': '8901234567890',
      'category': 'Edible Oils & Fats',
      'fingerprint_hash': 'sha256:7b92f4c92881a...d910',
    },
    'label_versions': [
      {
        'version_id': 'v2',
        'effective_from': '2026-01-15',
        'mrp': '₹650',
        'net_quantity': '950 ml',
        'font_height_mm': 1.8,
        'min_required_font_mm': 2.5,
        'phash': 'phash:a93f0b21',
        'summary': 'Redesigned gold-embossed bottle label with altered declaration placement.',
        'change_type': 'BOTH',
        'status': 'POTENTIAL_VIOLATION',
        'flags': ['Shrinkflation (1000ml -> 950ml)', 'Net Qty Font 1.8mm < Rule 7 Required 2.5mm'],
      },
      {
        'version_id': 'v1',
        'effective_from': '2024-06-10',
        'mrp': '₹580',
        'net_quantity': '1000 ml',
        'font_height_mm': 2.6,
        'min_required_font_mm': 2.5,
        'phash': 'phash:8812c310',
        'summary': 'Standard compliant packaging as per LM Amendment 2021.',
        'change_type': 'BASELINE',
        'status': 'COMPLIANT',
        'flags': [],
      }
    ],
    'inspection_count': 4
  };
});

class ProductHistoryScreen extends ConsumerWidget {
  final String productId;

  const ProductHistoryScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(productHistoryProvider(productId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('SKU Label Evolution & Diff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(productHistoryProvider(productId)),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (data) {
          final product = data['product'] as Map<String, dynamic>? ?? {};
          final versions = (data['label_versions'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Master Header
                _buildProductMasterCard(product),
                const SizedBox(height: 16),

                // Shrinkflation & Alteration Alert if v2 has violation
                if (versions.isNotEmpty && versions.first['status'] == 'POTENTIAL_VIOLATION')
                  _buildShrinkflationAlert(versions.first),
                const SizedBox(height: 16),

                // Version Timeline & Comparative Diff
                const Text(
                  'Packaging Evolution Timeline (v1 vs v2)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Compares semantic declarations (MRP, Quantity, Font) and perceptual visual layout.',
                  style: TextStyle(fontSize: 11, color: AppColors.neutral600),
                ),
                const SizedBox(height: 12),

                ...versions.map((ver) => _buildVersionCard(ver)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading history: $e')),
      ),
    );
  }

  Widget _buildProductMasterCard(Map<String, dynamic> product) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                product['brand'] ?? 'Commodity Brand',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GTIN: ${product['gtin'] ?? '8901234567890'}',
                  style: const TextStyle(fontSize: 10, color: AppColors.neutral700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            product['name'] ?? 'Packaged Product',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.fingerprint, size: 14, color: AppColors.neutral500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'SHA-256 Identity: ${product['fingerprint_hash'] ?? 'Verified'}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.neutral600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShrinkflationAlert(Map<String, dynamic> latestVersion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violationBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.violation.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning, color: AppColors.violation, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POTENTIAL SHRINKFLATION & RULE 7 VIOLATION',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.violation),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Net Quantity dropped by 5% (1000ml -> 950ml) with an MRP hike (₹580 -> ₹650). '
                  'Additionally, the declared Net Quantity font size was reduced from 2.6mm to 1.8mm, falling below the mandatory 2.5mm minimum threshold.',
                  style: TextStyle(fontSize: 11, color: AppColors.neutral800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(dynamic v) {
    final ver = v as Map<String, dynamic>;
    final isBaseline = ver['change_type'] == 'BASELINE';
    final hasViolation = ver['status'] == 'POTENTIAL_VIOLATION';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasViolation ? AppColors.violation : AppColors.neutral200,
          width: hasViolation ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBaseline ? AppColors.compliantBg : AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Version ${ver['version_id']}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBaseline ? AppColors.compliant : AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Effective: ${ver['effective_from']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: hasViolation ? AppColors.violationBg : AppColors.compliantBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ver['status'] ?? 'AUDITED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasViolation ? AppColors.violation : AppColors.compliant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Parameter Matrix
          Row(
            children: [
              _buildDiffColumn('Declared MRP', ver['mrp'] ?? 'N/A', isAlert: !isBaseline),
              _buildDiffColumn('Net Quantity', ver['net_quantity'] ?? 'N/A', isAlert: hasViolation),
              _buildDiffColumn(
                'Font Height',
                '${ver['font_height_mm']} mm',
                subText: 'Min: ${ver['min_required_font_mm']} mm',
                isAlert: hasViolation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ver['summary'] ?? '',
            style: const TextStyle(fontSize: 12, color: AppColors.neutral700),
          ),
          if (ver['phash'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Perceptual Hash: ${ver['phash']}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.neutral400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffColumn(String label, String val, {String? subText, bool isAlert = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.neutral500)),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isAlert ? AppColors.violation : AppColors.neutral900,
            ),
          ),
          if (subText != null)
            Text(
              subText,
              style: TextStyle(
                fontSize: 9,
                color: isAlert ? AppColors.violation : AppColors.neutral400,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
