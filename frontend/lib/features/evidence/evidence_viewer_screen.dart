import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../inspections/inspections_controller.dart';

class EvidenceViewerScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const EvidenceViewerScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<EvidenceViewerScreen> createState() => _EvidenceViewerScreenState();
}

class _EvidenceViewerScreenState extends ConsumerState<EvidenceViewerScreen> {
  int _selectedImageIndex = 0;
  int _selectedEvidenceIndex = 0;
  bool _viewCloudEvidence = false;
  bool _showOverlays = true;
  String? _selectedFindingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(inspectionsProvider).selectedInspection;
      if (current == null || current.id != widget.inspectionId) {
        ref.read(inspectionsProvider.notifier).fetchInspectionDetail(widget.inspectionId);
      }
      ref.read(inspectionsProvider.notifier).fetchEvidence(widget.inspectionId);
    });
  }

  void _showConfirmDialog(String findingId) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Regulatory Finding"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to confirm this finding as a non-compliance observation?",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: "Inspector Physical Verification Remarks",
                hintText: "Enter observation details...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.violationRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(inspectionsProvider.notifier).confirmFinding(
                findingId,
                comment: commentController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✓ Finding confirmed by inspector.")),
                );
              }
            },
            child: const Text("Confirm Finding"),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String findingId) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Dismiss Finding"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dismiss this finding after physical verification?", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: "Reason for Dismissal",
                hintText: "e.g. Verified on alternate surface...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(inspectionsProvider.notifier).rejectFinding(
                findingId,
                comment: commentController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Finding dismissed by inspector.")),
                );
              }
            },
            child: const Text("Dismiss Finding"),
          ),
        ],
      ),
    );
  }

  void _showAddManualFindingDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Record Manual Inspector Observation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Observation Title")),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description & Details")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(inspectionsProvider.notifier).addManualFinding(
                  widget.inspectionId,
                  title: titleCtrl.text,
                  description: descCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✓ Manual finding recorded (INSPECTOR_ADDED).")),
                  );
                }
              }
            },
            child: const Text("Add Observation"),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(dynamic name) {
    if (name == null) return 'Declaration';
    final s = name.toString().replaceAll('_', ' ');
    return s.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  Widget _buildImageWidget(Map<String, dynamic> img) {
    // 1. Try base64 direct decode (highest reliability & offline resilience)
    final qualityDetails = img['quality_details'] as Map<String, dynamic>?;
    final b64 = qualityDetails?['_image_b64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildNetworkImage(img),
        );
      } catch (_) {
        // Fallback to network
      }
    }

    return _buildNetworkImage(img);
  }

  Widget _buildNetworkImage(Map<String, dynamic> img) {
    final imgId = img['id']?.toString() ?? '';
    final primaryUrl = "${ApiConstants.baseUrl}/api/inspections/${widget.inspectionId}/images/$imgId";

    return Image.network(
      primaryUrl,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, stack) {
        // Fallback to static storage path
        final origPath = img['original_path']?.toString().replaceAll(RegExp(r'^[/\\]*'), '') ?? '';
        final cleanRel = origPath.replaceFirst(RegExp(r'^storage[/\\\\]?'), '');
        final storageUrl = "${ApiConstants.baseUrl}/storage/$cleanRel";

        return Image.network(
          storageUrl,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => _buildPlaceholderGraphic(img['surface_type']),
        );
      },
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryBlue),
        );
      },
    );
  }

  Widget _buildPlaceholderGraphic(dynamic surfaceType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white38),
          const SizedBox(height: 10),
          Text(
            "Package Surface: ${surfaceType ?? 'FRONT'}",
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudinaryEvidenceWidget(EvidenceModel ev) {
    final secureUrl = ev.cloudinarySecureUrl;
    if (secureUrl != null && secureUrl.isNotEmpty) {
      return Image.network(
        secureUrl,
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryBlue),
                SizedBox(height: 12),
                Text(
                  "Loading evidence from secure cloud...",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          );
        },
        errorBuilder: (ctx, err, stack) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.violationRed),
                  const SizedBox(height: 10),
                  const Text(
                    "Unable to load evidence image",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "The persistent cloud asset could not be retrieved.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      ref.read(inspectionsProvider.notifier).retryEvidenceUpload(widget.inspectionId, ev.id);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("Retry Cloud Archival", style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ev.status == 'UPLOAD_FAILED' ? Icons.cloud_off : Icons.image_search,
            size: 48,
            color: Colors.white38,
          ),
          const SizedBox(height: 10),
          Text(
            ev.status == 'UPLOAD_FAILED'
                ? "Evidence archive failed"
                : (ev.status == 'LOCAL_ONLY' ? "Local Preprocessed Crop" : "Evidence is being securely archived..."),
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          if (ev.description != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                ev.description!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
          if (ev.status == 'UPLOAD_FAILED') ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.reviewAmber,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: () {
                ref.read(inspectionsProvider.notifier).retryEvidenceUpload(widget.inspectionId, ev.id);
              },
              icon: const Icon(Icons.cloud_upload, size: 14),
              label: const Text("Retry Upload", style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspectionState = ref.watch(inspectionsProvider);
    final inspection = inspectionState.selectedInspection;

    final rawImages = inspection?.images ?? [];
    final images = rawImages.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

    final evidenceItems = inspection?.evidenceItems ?? [];

    final rawViolations = inspection?.violations ?? [];
    final violations = rawViolations.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

    final rawDeclarations = inspection?.declarations ?? [];
    final declarations = rawDeclarations.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

    // Clamp safe image index
    final safeIndex = images.isNotEmpty ? _selectedImageIndex.clamp(0, images.length - 1) : 0;
    final currentImg = images.isNotEmpty ? images[safeIndex] : null;

    final safeEvIndex = evidenceItems.isNotEmpty ? _selectedEvidenceIndex.clamp(0, evidenceItems.length - 1) : 0;
    final currentEv = evidenceItems.isNotEmpty ? evidenceItems[safeEvIndex] : null;

    // Filter declarations relevant to the current surface/image
    final currentImgId = currentImg?['id']?.toString();
    final surfaceType = currentImg?['surface_type']?.toString().toUpperCase();

    final relevantDecls = declarations.where((d) {
      final srcImgId = d['source_image_id']?.toString();
      if (srcImgId != null && currentImgId != null && srcImgId == currentImgId) return true;
      // If no image ID match or single image, show declarations on front
      return surfaceType == null || surfaceType == 'FRONT';
    }).toList();

    final detectedDecls = (relevantDecls.isNotEmpty ? relevantDecls : declarations)
        .where((d) => d['presence_status'] == 'DETECTED' || d['verified_value'] != null || d['ai_value'] != null)
        .toList();

    final missingDecls = declarations
        .where((d) => d['presence_status'] == 'MISSING')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Visual Evidence & Overlays"),
        actions: [
          IconButton(
            icon: Icon(_showOverlays ? Icons.visibility : Icons.visibility_off),
            tooltip: "Toggle Overlays",
            onPressed: () => setState(() => _showOverlays = !_showOverlays),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: "Add Manual Finding",
            onPressed: _showAddManualFindingDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Toggle Selector: Full Package Photos vs Cloud Evidence Crops
          if (evidenceItems.isNotEmpty)
            Container(
              color: const Color(0xFF0B1120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text("Evidence Crops & Overlays (${evidenceItems.length})"),
                    selected: _viewCloudEvidence,
                    selectedColor: AppColors.secondaryBlue,
                    labelStyle: TextStyle(
                      color: _viewCloudEvidence ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: _viewCloudEvidence ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    onSelected: (val) {
                      if (val) setState(() => _viewCloudEvidence = true);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text("Full Package Photos (${images.length})"),
                    selected: !_viewCloudEvidence,
                    selectedColor: AppColors.secondaryBlue,
                    labelStyle: TextStyle(
                      color: !_viewCloudEvidence ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: !_viewCloudEvidence ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    onSelected: (val) {
                      if (val) setState(() => _viewCloudEvidence = false);
                    },
                  ),
                ],
              ),
            ),

          // Evidence / Surface Selector Bar
          if (_viewCloudEvidence && evidenceItems.isNotEmpty)
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(evidenceItems.length, (idx) {
                    final ev = evidenceItems[idx];
                    final isSelected = idx == safeEvIndex;
                    final label = ev.evidenceType.replaceAll('_', ' ');
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          ev.evidenceType == 'ANNOTATED_OVERLAY'
                              ? Icons.layers
                              : (ev.evidenceType == 'VIOLATION_EVIDENCE'
                                  ? Icons.warning_amber
                                  : Icons.crop_free),
                          size: 14,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.secondaryBlue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: const Color(0xFF1E293B),
                        onSelected: (val) {
                          if (val) setState(() => _selectedEvidenceIndex = idx);
                        },
                      ),
                    );
                  }),
                ),
              ),
            )
          else if (images.length > 1)
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(images.length, (idx) {
                    final img = images[idx];
                    final surface = img['surface_type']?.toString() ?? 'SURFACE ${idx + 1}';
                    final isSelected = idx == safeIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(surface),
                        selected: isSelected,
                        selectedColor: AppColors.secondaryBlue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: const Color(0xFF1E293B),
                        onSelected: (val) {
                          if (val) setState(() => _selectedImageIndex = idx);
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),

          // Visual Evidence Canvas Area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF0F172A),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Container(
                    width: 340,
                    height: 440,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Display either Cloud Evidence Crop or Package Photo
                        if (_viewCloudEvidence && currentEv != null)
                          _buildCloudinaryEvidenceWidget(currentEv)
                        else if (currentImg != null)
                          _buildImageWidget(currentImg)
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_camera_back_outlined, size: 64, color: Colors.white30),
                                const SizedBox(height: 12),
                                Text(
                                  inspection?.packageType ?? "Packaged Commodity",
                                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "No photos captured yet for this inspection.",
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                        // If viewing Cloud Evidence: Overlay SHA-256 and metadata badges at bottom
                        if (_viewCloudEvidence && currentEv != null)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          currentEv.evidenceType.replaceAll('_', ' '),
                                          style: const TextStyle(
                                            color: Color(0xFF93C5FD),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: currentEv.status == 'STORED'
                                              ? AppColors.passGreen.withValues(alpha: 0.3)
                                              : (currentEv.status == 'UPLOAD_FAILED'
                                                  ? AppColors.violationRed.withValues(alpha: 0.3)
                                                  : AppColors.reviewAmber.withValues(alpha: 0.3)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          currentEv.status,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: currentEv.status == 'STORED'
                                                ? AppColors.passGreen
                                                : (currentEv.status == 'UPLOAD_FAILED'
                                                    ? AppColors.violationRed
                                                    : AppColors.reviewAmber),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (currentEv.sha256 != null) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.lock_outline, size: 10, color: Colors.white70),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            "SHA-256: ${currentEv.sha256!.substring(0, 16)}...",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9.5,
                                              fontFamily: 'monospace',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                        // Real Dynamic Overlays & Annotations
                        if (_showOverlays) ...[
                          // Dynamic overlays generated from real inspection declarations
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Missing declarations alert banner (if any)
                                if (missingDecls.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.violationRed.withValues(alpha: 0.90),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white54),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.error_outline, size: 13, color: Colors.white),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            "MISSING: ${missingDecls.map((m) => _formatFieldName(m['field_name'])).join(', ')}",
                                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Detected declarations floating HUD chips
                                ...detectedDecls.take(4).map((d) {
                                  final fieldName = d['field_name']?.toString() ?? 'item';
                                  final val = d['verified_value'] ?? d['ai_value'] ?? '';

                                  final hasViol = violations.any((v) =>
                                      (v['field'] == fieldName ||
                                          v['type']?.toString().toLowerCase().contains(fieldName.toLowerCase()) == true) &&
                                      v['status'] != 'REJECTED');

                                  final isReview = d['correctness_status'] == 'REVIEW';

                                  final Color boxColor = hasViol
                                      ? AppColors.violationRed
                                      : (isReview ? AppColors.reviewAmber : AppColors.passGreen);

                                  final String statusText = hasViol ? 'VIOLATION' : (isReview ? 'REVIEW' : 'PASS');
                                  final String iconSymbol = hasViol ? '⚠' : (isReview ? '⚡' : '✓');

                                  final isSelected = _selectedFindingId != null &&
                                      violations.any((v) => v['id'] == _selectedFindingId &&
                                          (v['field'] == fieldName || v['type']?.toString().toLowerCase().contains(fieldName.toLowerCase()) == true));

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.78),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? Colors.white : boxColor,
                                        width: isSelected ? 2.5 : 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "$iconSymbol ${_formatFieldName(fieldName)}: ",
                                          style: TextStyle(
                                            color: boxColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            val.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "($statusText)",
                                          style: TextStyle(
                                            color: boxColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          // Surface indicator badge at bottom right
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                surfaceType ?? "SURFACE",
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Findings & Inspector Action Drawer
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Findings & Observations (${violations.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
                        ),
                        TextButton.icon(
                          onPressed: _showAddManualFindingDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Manual Finding", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: violations.isEmpty
                        ? const Center(
                            child: Text(
                              "No potential violations identified.\nAll verified declarations satisfy applicable rules.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: violations.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final viol = violations[idx];
                              final isConfirmed = viol['status'] == 'CONFIRMED';
                              final isRejected = viol['status'] == 'REJECTED';
                              final isSelected = viol['id'] == _selectedFindingId;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedFindingId = isSelected ? null : viol['id'];
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primaryNavy : Colors.transparent,
                                      width: isSelected ? 1.5 : 0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                viol['type'] ?? 'Finding',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isConfirmed
                                                    ? AppColors.violationRedLight
                                                    : (isRejected ? AppColors.passGreenLight : AppColors.reviewAmberLight),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                viol['status'] ?? 'AI_DETECTED',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isConfirmed
                                                      ? AppColors.violationRed
                                                      : (isRejected ? AppColors.passGreen : AppColors.reviewAmber),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          viol['ai_explanation'] ?? 'Requires physical verification.',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                                        ),
                                        if (viol['inspector_comment'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "Inspector Note: ${viol['inspector_comment']}",
                                            style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                textStyle: const TextStyle(fontSize: 11),
                                              ),
                                              onPressed: () => _showRejectDialog(viol['id']),
                                              child: const Text("Dismiss"),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.violationRed,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                textStyle: const TextStyle(fontSize: 11),
                                              ),
                                              onPressed: () => _showConfirmDialog(viol['id']),
                                              child: const Text("Confirm"),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
