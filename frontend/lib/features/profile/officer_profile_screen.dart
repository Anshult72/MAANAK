import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_brand.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';

class OfficerProfileScreen extends ConsumerWidget {
  const OfficerProfileScreen({super.key});

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'OF';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final fullName = user?.fullName ?? 'Officer';
    final officerId = user?.officerId ?? 'LM-001';
    final role = (user?.role ?? 'INSPECTOR').toUpperCase();
    final department = user?.department ?? 'Legal Metrology Department';
    final zone = user?.zone ?? 'Central Enforcement Zone';
    final email = user?.email ?? AppBrand.defaultOfficerEmail;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Officer Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Hero Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.neutral200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryNavy,
                      child: Text(
                        _getInitials(fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Officer ID: $officerId',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.secondaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: AppColors.secondaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Credentials & Official Details
            _buildSection(
              title: 'OFFICIAL ASSIGNMENT',
              children: [
                _buildInfoRow(
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: department,
                ),
                _buildInfoRow(
                  icon: Icons.map_outlined,
                  label: 'Enforcement Zone',
                  value: zone,
                ),
                _buildInfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Statutory Authority',
                  value: 'Legal Metrology Act, 2009',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact & Authentication
            _buildSection(
              title: 'ACCOUNT CREDENTIALS',
              children: [
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Official Email',
                  value: email,
                ),
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Designation Code',
                  value: '$role • $officerId',
                ),
                _buildInfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Account Status',
                  value: 'Active & Authorized',
                  valueColor: AppColors.passGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Authority notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, size: 18, color: AppColors.secondaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Official credentials and jurisdiction are governed by Central Legal Metrology Administration. Role and posting changes require administrative clearance.',
                      style: TextStyle(fontSize: 11, color: AppColors.neutral700, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
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
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.neutral500),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.neutral900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
