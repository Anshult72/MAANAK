import 'package:flutter/material.dart';
import '../constants/app_brand.dart';

/// Reusable branding widget for the official LM-TRACE logo asset.
///
/// Features:
/// - Preserves strict 1:1 aspect ratio without stretching, squashing, distortion or blur.
/// - Supports compact mode (e.g. for collapsed sidebar, topbar, or mobile appbar).
/// - Supports full mode (for expanded sidebar, login screen, and about dialogs).
/// - Configurable dimensions, rounded corners, tooltips, and accessibility semantics.
/// - Handles loading gracefully with no duplicate asset path strings across screens.
class AppLogo extends StatelessWidget {
  /// Custom width constraint.
  final double? width;

  /// Custom height constraint.
  final double? height;

  /// Square size shortcut (sets both width and height to this value).
  final double? size;

  /// Whether to render in compact mode (appropriate for toolbars, collapsed sidebars, and badges).
  final bool compact;

  /// Optional custom tooltip or accessibility label.
  final String? tooltip;

  /// How the image should be inscribed into the box (defaults to BoxFit.contain).
  final BoxFit fit;

  /// Corner radius for the logo boundary (defaults to 10.0 for natural badge look).
  final BorderRadius? borderRadius;

  /// Optional hero tag for smooth transitions (e.g. between splash/login and dashboard).
  final String? heroTag;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.size,
    this.compact = false,
    this.tooltip,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.heroTag,
  });

  /// Factory for a compact 36px-44px icon brand mark.
  const AppLogo.compact({
    super.key,
    double? size,
    this.tooltip,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.heroTag,
  })  : compact = true,
        size = size ?? 40.0,
        width = null,
        height = null;

  /// Factory for a full brand mark with specified width/height.
  const AppLogo.full({
    super.key,
    this.width,
    this.height,
    this.size,
    this.tooltip,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.heroTag,
  }) : compact = false;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? (compact ? 40.0 : null);
    final effectiveWidth = width ?? effectiveSize;
    final effectiveHeight = height ?? effectiveSize;
    final effectiveTooltip = tooltip ?? AppBranding.semanticLabel;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(compact ? 8.0 : 12.0);

    Widget imageWidget = ClipRRect(
      borderRadius: effectiveRadius,
      child: Image.asset(
        AppBranding.logoAsset,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        semanticLabel: effectiveTooltip,
        errorBuilder: (context, error, stackTrace) {
          // Graceful fallback if asset path is momentarily reloading
          return Container(
            width: effectiveWidth ?? 40,
            height: effectiveHeight ?? 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0F2537),
              borderRadius: effectiveRadius,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.cyanAccent, size: 24),
          );
        },
      ),
    );

    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return Semantics(
      label: effectiveTooltip,
      image: true,
      child: Tooltip(
        message: effectiveTooltip,
        waitDuration: const Duration(milliseconds: 750),
        child: imageWidget,
      ),
    );
  }
}

/// Alias for [AppLogo] adhering to the specification.
typedef LMTraceLogo = AppLogo;
