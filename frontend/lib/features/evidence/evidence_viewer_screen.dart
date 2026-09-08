import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../inspections/inspections_controller.dart';

class EvidenceViewerScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const EvidenceViewerScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<EvidenceViewerScreen> createState() => _EvidenceViewerScreenState();
}

class _EvidenceViewerScreenState extends ConsumerState<EvidenceViewerScreen> {
  bool _showOverlays = true;

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

  @override
  Widget build(BuildContext context) {
    final inspectionState = ref.watch(inspectionsProvider);
    final inspection = inspectionState.selectedInspection;
    final violations = inspection?.violations ?? [];

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
          // Visual Evidence Canvas Area
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF0F172A),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
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
                    child: Stack(
                      children: [
                        // Background placeholder commodity label image
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 70, color: Colors.white30),
                              const SizedBox(height: 12),
                              Text(
                                inspection?.packageType ?? "Packaged Commodity Label",
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        // Render Annotated Bounding Box Overlays
                        if (_showOverlays) ...[
                          // Green passed box: Commodity Name
                          _buildOverlayBox(
                            left: 30, top: 40, width: 280, height: 45,
                            label: "✓ Name (PASS)", color: AppColors.passGreen,
                          ),
                          // Green passed box: Net Quantity
                          _buildOverlayBox(
                            left: 30, top: 220, width: 140, height: 40,
                            label: "✓ 5 KG (PASS)", color: AppColors.passGreen,
                          ),
                          // Green passed box: MRP
                          _buildOverlayBox(
                            left: 30, top: 280, width: 180, height: 40,
                            label: "✓ MRP ₹450 (PASS)", color: AppColors.passGreen,
                          ),
                          // Amber review box: Consumer Care
                          _buildOverlayBox(
                            left: 30, top: 340, width: 260, height: 45,
                            label: "⚠ Consumer Care (REVIEW)", color: AppColors.reviewAmber,
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

                              return Card(
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

  Widget _buildOverlayBox({
    required double left,
    required double top,
    required double width,
    required double height,
    required String label,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        alignment: Alignment.topLeft,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black87,
          ),
        ),
      ),
    );
  }
}
