import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/web/judge_demo_dialog.dart';
import 'responsive_layout.dart';

/// Compact enterprise topbar for LM-TRACE desktop and tablet web.
class WebTopBar extends ConsumerWidget {
  const WebTopBar({super.key});

  String _getPageTitle(String location) {
    if (location.startsWith('/dashboard') || location == '/') return 'Operational Dashboard';
    if (location.startsWith('/inspections/')) return 'Inspection Case File';
    if (location.startsWith('/inspections')) return 'Inspections Registry';
    if (location.startsWith('/scanner')) return 'Package Scanner & OCR Workspace';
    if (location.startsWith('/products')) return 'Product Intelligence & Label Versions';
    if (location.startsWith('/rules')) return 'Statutory Rule Engine Registry';
    if (location.startsWith('/calibration')) return 'Scale & Metric Calibration';
    if (location.startsWith('/supervisor')) return 'Supervisor Enforcement Review';
    if (location.startsWith('/audit-trail')) return 'Chain of Custody Audit Trail';
    if (location.startsWith('/settings')) return 'System Configuration';
    if (location.startsWith('/about')) return 'Statutory Standards & About';
    if (location.startsWith('/new-inspection')) return 'New Inspection Case';
    return 'Legal Metrology Compliance';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Container(
      height: Breakpoints.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.neutral200, width: 1)),
      ),
      child: Row(
        children: [
          // 1. Breadcrumbs / Page Title
          if (!isDesktop) ...[
            const AppLogo.compact(size: 28),
            const SizedBox(width: 10),
          ],
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Legal Metrology',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '/',
                    style: TextStyle(fontSize: 11, color: AppColors.neutral400),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getPageTitle(location),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _getPageTitle(location),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),

          const Spacer(),

          // 2. Quick Action Buttons
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB45309),
              side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
              backgroundColor: const Color(0xFFFEF3C7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.bolt, size: 16, color: Color(0xFFD97706)),
            label: const Text(
              'Judge Demo',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () => JudgeDemoDialog.show(context),
          ),
          const SizedBox(width: 12),

          // Primary "+ New Inspection" Action Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text(
              '+ New Inspection',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () => context.push('/new-inspection'),
          ),
          const SizedBox(width: 16),

          const SizedBox(
            height: 28,
            child: VerticalDivider(color: AppColors.neutral300, thickness: 1),
          ),
          const SizedBox(width: 16),

          // 3. Officer Profile Badge
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primaryNavy,
                    child: Text(
                      (user?.fullName ?? 'R').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Ramesh Verma',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.neutral200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                user?.role ?? 'INSPECTOR',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutral700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user?.zone ?? 'New Delhi Central Zone',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.neutral500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
