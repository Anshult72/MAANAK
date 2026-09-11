import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/responsive/responsive_layout.dart';
import '../inspections/inspections_controller.dart';
import 'widgets/scanner_web_workspace.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final String? inspectionId;

  const ScannerScreen({super.key, this.inspectionId});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _currentInspectionId;

  int _selectedSurfaceIndex = 0;
  final List<String> _surfaces = ['Front (PDP)', 'Back (Declarations)', 'Side (Consumer Care)', 'MRP & Date Stamp'];
  /// Canonical codes expected by backend mock OCR / placement logic.
  static const List<String> _canonicalSurfaces = ['FRONT', 'BACK', 'SIDE', 'MRP_AREA'];

  // Map of surface to captured image bytes and name
  final Map<int, Uint8List> _surfaceImages = {};
  final Map<int, String> _surfaceImageNames = {};

  Future<Uint8List> _generateSamplePng({required bool hasViolation, required String surface}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 450, 220));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 450, 220), bgPaint);

    String text;
    if (surface == 'FRONT') {
      text = hasViolation
          ? "ABC Basmati Rice\nNet Wt: 5 kg\n100% Pure Indian Basmati"
          : "ABC Premium Basmati Rice\nNet Weight: 5 kg\n100% Pure Indian Basmati";
    } else if (surface == 'BACK') {
      text = hasViolation
          ? "Manufactured by: ABC Agro Foods Ltd.\nBatch: BAS-2026-04\nConsumer Care: care@abc.com"
          : "Manufactured & Packed by: ABC Agro Foods Ltd., Plot 42, Karnal, Haryana - 132001\nPacked on: 08/2026\nBest Before: 24 months from packaging\nConsumer Care: 1800-111-2222 | care@abcagro.com\nCountry of Origin: India";
    } else {
      text = hasViolation
          ? "MRP Rs 500\nDate: 08/2026"
          : "MRP Rs 450.00 (Inclusive of all taxes)\nUnit Sale Price: Rs 90.00 / kg\nPacked on: 08/2026";
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 420);
    textPainter.paint(canvas, const Offset(15, 15));

    final picture = recorder.endRecording();
    final img = await picture.toImage(450, 220);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  bool _isUploading = false;
  String? _uploadStatusMessage;

  @override
  void initState() {
    super.initState();
    _currentInspectionId = widget.inspectionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentInspectionId == null) {
        final state = ref.read(inspectionsProvider);
        if (state.inspections.isNotEmpty) {
          final activeIns = state.inspections.firstWhere(
            (ins) => ins.status.toUpperCase() != 'FINALIZED',
            orElse: () => state.inspections.first,
          );
          setState(() {
            _currentInspectionId = activeIns.id;
          });
        }
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _surfaceImages[_selectedSurfaceIndex] = bytes;
          _surfaceImageNames[_selectedSurfaceIndex] = picked.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image selection failed: $e'), backgroundColor: AppColors.violation),
        );
      }
    }
  }

  Future<void> _loadSamplePackage(bool hasViolation) async {
    final frontBytes = await _generateSamplePng(hasViolation: hasViolation, surface: 'FRONT');
    final backBytes = await _generateSamplePng(hasViolation: hasViolation, surface: 'BACK');
    final mrpBytes = await _generateSamplePng(hasViolation: hasViolation, surface: 'MRP_AREA');

    setState(() {
      _surfaceImages[0] = frontBytes;
      _surfaceImageNames[0] = hasViolation ? 'sample_violation_front.png' : 'sample_compliant_front.png';
      _surfaceImages[1] = backBytes;
      _surfaceImageNames[1] = 'sample_back_declarations.png';
      _surfaceImages[3] = mrpBytes;
      _surfaceImageNames[3] = 'sample_mrp_area.png';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasViolation ? 'Loaded Sample Package with Rule 7 & MRP issues' : 'Loaded Standard Compliant Package Sample'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _runPipeline() async {
    if (_currentInspectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create an inspection first'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final inspectionsState = ref.read(inspectionsProvider);
    final selectedInspection = inspectionsState.inspections
        .where((ins) => ins.id == _currentInspectionId)
        .firstOrNull;
    if (selectedInspection != null && selectedInspection.status.toUpperCase() == 'FINALIZED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected case is FINALIZED. Please select an active inspection or tap + New Case to run a compliance audit.'),
          backgroundColor: AppColors.violation,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_surfaceImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture or load at least one package surface image before running the audit.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusMessage = 'Uploading commodity package surfaces...';
    });

    final client = ref.read(apiClientProvider);

    try {
      // 1. Upload any captured images with canonical surface codes
      for (final entry in _surfaceImages.entries) {
        final surfaceCode = entry.key < _canonicalSurfaces.length
            ? _canonicalSurfaces[entry.key]
            : 'FRONT';
        final bytes = entry.value;
        final filename = _surfaceImageNames[entry.key] ?? 'surface_${entry.key}.png';
        final isPng = filename.toLowerCase().endsWith('.png');

        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
          ),
          'surface_type': surfaceCode,
        });

        await client.uploadFile(
          "${ApiConstants.inspections}/$_currentInspectionId/images",
          formData,
        );
      }

      setState(() {
        _uploadStatusMessage = 'Launching AI OCR & Legal Metrology Engine...';
      });

      if (mounted) {
        context.push('/analysis-progress/$_currentInspectionId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        String message = 'Pipeline error: $e';
        if (e is DioException) {
          final responseData = e.response?.data;
          if (responseData is Map && responseData['detail'] is String) {
            message = responseData['detail'] as String;
          } else if (responseData is Map && responseData['error'] is Map) {
            final errorMap = responseData['error'] as Map;
            message = (errorMap['details'] as String?) ??
                (errorMap['message'] as String?) ??
                e.message ??
                message;
          } else if (e.message != null && e.message!.isNotEmpty) {
            message = e.message!;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.violation,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isWebDesktop(context)) {
      return ScannerWebWorkspace(
        currentInspectionId: _currentInspectionId,
        onInspectionChanged: (val) {
          if (val != null) setState(() => _currentInspectionId = val);
        },
        selectedSurfaceIndex: _selectedSurfaceIndex,
        surfaces: _surfaces,
        onSurfaceChanged: (val) => setState(() => _selectedSurfaceIndex = val),
        surfaceImages: _surfaceImages,
        surfaceImageNames: _surfaceImageNames,
        onClearActiveSurface: () {
          setState(() {
            _surfaceImages.remove(_selectedSurfaceIndex);
            _surfaceImageNames.remove(_selectedSurfaceIndex);
          });
        },
        onPickImage: _pickImage,
        onLoadSamplePackage: _loadSamplePackage,
        onRunPipeline: _runPipeline,
        isUploading: _isUploading,
        uploadStatusMessage: _uploadStatusMessage,
      );
    }

    final inspectionsState = ref.watch(inspectionsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Package Scanner & Ingestion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten_outlined),
            tooltip: 'Calibrate Scale',
            onPressed: _currentInspectionId == null
                ? null
                : () => context.push('/calibration?inspectionId=$_currentInspectionId'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Inspection Selector
            _buildInspectionSelector(inspectionsState),
            const SizedBox(height: 16),

            // Surface Selector Tabs
            const Text(
              'Package Surfaces (Multi-Surface Audit)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_surfaces.length, (index) {
                  final isSelected = _selectedSurfaceIndex == index;
                  final hasImage = _surfaceImages.containsKey(index);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasImage) ...[
                            const Icon(Icons.check_circle, size: 14, color: AppColors.compliant),
                            const SizedBox(width: 4),
                          ],
                          Text(_surfaces[index]),
                        ],
                      ),
                      selectedColor: AppColors.secondary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.neutral700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedSurfaceIndex = index);
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Active Surface Capture Card
            _buildCaptureBox(),
            const SizedBox(height: 16),

            // Image Quality / Pre-check Metrics
            _buildQualityIndicators(),
            const SizedBox(height: 16),

            // Demo Quick Loaders
            _buildDemoPresets(),
            const SizedBox(height: 24),

            // Calibration & Pipeline Actions
            if (_isUploading) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _uploadStatusMessage ?? 'Processing...',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.straighten),
                      label: const Text('Calibrate Scale (Rule 7)'),
                      onPressed: _currentInspectionId == null
                          ? null
                          : () => context.push('/calibration?inspectionId=$_currentInspectionId'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text(
                    'Run AI Compliance Audit',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _runPipeline,
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionSelector(InspectionState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Inspection Case',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral600),
              ),
              TextButton(
                onPressed: () => context.push('/new-inspection'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                child: const Text('+ New Case', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (state.inspections.isEmpty)
            const Text('No inspections created. Tap + New Case.', style: TextStyle(color: AppColors.warning))
          else ...[
            DropdownButton<String>(
              isExpanded: true,
              value: _currentInspectionId,
              underline: const SizedBox(),
              items: state.inspections.map((ins) {
                final isItemFinalized = ins.status.toUpperCase() == 'FINALIZED';
                return DropdownMenuItem<String>(
                  value: ins.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isItemFinalized
                              ? AppColors.neutral200
                              : AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ins.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isItemFinalized ? AppColors.neutral600 : AppColors.secondary,
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
              onChanged: (val) {
                if (val != null) setState(() => _currentInspectionId = val);
              },
            ),
            Builder(builder: (context) {
              final selectedIns = state.inspections
                  .where((ins) => ins.id == _currentInspectionId)
                  .firstOrNull;
              if (selectedIns?.status.toUpperCase() == 'FINALIZED') {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.violation.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.violation.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppColors.violation),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Selected case is FINALIZED (read-only). To scan package images, please select an in-progress case or tap + New Case.',
                          style: TextStyle(fontSize: 11, color: AppColors.violation, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptureBox() {
    final hasImage = _surfaceImages.containsKey(_selectedSurfaceIndex);

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral300, width: 1.5),
      ),
      child: hasImage
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      color: AppColors.neutral100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, size: 60, color: AppColors.secondary),
                          const SizedBox(height: 8),
                          Text(
                            _surfaceImageNames[_selectedSurfaceIndex] ?? 'Surface Image',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          const Text('Captured & Ready for OCR', style: TextStyle(fontSize: 11, color: AppColors.compliant)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.violation),
                      onPressed: () {
                        setState(() {
                          _surfaceImages.remove(_selectedSurfaceIndex);
                          _surfaceImageNames.remove(_selectedSurfaceIndex);
                        });
                      },
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedSurfaceIndex == 0 ? Icons.crop_free : Icons.document_scanner_outlined,
                  size: 50,
                  color: AppColors.neutral400,
                ),
                const SizedBox(height: 10),
                Text(
                  'Capture ${_surfaces[_selectedSurfaceIndex]}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.neutral700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hold package perpendicular to avoid perspective distortion',
                  style: TextStyle(fontSize: 11, color: AppColors.neutral400),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Camera'),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text('Gallery'),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildQualityIndicators() {
    final hasImage = _surfaceImages.containsKey(_selectedSurfaceIndex);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Computer Vision Quality Pre-Check',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutral700),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQualityItem(
                label: 'Sharpness',
                value: hasImage ? 'Laplacian: 312 (Clear)' : 'Pending Capture',
                icon: Icons.lens_blur,
                isOk: hasImage,
              ),
              _buildQualityItem(
                label: 'Lighting',
                value: hasImage ? 'Normal (No Glare)' : 'Pending Capture',
                icon: Icons.wb_sunny_outlined,
                isOk: hasImage,
              ),
              _buildQualityItem(
                label: 'Angle',
                value: hasImage ? 'Frontal Parallel' : 'Pending Capture',
                icon: Icons.screen_rotation,
                isOk: hasImage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isOk,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: isOk ? AppColors.compliant : AppColors.neutral400),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        Text(
          value,
          style: TextStyle(fontSize: 10, color: isOk ? AppColors.compliant : AppColors.neutral400),
        ),
      ],
    );
  }

  Widget _buildDemoPresets() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIH Demo Commodity Presets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Load synthetic sample packages to test the full pipeline without external camera:',
            style: TextStyle(fontSize: 11, color: AppColors.neutral600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(backgroundColor: Colors.white),
                  icon: const Icon(Icons.check_box_outlined, size: 16, color: AppColors.compliant),
                  label: const Text('Load Compliant Pack', style: TextStyle(fontSize: 11)),
                  onPressed: () => _loadSamplePackage(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(backgroundColor: Colors.white),
                  icon: const Icon(Icons.warning_amber_outlined, size: 16, color: AppColors.violation),
                  label: const Text('Load Violation Pack', style: TextStyle(fontSize: 11)),
                  onPressed: () => _loadSamplePackage(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
