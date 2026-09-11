import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'responsive_layout.dart';

/// Standard container for desktop and tablet web pages.
/// Enforces maximum width constraint (1440px), centers content on ultra-wide screens,
/// and applies consistent institutional spacing and background.
class WebPageContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final bool scrollable;

  const WebPageContainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding,
    this.scrollController,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktopTier = ResponsiveLayout.isDesktop(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: isDesktopTier ? 28.0 : 20.0,
          vertical: isDesktopTier ? 24.0 : 16.0,
        );

    final constrainedContent = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );

    if (!scrollable) {
      return Container(
        color: AppColors.neutral50,
        width: double.infinity,
        height: double.infinity,
        child: constrainedContent,
      );
    }

    return Container(
      color: AppColors.neutral50,
      width: double.infinity,
      height: double.infinity,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: constrainedContent,
        ),
      ),
    );
  }
}
