import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inspections/inspections_list_screen.dart';
import '../../features/inspections/new_inspection_screen.dart';
import '../../features/inspections/inspection_detail_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/calibration/calibration_screen.dart';
import '../../features/evidence/evidence_viewer_screen.dart';
import '../../features/ai_analysis/analysis_progress_screen.dart';
import '../../features/reports/report_preview_screen.dart';
import '../../features/products/product_list_screen.dart';
import '../../features/products/product_history_screen.dart';
import '../../features/online_listing/online_listing_screen.dart';
import '../../features/rule_management/rule_admin_screen.dart';
import '../../features/supervisor/supervisor_screen.dart';
import '../../features/profile/officer_profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/audit/audit_trail_screen.dart';
import '../../features/about/help_about_screen.dart';

import '../responsive/web_app_shell.dart';

// Stable navigator keys — survive GoRouter refreshes.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Creates the application [GoRouter].
///
/// The router is created ONCE and stored in the widget tree (not inside a
/// Riverpod Provider) so that Riverpod can never dispose/recreate it.
/// Auth-driven redirect is re-evaluated via [refreshListenable].
///
/// [authNotifier] is bumped externally (from the widget's build method via
/// ref.listen) whenever [authProvider] changes.
GoRouter createAppRouter(WidgetRef ref, ValueListenable<int> authNotifier) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuth = ref.read(authProvider).isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }
      if (isAuth && isLoggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Operational Navigation Shell (Sidebar & Topbar on Web Desktop, Bottom Nav on Mobile)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return WebAppShell(
            mobileChild: ScaffoldWithBottomNavBar(child: child),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inspections',
            builder: (context, state) => const InspectionsListScreen(),
          ),
          GoRoute(
            path: '/scanner',
            builder: (context, state) {
              final id = state.uri.queryParameters['inspectionId'];
              return ScannerScreen(inspectionId: id);
            },
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductListScreen(),
          ),
          GoRoute(
            path: '/rules',
            builder: (context, state) => const RuleAdminScreen(),
          ),
        ],
      ),

      // Detail & Workflow Screens
      GoRoute(
        path: '/new-inspection',
        builder: (context, state) => const NewInspectionScreen(),
      ),
      GoRoute(
        path: '/inspections/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return InspectionDetailScreen(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/calibration',
        builder: (context, state) {
          final id = state.uri.queryParameters['inspectionId'] ?? 'ins-001';
          return CalibrationScreen(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/evidence/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EvidenceViewerScreen(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/analysis-progress/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AnalysisProgressScreen(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/reports/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ReportPreviewScreen(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductHistoryScreen(productId: id);
        },
      ),
      GoRoute(
        path: '/online-listing',
        builder: (context, state) {
          final id = state.uri.queryParameters['inspectionId'];
          return OnlineListingScreen(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/supervisor',
        builder: (context, state) => const SupervisorScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const OfficerProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/audit-trail',
        builder: (context, state) => const AuditTrailScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const HelpAboutScreen(),
      ),
    ],
  );
}

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithBottomNavBar({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/inspections')) return 1;
    if (location.startsWith('/scanner')) return 2;
    if (location.startsWith('/products')) return 3;
    if (location.startsWith('/rules')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/inspections');
        break;
      case 2:
        context.go('/scanner');
        break;
      case 3:
        context.go('/products');
        break;
      case 4:
        context.go('/rules');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _onItemTapped(index, context),
          selectedItemColor: AppColors.secondary,
          unselectedItemColor: AppColors.neutral400,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Inspections',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_outlined),
              activeIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fingerprint_outlined),
              activeIcon: Icon(Icons.fingerprint),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gavel_outlined),
              activeIcon: Icon(Icons.gavel),
              label: 'Rules',
            ),
          ],
        ),
      ),
    );
  }
}
