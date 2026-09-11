import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../constants/app_brand.dart';
import '../widgets/app_logo.dart';
import '../../features/web/judge_demo_dialog.dart';
import 'responsive_layout.dart';

/// Persistent enterprise left sidebar for LM-TRACE desktop and tablet web.
class WebSidebar extends StatelessWidget {
  final bool isCollapsed;

  const WebSidebar({super.key, this.isCollapsed = false});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: isCollapsed ? Breakpoints.collapsedSidebarWidth : Breakpoints.sidebarWidth,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        border: Border(right: BorderSide(color: Color(0xFF1E3A5F), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Branding Header
          _buildBrandHeader(context),
          const Divider(color: Color(0xFF1E3A5F), height: 1),

          // 2. Primary Navigation
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCollapsed)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Text(
                        'CORE INSPECTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Color(0xFF8DA4C4),
                        ),
                      ),
                    ),
                  _buildNavItem(
                    context,
                    label: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    route: '/dashboard',
                    isActive: location == '/dashboard' || location == '/',
                  ),
                  _buildNavItem(
                    context,
                    label: 'Inspections Registry',
                    icon: Icons.assignment_outlined,
                    activeIcon: Icons.assignment,
                    route: '/inspections',
                    isActive: location.startsWith('/inspections'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'Scan & Ingestion',
                    icon: Icons.qr_code_scanner_outlined,
                    activeIcon: Icons.qr_code_scanner,
                    route: '/scanner',
                    isActive: location.startsWith('/scanner'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'Product Intelligence',
                    icon: Icons.fingerprint_outlined,
                    activeIcon: Icons.fingerprint,
                    route: '/products',
                    isActive: location.startsWith('/products'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'Statutory Rule Engine',
                    icon: Icons.gavel_outlined,
                    activeIcon: Icons.gavel,
                    route: '/rules',
                    isActive: location.startsWith('/rules'),
                  ),

                  const SizedBox(height: 14),
                  if (!isCollapsed) ...[
                    const Divider(color: Color(0xFF1E3A5F), height: 1),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Text(
                        'ENFORCEMENT & SYSTEM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Color(0xFF8DA4C4),
                        ),
                      ),
                    ),
                  ],
                  _buildNavItem(
                    context,
                    label: 'Scale Calibration',
                    icon: Icons.straighten_outlined,
                    activeIcon: Icons.straighten,
                    route: '/calibration',
                    isActive: location.startsWith('/calibration'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'Supervisor Review',
                    icon: Icons.supervisor_account_outlined,
                    activeIcon: Icons.supervisor_account,
                    route: '/supervisor',
                    isActive: location.startsWith('/supervisor'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'Audit Trail',
                    icon: Icons.history_edu_outlined,
                    activeIcon: Icons.history_edu,
                    route: '/audit-trail',
                    isActive: location.startsWith('/audit-trail'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'Statutory Reference',
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book,
                    route: '/about',
                    isActive: location.startsWith('/about'),
                  ),
                  _buildNavItem(
                    context,
                    label: 'System Settings',
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    route: '/settings',
                    isActive: location.startsWith('/settings'),
                  ),
                ],
              ),
            ),
          ),

          // 3. Footer with Judge Demo CTA & Status
          _buildSidebarFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    if (isCollapsed) {
      return Container(
        height: Breakpoints.topBarHeight,
        alignment: Alignment.center,
        child: const AppLogo.compact(
          size: 42,
          tooltip: '${AppBrand.name} — ${AppBrand.subtitle}',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 195, maxHeight: 110),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const AppLogo(
                fit: BoxFit.contain,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF2E4D7A), width: 0.8),
              ),
              child: const Text(
                'Legal Metrology • Govt. of India',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required String route,
    required bool isActive,
  }) {
    final effectiveColor = isActive ? Colors.white : const Color(0xFFCBD5E1);
    final effectiveBg = isActive ? const Color(0xFF1E3A5F) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFF162D4A),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: AppColors.accentBlue.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? const Color(0xFF60A5FA) : effectiveColor,
                size: 20,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: effectiveColor,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF60A5FA),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    if (isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: IconButton(
          icon: const Icon(Icons.bolt, color: Color(0xFFFBBF24)),
          tooltip: 'Judge Demo',
          onPressed: () => JudgeDemoDialog.show(context),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1B29),
        border: Border(top: BorderSide(color: Color(0xFF1E3A5F), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judge Demo Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.bolt, size: 16, color: Colors.white),
              label: const Text(
                '⚡ Judge Demo Mode',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => JudgeDemoDialog.show(context),
            ),
          ),
          const SizedBox(height: 10),

          // Engine Status Indicator
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Engine Online • Rule v2024.1',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
