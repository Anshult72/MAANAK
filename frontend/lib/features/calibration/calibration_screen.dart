import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../inspections/inspections_controller.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const CalibrationScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  final Offset _point1 = const Offset(80, 240);
  Offset? _point2 = const Offset(280, 240);
  final _distanceController = TextEditingController(text: "100.0");
  String _packageConstruction = "NORMAL";
  double _pdpArea = 320.0;

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  double get _derivedPxPerMm {
    if (_point2 == null) return 2.0;
    final dx = _point2!.dx - _point1.dx;
    final dy = _point2!.dy - _point1.dy;
    final distPx = sqrt(dx * dx + dy * dy);
    final knownMm = double.tryParse(_distanceController.text) ?? 100.0;
    if (knownMm <= 0) return 2.0;
    return distPx / knownMm;
  }

  double get _resolvedMinHeight {
    final isBlown = _packageConstruction == "BLOWN_FORMED_MOLDED";
    if (_pdpArea <= 50) return isBlown ? 2.0 : 1.0;
    if (_pdpArea <= 100) return isBlown ? 3.0 : 1.5;
    if (_pdpArea <= 500) return isBlown ? 4.0 : 2.5; // strictly 2.5 mm
    if (_pdpArea <= 2500) return isBlown ? 6.0 : 4.0;
    return 6.0;
  }

  Future<void> _saveCalibration() async {
    final pxPerMm = _derivedPxPerMm;
    final knownMm = double.tryParse(_distanceController.text) ?? 100.0;

    await ref.read(inspectionsProvider.notifier).updateCalibration(
      inspectionId: widget.inspectionId,
      pxPerMm: pxPerMm,
      knownDistanceMm: knownMm,
      pt1: {'x': _point1.dx, 'y': _point1.dy},
      pt2: {'x': _point2?.dx ?? 0, 'y': _point2?.dy ?? 0},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✓ Measurement calibration applied successfully."),
          backgroundColor: AppColors.passGreen,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calibrate Measurement Scale"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Regulatory Warning & Plane Guidance Box (Rule 5 requirement)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.reviewAmberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.reviewAmber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.reviewAmber, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Physical dimensions cannot be reliably inferred from pixels alone.\n"
                      "Place/select the measurement reference on the same package surface and approximately the same depth/plane as the declaration to reduce perspective error.",
                      style: TextStyle(fontSize: 12.5, color: AppColors.textDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Interactive 2-point canvas representation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Calibration Reference (Points A & B):",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _point2 = details.localPosition;
                        });
                      },
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: CustomPaint(
                          painter: _CalibrationPainter(
                            point1: _point1,
                            point2: _point2,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "Tap to reposition Point B on known edge",
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _distanceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Known Physical Distance (mm)",
                              suffixText: "mm",
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.lightNeutral,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Derived Scale:", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              Text(
                                "${_derivedPxPerMm.toStringAsFixed(2)} px/mm",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rule 7 Context Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Principal Display Panel (PDP) Context:",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _packageConstruction,
                            decoration: const InputDecoration(labelText: "Package Construction"),
                            items: const [
                              DropdownMenuItem(value: "NORMAL", child: Text("Normal Packaging")),
                              DropdownMenuItem(value: "BLOWN_FORMED_MOLDED", child: Text("Blown / Formed / Molded")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _packageConstruction = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _pdpArea.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "PDP Area (cm²)", suffixText: "cm²"),
                            onChanged: (val) {
                              final parsed = double.tryParse(val);
                              if (parsed != null && parsed > 0) setState(() => _pdpArea = parsed);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.passGreenLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.passGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gavel, color: AppColors.passGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Rule 7 Table-I Standard: Minimum $_resolvedMinHeight mm character height required.",
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.passGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveCalibration,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Apply Scale Calibration"),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationPainter extends CustomPainter {
  final Offset? point1;
  final Offset? point2;

  _CalibrationPainter({this.point1, this.point2});

  @override
  void paint(Canvas canvas, Size size) {
    if (point1 == null || point2 == null) return;

    final linePaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // Draw reference line
    canvas.drawLine(point1!, point2!, linePaint);

    // Draw endpoint markers
    canvas.drawCircle(point1!, 6, pointPaint);
    canvas.drawCircle(point2!, 6, pointPaint);

    // Draw labels
    final tpA = TextPainter(
      text: const TextSpan(text: "A", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpA.paint(canvas, Offset(point1!.dx - 5, point1!.dy - 22));

    final tpB = TextPainter(
      text: const TextSpan(text: "B", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpB.paint(canvas, Offset(point2!.dx - 5, point2!.dy - 22));
  }

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) => true;
}
