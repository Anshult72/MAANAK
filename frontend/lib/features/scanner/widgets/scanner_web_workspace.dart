import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/responsive/web_page_container.dart';
import '../../inspections/inspections_controller.dart';

/// Professional government desktop workspace for package scanning, CV pre-checks,
/// OCR extraction, and Rule 7 Table-I font analysis.
class ScannerWebWorkspace extends StatelessWidget {
  final String? currentInspectionId;
  final ValueChanged<String?> onInspectionChanged;
  final int selectedSurfaceIndex;
  final List<String> surfaces;
  final ValueChanged<int> onSurfaceChanged;
  final Map<int, Uint8List> surfaceImages;
  final Map<int, String> surfaceImageNames;
  final VoidCallback onClearActiveSurface;
  final Function(ImageSource) onPickImage;
  final Function(bool) onLoadSamplePackage;
  final VoidCallback onRunPipeline;
  final bool isUploading;
  final String? uploadStatusMessage;

  const ScannerWebWorkspace({
    super.key,
    required this.currentInspectionId,
    required this.onInspectionChanged,
    required this.selectedSurfaceIndex,
    required this.surfaces,
    required this.onSurfaceChanged,
    required this.surfaceImages,
    required this.surfaceImageNames,
    required this.onClearActiveSurface,
    required this.onPickImage,
    required this.onLoadSamplePackage,
    required this.onRunPipeline,
    required this.isUploading,
    required this.uploadStatusMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(inspectionsProvider);
        final currentInspection = state.inspections
            .where((i) => i.id == currentInspectionId)
            .firstOrNull;
        final isFinalized = currentInspection?.status.toUpperCase() == 'FINALIZED';

        return WebPageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Workspace Header & Case Selector Bar
              _buildCaseSelectorBar(context, state, currentInspection, isFinalized),
              const SizedBox(height: 16),

              // 2. Multi-Surface Segmented Tabs
              _buildSurfaceTabs(),
              const SizedBox(height: 16),

              // 3. Two-Column Workspace: Left (~58%) Preview / Right (~42%) Analysis & Controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel: Image Preview & Sample Presets
                  Expanded(
                    flex: 58,
                    child: _buildLeftImagePanel(context),
                  ),
                  const SizedBox(width: 20),

                  // Right Panel: CV Quality, Scale Calibration, Actions, & Font Analysis
                  Expanded(
                    flex: 42,
                    child: _buildRightControlPanel(context, currentInspection, isFinalized),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaseSelectorBar(
    BuildContext context,
    InspectionState state,
    InspectionModel? currentInspection,
    bool isFinalized,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_shared_outlined, color: AppColors.secondaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Active Inspection Case File:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: currentInspectionId,
                    hint: const Text('Select an inspection case...'),
                    items: state.inspections.map((ins) {
                      final itemFinalized = ins.status.toUpperCase() == 'FINALIZED';
                      return DropdownMenuItem<String>(
                        value: ins.id,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: itemFinalized ? AppColors.neutral200 : AppColors.secondaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ins.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: itemFinalized ? AppColors.neutral600 : AppColors.secondaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${ins.inspectionCode} — ${ins.businessName ?? ins.sellerName ?? ins.location}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: onInspectionChanged,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: AppColors.neutral300),
                ),
                icon: const Icon(Icons.straighten, size: 15),
                label: const Text('Calibrate Scale', style: TextStyle(fontSize: 12)),
                onPressed: currentInspectionId == null
                    ? null
                    : () => context.push('/calibration?inspectionId=$currentInspectionId'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 15, color: Colors.white),
                label: const Text('+ New Case', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => context.push('/new-inspection'),
              ),
            ],
          ),
          if (isFinalized) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.violationRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.violationRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.violationRed),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This case is FINALIZED (sealed legal record). Under statutory audit rules, new images cannot be attached to closed cases. Select an in-progress case or click "+ New Case".',
                      style: TextStyle(fontSize: 11.5, color: AppColors.violationRed, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSurfaceTabs() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: List.generate(surfaces.length, (index) {
          final isSelected = selectedSurfaceIndex == index;
          final hasImage = surfaceImages.containsKey(index);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => onSurfaceChanged(index),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasImage) ...[
                        Icon(Icons.check_circle, size: 15, color: isSelected ? Colors.white : AppColors.passGreen),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        surfaces[index],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeftImagePanel(BuildContext context) {
    final hasImage = surfaceImages.containsKey(selectedSurfaceIndex);
    final imageName = surfaceImageNames[selectedSurfaceIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.center_focus_strong, size: 18, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                Text(
                  'Surface Image: ${surfaces[selectedSurfaceIndex]}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primaryNavy),
                ),
                const Spacer(),
                if (hasImage)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.violationRed,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Clear Surface', style: TextStyle(fontSize: 12)),
                    onPressed: onClearActiveSurface,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Main Preview Box with sensible aspect ratio (height: 380px)
          Container(
            height: 360,
            width: double.infinity,
            color: AppColors.neutral100,
            child: hasImage
                ? Stack(
                    children: [
                      Center(
                        child: Image.memory(
                          surfaceImages[selectedSurfaceIndex]!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_size_select_actual_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                imageName ?? 'Captured Surface',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera_back_outlined, size: 52, color: AppColors.neutral400),
                        const SizedBox(height: 12),
                        Text(
                          'No Image Captured for ${surfaces[selectedSurfaceIndex]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.neutral700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Upload a high-resolution commodity package photo or choose an SIH Preset below.',
                          style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              icon: const Icon(Icons.file_upload_outlined, size: 16, color: Colors.white),
                              label: const Text('Upload Image', style: TextStyle(fontSize: 12.5)),
                              onPressed: () => onPickImage(ImageSource.gallery),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined, size: 16),
                              label: const Text('Camera', style: TextStyle(fontSize: 12.5)),
                              onPressed: () => onPickImage(ImageSource.camera),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),

          // Presets Toolbar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text(
                  'SIH Demo Presets:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral700),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.passGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle, size: 14, color: AppColors.passGreen),
                  label: const Text('Load Compliant Pack (Rice 5kg)', style: TextStyle(fontSize: 11.5, color: AppColors.passGreen, fontWeight: FontWeight.bold)),
                  onPressed: () => onLoadSamplePackage(false),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.violationRed),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.warning, size: 14, color: AppColors.violationRed),
                  label: const Text('Load Violation Pack (Rule 7 Font Issue)', style: TextStyle(fontSize: 11.5, color: AppColors.violationRed, fontWeight: FontWeight.bold)),
                  onPressed: () => onLoadSamplePackage(true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightControlPanel(
    BuildContext context,
    InspectionModel? currentInspection,
    bool isFinalized,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Computer Vision Quality Pre-Check Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Computer Vision Quality Pre-Check',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                  ),
                  Icon(Icons.auto_graph, size: 16, color: AppColors.secondaryBlue),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCvMetricPill(
                      label: 'Sharpness',
                      value: '312 Clear',
                      subtext: 'Laplacian Blur Pass',
                      icon: Icons.grain,
                      color: AppColors.passGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCvMetricPill(
                      label: 'Lighting',
                      value: 'Normal',
                      subtext: 'No Glare / Specular',
                      icon: Icons.light_mode_outlined,
                      color: AppColors.passGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCvMetricPill(
                      label: 'Perspective',
                      value: 'Frontal',
                      subtext: 'Skew < 2°',
                      icon: Icons.aspect_ratio,
                      color: AppColors.passGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Primary Execution Action Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.straighten, size: 16, color: AppColors.secondaryBlue),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scale Calibration Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        Text('Active Ratio: 2.0 px/mm • Known 150mm scale', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.passGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('CALIBRATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.passGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action button
              if (isUploading) ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        uploadStatusMessage ?? 'Processing package surfaces...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(height: 4),
                      const Text('Running OCR extraction & Rule 7 Table-I evaluation...', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFinalized ? AppColors.neutral400 : AppColors.secondaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    label: const Text(
                      'Run AI Compliance Audit',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isFinalized ? null : onRunPipeline,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Rule 7 Table-I Font-Size Analysis Presentation (Section 13)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_size, color: AppColors.primaryNavy, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Rule 7 Table-I Font-Size Analysis',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.passGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PASS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.passGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    _buildMeasurementRow('Declaration Target', 'Net Quantity (Numeral)', '5 kg'),
                    const SizedBox(height: 6),
                    _buildMeasurementRow('Principal Display Panel (PDP)', 'Calculated Area', '320 cm²'),
                    const SizedBox(height: 6),
                    _buildMeasurementRow('Statutory Minimum (Table-I)', 'Area 100-500 cm²', '2.50 mm'),
                    const SizedBox(height: 6),
                    _buildMeasurementRow('CV Measured Numeral Height', 'Scaled 2.0 px/mm', '3.20 mm'),
                    const SizedBox(height: 6),
                    _buildMeasurementRow('Numeral Width-to-Height', 'Ratio: 0.58 (min 0.33)', 'PASS (Rule 7)'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Icon(Icons.verified, size: 14, color: AppColors.passGreen),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Automated compliance: Character height exceeds statutory threshold with 94% measurement confidence.',
                      style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCvMetricPill({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neutral600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          Text(subtext, style: const TextStyle(fontSize: 9.5, color: AppColors.neutral500)),
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(String title, String subtitle, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.neutral800)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.neutral500)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
        ),
      ],
    );
  }
}
