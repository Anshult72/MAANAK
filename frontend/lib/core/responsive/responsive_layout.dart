import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Standard breakpoint thresholds for LM-TRACE enterprise web/desktop layouts.
class Breakpoints {
  /// Width threshold for desktop multi-column layouts (>= 1200px)
  static const double desktop = 1200.0;

  /// Width threshold for tablet layout (768px <= width < 1200px)
  static const double tablet = 768.0;

  /// Maximum container width for desktop web content
  static const double maxContentWidth = 1440.0;

  /// Standard sidebar width
  static const double sidebarWidth = 250.0;

  /// Collapsed icon-only sidebar width for tablet
  static const double collapsedSidebarWidth = 72.0;

  /// Standard top header height
  static const double topBarHeight = 64.0;
}

/// Helper methods to determine current platform and responsive tier.
class ResponsiveLayout {
  /// Returns true if running on Web and the viewport width is desktop tier (>= 1200px),
  /// or running on desktop operating systems (Windows, macOS, Linux).
  static bool isDesktop(BuildContext context) {
    if (isNativeMobile) return false;
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.desktop;
  }

  /// Returns true if running on Web and the viewport width is tablet tier (768px <= width < 1200px).
  static bool isTablet(BuildContext context) {
    if (isNativeMobile) return false;
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.tablet && width < Breakpoints.desktop;
  }

  /// Returns true if running on mobile screen width (< 768px) or native mobile app.
  static bool isMobile(BuildContext context) {
    if (isNativeMobile) return true;
    final width = MediaQuery.sizeOf(context).width;
    return width < Breakpoints.tablet;
  }

  /// Returns true if the screen should show the desktop/tablet web layout (width >= 768px on Web/desktop).
  static bool isWebDesktop(BuildContext context) {
    if (isNativeMobile) return false;
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.tablet;
  }

  /// True ONLY if running natively on an Android or iOS device (not Web).
  static bool get isNativeMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
}

/// Responsive builder widget that renders appropriate UI based on current screen size.
class ResponsiveBuilder extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context)) {
      return desktop(context);
    } else if (ResponsiveLayout.isTablet(context) && tablet != null) {
      return tablet!(context);
    } else if (ResponsiveLayout.isTablet(context)) {
      return desktop(context);
    } else {
      return mobile(context);
    }
  }
}
