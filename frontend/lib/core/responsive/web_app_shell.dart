import 'package:flutter/material.dart';
import 'responsive_layout.dart';
import 'web_sidebar.dart';
import 'web_top_bar.dart';

/// Master responsive application shell for LM-TRACE.
///
/// On Desktop & Tablet Web:
/// - Renders persistent left navigation sidebar
/// - Renders compact enterprise topbar
/// - Eliminates mobile bottom navigation
/// - Provides clean scrollable workspace container
///
/// On Mobile / Android:
/// - Renders the existing mobile layout with bottom navigation untouched.
class WebAppShell extends StatelessWidget {
  final Widget child;
  final Widget mobileChild;

  const WebAppShell({
    super.key,
    required this.child,
    required this.mobileChild,
  });

  @override
  Widget build(BuildContext context) {
    // If running on native mobile or small viewport, keep exact existing mobile UI.
    if (ResponsiveLayout.isMobile(context)) {
      return mobileChild;
    }

    final isTablet = ResponsiveLayout.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Left persistent sidebar
          WebSidebar(isCollapsed: isTablet),

          // Right main area
          Expanded(
            child: Column(
              children: [
                // Compact topbar
                const WebTopBar(),

                // Scrollable main page content
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
