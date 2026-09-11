import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/auth_controller.dart';

class MaanakNavigationDrawer extends ConsumerWidget {
  const MaanakNavigationDrawer({super.key});

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
    final fullName = user?.fullName ?? 'Enforcement Officer';
    final role = (user?.role ?? 'INSPECTOR').toUpperCase();
    final department = user?.department ?? 'Legal Metrology Department';
    final zone = user?.zone ?? 'Central Enforcement Zone';
    final officerId = user?.officerId ?? 'LM-001';
    final isSupervisorOrAdmin = role == 'SUPERVISOR' || role == 'ADMIN';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 1. Officer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primaryNavy,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.secondaryBlue,
                      child: Text(
                        _getInitials(fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const AppLogo.compact(
                      size: 32,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  zone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$department • ID: $officerId',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // 2. Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Core Operations
                _buildDrawerSectionTitle('PRIMARY NAVIGATION'),
                _buildDrawerTile(
                  context,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  title: 'Dashboard',
                  route: '/dashboard',
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment,
                  title: 'My Inspections',
                  route: '/inspections',
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.fingerprint_outlined,
                  activeIcon: Icons.fingerprint,
                  title: 'Products',
                  route: '/products',
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.gavel_outlined,
                  activeIcon: Icons.gavel,
                  title: 'Statutory Rules',
                  route: '/rules',
                ),

                // Role-based supervisor extension
                if (isSupervisorOrAdmin) ...[
                  _buildDrawerTile(
                    context,
                    icon: Icons.admin_panel_settings_outlined,
                    activeIcon: Icons.admin_panel_settings,
                    title: 'Supervisor Oversight',
                    route: '/supervisor',
                    badgeText: 'COMMAND',
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Divider(height: 1, color: AppColors.neutral200),
                ),

                // Account & System
                _buildDrawerSectionTitle('OFFICER & SYSTEM'),
                _buildDrawerTile(
                  context,
                  icon: Icons.badge_outlined,
                  title: 'Officer Profile',
                  route: '/profile',
                  semanticLabel: 'Officer Profile',
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Activity / Audit History',
                  route: '/audit-trail',
                  semanticLabel: 'Activity and Audit History',
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  route: '/settings',
                  semanticLabel: 'Settings',
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: 'Help & About LM-TRACE',
                  route: '/about',
                  semanticLabel: 'Help and About',
                ),
              ],
            ),
          ),

          // 3. Logout Section
          const Divider(height: 1, color: AppColors.neutral200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.logout_rounded, color: AppColors.violationRed, size: 22),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.violationRed,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'End session & clear security credentials',
                style: TextStyle(fontSize: 11, color: AppColors.neutral500),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: AppColors.neutral500,
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    IconData? activeIcon,
    required String title,
    required String route,
    String? badgeText,
    String? semanticLabel,
  }) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final isSelected = currentLocation == route || currentLocation.startsWith('$route/');

    return Semantics(
      label: semanticLabel ?? title,
      button: true,
      child: ListTile(
        dense: true,
        leading: Icon(
          isSelected && activeIcon != null ? activeIcon : icon,
          color: isSelected ? AppColors.secondaryBlue : AppColors.neutral700,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.secondaryBlue : AppColors.neutral900,
          ),
        ),
        trailing: badgeText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryBlue,
                  ),
                ),
              )
            : null,
        selected: isSelected,
        selectedTileColor: AppColors.secondaryBlue.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          if (route.startsWith('/dashboard') ||
              route.startsWith('/inspections') ||
              route.startsWith('/products') ||
              route.startsWith('/rules')) {
            context.go(route);
          } else {
            context.push(route);
          }
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to end your current session? You will be returned to the secure login screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violationRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close dialog
              Navigator.of(context).pop(); // Close drawer
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
