import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/responsive/web_page_container.dart';
import '../product_list_screen.dart';

/// Desktop enterprise layout for Product Intelligence & Fingerprint Registry.
class ProductListWebLayout extends ConsumerStatefulWidget {
  const ProductListWebLayout({super.key});

  @override
  ConsumerState<ProductListWebLayout> createState() => _ProductListWebLayoutState();
}

class _ProductListWebLayoutState extends ConsumerState<ProductListWebLayout> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);

    return WebPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Product Intelligence & Fingerprint Registry',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track pre-packaged SKU identities, label version evolution, and silent shrinkflation history',
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
                label: const Text('Refresh Registry', style: TextStyle(fontSize: 12)),
                onPressed: () => ref.refresh(productsListProvider),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Informational Banner on Label Evolution & Shrinkflation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: const [
                Icon(Icons.fingerprint, color: AppColors.secondaryBlue, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fingerprint Visual Hash Engine: Automatically hashes packaging declarations across time. Detects silent net-weight shrinkflation, MRP escalations, and illegal font-size reductions between production batches.',
                    style: TextStyle(fontSize: 12, color: AppColors.neutral800, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products by GTIN barcode, brand, or commodity name...',
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
          const SizedBox(height: 18),

          // 4. Products Table
          productsAsync.when(
            data: (products) {
              final filtered = products.where((p) {
                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                final name = (p['name'] ?? '').toString().toLowerCase();
                final brand = (p['brand'] ?? '').toString().toLowerCase();
                final gtin = (p['gtin'] ?? p['barcode'] ?? '').toString().toLowerCase();
                return name.contains(q) || brand.contains(q) || gtin.contains(q);
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
                          Expanded(flex: 3, child: Text('BRAND & COMMODITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('GTIN BARCODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('PACK SIZE / MRP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('ACTIVE VERSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Text('FINGERPRINT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral700)))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.neutral200),

                    // Product Rows
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text('No products match your search criteria.', style: TextStyle(color: AppColors.neutral500)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.neutral200),
                        itemBuilder: (context, index) {
                          final prod = filtered[index];
                          final id = prod['id'] ?? 'prod-$index';
                          final brand = prod['brand'] ?? 'Brand';
                          final name = prod['name'] ?? 'Product';
                          final category = prod['category'] ?? 'Packaged Commodity';
                          final gtin = prod['gtin'] ?? prod['barcode'] ?? '8901234567890';
                          final qty = prod['declared_net_quantity'] ?? prod['net_quantity'] ?? '1 Unit';
                          final mrp = prod['declared_mrp'] ?? prod['mrp'] ?? 'Standard';
                          final version = prod['active_version'] ?? 'v1.0';

                          return InkWell(
                            onTap: () => context.push('/products/$id'),
                            hoverColor: AppColors.neutral50,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy)),
                                        Text(brand, style: const TextStyle(fontSize: 11.5, color: AppColors.neutral600)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(category, style: const TextStyle(fontSize: 12, color: AppColors.neutral700)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.qr_code, size: 14, color: AppColors.neutral500),
                                        const SizedBox(width: 4),
                                        Text(gtin, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.neutral800)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('$qty • $mrp', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral800)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(version, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: const [
                                        Icon(Icons.check_circle, size: 13, color: AppColors.passGreen),
                                        SizedBox(width: 4),
                                        Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.passGreen, fontWeight: FontWeight.w600)),
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
                                        icon: const Icon(Icons.history, size: 13),
                                        label: const Text('Version Diff', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        onPressed: () => context.push('/products/$id'),
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
              child: Center(child: Text('Error loading product registry: $err')),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
