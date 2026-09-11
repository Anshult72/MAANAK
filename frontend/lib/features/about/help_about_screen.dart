import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Help & About MAANAK'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Branding Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.neutral200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MAANAK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Legal Metrology Compliance & Inspection Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ministry of Consumer Affairs, Food and Public Distribution\nGovernment of India',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.neutral600, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Production Release v1.0.0',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.neutral700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statutory Mandate
          _buildInfoCard(
            title: 'STATUTORY AUTHORITY',
            children: const [
              Text(
                'MAANAK automates the enforcement of statutory labeling standards under:',
                style: TextStyle(fontSize: 12, color: AppColors.neutral700),
              ),
              SizedBox(height: 6),
              Text(
                '• The Legal Metrology Act, 2009 (Act No. 1 of 2010)\n• The Legal Metrology (Packaged Commodities) Rules, 2011\n• E-Commerce Amendment Rules, 2017 (GSR 629(E))\n• Unit Sale Price Amendment Rules, 2021 (GSR 779(E))\n• Electronic Products Provisions, 2022 (GSR 529(E))',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral900, height: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Platform Capabilities
          _buildInfoCard(
            title: 'CORE CAPABILITIES',
            children: [
              _buildCapabilityRow(Icons.document_scanner_outlined, 'Multi-Surface AI OCR', 'Grounds declaration text across all package surfaces with pixel coordinates.'),
              _buildCapabilityRow(Icons.straighten_outlined, 'Table-I PDP Measurement', 'Evaluates minimum numeral/letter height against packaging area thresholds.'),
              _buildCapabilityRow(Icons.currency_rupee_outlined, 'Dual MRP & Pricing Checks', 'Detects predatory pricing, multiple MRPs, and unit sale price omissions.'),
              _buildCapabilityRow(Icons.shopping_cart_outlined, 'Marketplace Listing Scan', 'Monitors e-commerce PDP viewports for Rule 6(10) mandatory declarations.'),
              _buildCapabilityRow(Icons.fingerprint_outlined, 'Product Fingerprinting', 'Tracks packaging revisions and alerts inspectors to shrinkflation.'),
            ],
          ),
          const SizedBox(height: 16),

          // Support & Technical Contact
          _buildInfoCard(
            title: 'ENFORCEMENT SUPPORT',
            children: const [
              Text(
                'For operational assistance or technical escalation, contact Central Legal Metrology Enforcement Cell:',
                style: TextStyle(fontSize: 12, color: AppColors.neutral700),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 16, color: AppColors.secondaryBlue),
                  SizedBox(width: 8),
                  Text('support@maanak.gov.in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryBlue)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.neutral200),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 11, color: AppColors.neutral600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
