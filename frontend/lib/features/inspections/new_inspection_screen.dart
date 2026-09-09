import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'inspections_controller.dart';

class NewInspectionScreen extends ConsumerStatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  ConsumerState<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends ConsumerState<NewInspectionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _locationController = TextEditingController(text: 'Khan Market, Shop 14, New Delhi');
  final _businessController = TextEditingController(text: 'Heritage Fresh Supermarket');
  final _sellerController = TextEditingController(text: 'Retail Traders Pvt Ltd');
  final _notesController = TextEditingController();

  String _inspectionType = 'PHYSICAL';
  String _category = 'Packaged Food';
  String _constructionType = 'NORMAL';
  String _packageType = 'RECTANGULAR';

  final List<String> _categories = [
    'Packaged Food',
    'Edible Oils & Fats',
    'Beverages & Juices',
    'Cosmetics & Toiletries',
    'Soaps & Detergents',
    'Baby Food & Milk Powder',
    'General Merchandise',
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _businessController.dispose();
    _sellerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(inspectionsProvider.notifier);
    final inspection = await controller.createInspection(
      location: _locationController.text.trim(),
      sellerName: _sellerController.text.trim(),
      businessName: _businessController.text.trim(),
      productCategory: _category,
      inspectionType: _inspectionType,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (inspection != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created inspection ${inspection.inspectionCode}'),
          backgroundColor: AppColors.compliant,
        ),
      );

      if (_inspectionType == 'ONLINE_LISTING') {
        context.push('/online-listing?inspectionId=${inspection.id}');
      } else {
        // Use go() not push() — /scanner is inside ShellRoute and
        // push() from outside the shell creates a duplicate shell page key.
        context.go('/scanner?inspectionId=${inspection.id}');
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize inspection. Please try again.'),
          backgroundColor: AppColors.violation,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Initiate New Inspection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.secondary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Inspections are governed by Legal Metrology (Packaged Commodities) Rules, 2011. Captured records are sealed with audit provenance.',
                        style: TextStyle(fontSize: 12, color: AppColors.neutral700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Inspection Type Toggle
              const Text(
                'Inspection Channel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeRadio(
                      title: 'Physical Commodity',
                      subtitle: 'Retail shelf / Warehouse',
                      icon: Icons.inventory_2_outlined,
                      value: 'PHYSICAL',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeRadio(
                      title: 'E-Commerce Listing',
                      subtitle: 'Online Marketplace (Rule 2027)',
                      icon: Icons.language,
                      value: 'ONLINE_LISTING',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Retailer & Location Details
              _buildSectionTitle('Location & Trader Information'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _businessController,
                decoration: const InputDecoration(
                  labelText: 'Establishment / Trader Name *',
                  hintText: 'e.g. M/s Greenfield Retail Hub',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Inspection Location / Address *',
                  hintText: 'Shop No., Market, District, State',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellerController,
                decoration: const InputDecoration(
                  labelText: 'Dealer / Seller Licensee (Optional)',
                  hintText: 'e.g. Retail Traders Pvt Ltd',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Commodity & Package Characteristics
              _buildSectionTitle('Commodity Classification (Rule 6 & 7 Context)'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Commodity Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _constructionType,
                      decoration: const InputDecoration(
                        labelText: 'Package Construction',
                        helperText: 'Rule 7 Table-I font scaling',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'NORMAL',
                          child: Text('Normal (Cardboard / Poly / Label)'),
                        ),
                        DropdownMenuItem(
                          value: 'BLOWN_FORMED_MOLDED',
                          child: Text('Blown / Formed / Molded (Glass/Plastic)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _constructionType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _packageType,
                decoration: const InputDecoration(
                  labelText: 'Package Geometry / Shape',
                  helperText: 'Calculates Principal Display Panel (PDP) area',
                ),
                items: const [
                  DropdownMenuItem(value: 'RECTANGULAR', child: Text('Rectangular (H × W)')),
                  DropdownMenuItem(value: 'CYLINDRICAL', child: Text('Cylindrical (40% of H × Circumference)')),
                  DropdownMenuItem(value: 'IRREGULAR', child: Text('Irregular / Other (40% Total Surface)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _packageType = val);
                },
              ),
              const SizedBox(height: 16),

              // Inspector Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Preliminary Notes / Case Memo (Optional)',
                  hintText: 'e.g. Spot audit based on consumer complaint regarding altered MRP',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    state.isLoading ? 'Creating Case...' : 'Create & Proceed to Capture',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: state.isLoading ? null : _handleCreate,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildTypeRadio({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _inspectionType == value;
    return InkWell(
      onTap: () => setState(() => _inspectionType = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.secondary : AppColors.neutral600,
                  size: 20,
                ),
                const Spacer(),
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.secondary : AppColors.neutral400,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.secondary : AppColors.neutral800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
          ],
        ),
      ),
    );
  }
}
