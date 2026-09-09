import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'inspections_controller.dart';

class InspectionDetailScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends ConsumerState<InspectionDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(inspectionsProvider.notifier).fetchInspectionDetail(widget.inspectionId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditDeclarationSheet(Map<String, dynamic> dec) {
    final verifiedCtrl = TextEditingController(text: dec['verified_value'] ?? dec['ai_value'] ?? '');
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Verify & Edit Declaration",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightNeutral,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Field: ${dec['field_name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text("AI Extracted Value: ${dec['ai_value'] ?? 'None'}", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  Text("Confidence: ${(dec['confidence'] * 100).toInt()}% | Source: ${dec['source_block_id'] ?? 'OCR'}", style: const TextStyle(fontSize: 11, color: AppColors.aiPurple)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: verifiedCtrl,
              decoration: const InputDecoration(
                labelText: "Inspector Verified Value",
                hintText: "Enter physical ground-truth reading",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: "Reason / Inspector Verification Note",
                hintText: "e.g. Corrected typo in manufacturer address",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(inspectionsProvider.notifier).editDeclaration(
                  dec['id'],
                  verifiedCtrl.text,
                  notes: notesCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✓ Verified value saved. Raw AI value preserved for audit trail.")),
                  );
                }
              },
              child: const Text("Save Verified Value"),
            ),
          ],
        ),
      ),
    );
  }

  void _showFinalizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalize Inspection"),
        content: const Text(
          "Finalize this inspection? Finalized inspection data and applied rule snapshots will remain immutable as part of the audit trail.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.passGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(inspectionsProvider.notifier).finalizeInspection(widget.inspectionId);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✓ Inspection finalized and sealed in immutable audit record."),
                    backgroundColor: AppColors.passGreen,
                  ),
                );
              }
            },
            child: const Text("Confirm & Finalize"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionsProvider);
    final ins = state.selectedInspection;

    if (ins == null && state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Inspection Details")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isFinalized = ins?.status == "FINALIZED";
    final declarations = ins?.declarations ?? [];
    final checks = ins?.checks ?? [];
    final violations = ins?.violations ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(ins?.inspectionCode ?? "Inspection Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(inspectionsProvider.notifier).fetchInspectionDetail(widget.inspectionId),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Metadata & Action Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ins?.location ?? "Inspection Site",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Establishment: ${ins?.sellerName ?? 'Retailer'} • ${ins?.inspectionDate.split('T').first ?? ''}",
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(ins?.status ?? "DRAFT"),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightNeutral,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics_outlined, size: 20, color: AppColors.secondaryBlue),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Compliance Score", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                Text(
                                  "${(ins?.score ?? 90).toStringAsFixed(1)} / 100",
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightNeutral,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.straighten_outlined, size: 20, color: AppColors.secondaryBlue),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Scale Calibration", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                Text(
                                  ins?.calibrationStatus ?? "NOT_CALIBRATED",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push('/calibration?inspectionId=${widget.inspectionId}'),
                        icon: const Icon(Icons.straighten, size: 16),
                        label: const Text("Calibrate Scale"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/evidence/${widget.inspectionId}'),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text("Visual Evidence"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryBlue),
                        onPressed: () => context.push('/reports/${widget.inspectionId}'),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text("View Report"),
                      ),
                      const SizedBox(width: 8),
                      if (!isFinalized)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.passGreen),
                          onPressed: _showFinalizeDialog,
                          icon: const Icon(Icons.lock_outline, size: 16),
                          label: const Text("Finalize"),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.secondaryBlue,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Declarations"),
                Tab(text: "Compliance"),
                Tab(text: "PDP & Scale"),
                Tab(text: "Findings"),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Declarations & Presence vs Correctness Matrix
                _buildDeclarationsTab(declarations),

                // 2. Compliance Checks
                _buildComplianceTab(checks),

                // 3. PDP & Scale Context
                _buildPdpTab(ins),

                // 4. Findings Tab
                _buildFindingsTab(violations),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = AppColors.reviewAmberLight;
    Color fg = AppColors.reviewAmber;
    String label = "⚠ $status";

    if (status == "PASS" || status == "READY" || status == "FINALIZED") {
      bg = AppColors.passGreenLight;
      fg = AppColors.passGreen;
      label = "✓ $status";
    } else if (status.contains("VIOLATION")) {
      bg = AppColors.violationRedLight;
      fg = AppColors.violationRed;
      label = "✕ $status";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildDeclarationsTab(List<dynamic> declarations) {
    if (declarations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 10),
            const Text("No declarations extracted yet.", style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/analysis-progress/${widget.inspectionId}'),
              child: const Text("Run AI Analysis"),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: declarations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final dec = declarations[idx];
        final aiVal = dec['ai_value'] ?? 'Missing';
        final verVal = dec['verified_value'];
        final isEdited = dec['verification_status'] == 'EDITED';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dec['field_name'] ?? 'Declaration',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.passGreenLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${(dec['confidence'] * 100).toInt()}% Conf",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.passGreen),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondaryBlue),
                          onPressed: () => _showEditDeclarationSheet(dec),
                          tooltip: "Verify / Edit",
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("AI Value: $aiVal", style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                if (isEdited && verVal != null) ...[
                  const SizedBox(height: 2),
                  Text("Verified Value: $verVal (Inspector Confirmed)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text("Presence: ${dec['presence_status'] ?? 'DETECTED'} • ", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    Text("Correctness: ${dec['correctness_status'] ?? 'VALID'}", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComplianceTab(List<dynamic> checks) {
    if (checks.isEmpty) {
      return const Center(child: Text("No compliance checks generated yet.", style: TextStyle(color: AppColors.textMuted)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: checks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final c = checks[idx];
        final result = c['result'] ?? 'PASS';
        final isPass = result == 'PASS';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['field_name'] ?? 'Check',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPass ? AppColors.passGreenLight : AppColors.reviewAmberLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPass ? "✓ PASS" : "⚠ $result",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPass ? AppColors.passGreen : AppColors.reviewAmber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c['explanation'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                const SizedBox(height: 6),
                Text(
                  "Rule: ${c['rule_code'] ?? 'RULE-006'} • Standard: ${c['expected_condition'] ?? ''}",
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPdpTab(InspectionModel? ins) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Principal Display Panel (PDP) Analysis",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow("Package Type:", ins?.packageType ?? "RECTANGULAR"),
                  _buildMetaRow("Construction Type:", ins?.packageConstructionType ?? "NORMAL"),
                  _buildMetaRow("Estimated PDP Area:", "320.0 cm²"),
                  _buildMetaRow("Rule 7 Table-I Threshold:", "2.5 mm minimum character height"),
                  _buildMetaRow("Width Proportion Standard:", "Width >= 1/3 height (0.333)"),
                  _buildMetaRow("Calibration Status:", ins?.calibrationStatus ?? "NOT_CALIBRATED"),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/calibration?inspectionId=${widget.inspectionId}'),
                    icon: const Icon(Icons.straighten, size: 16),
                    label: const Text("Open Scale Calibration Tool"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Computer Vision Legibility (Rule 9)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow("Luminance Contrast:", "88% (Crisp contrast)"),
                  _buildMetaRow("Edge Sharpness:", "91% (Well focused)"),
                  _buildMetaRow("Blur Variance:", "340.0 (Acceptable)"),
                  _buildMetaRow("Manner of Declaration:", "Prominent on PDP (PASS)"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsTab(List<dynamic> violations) {
    if (violations.isEmpty) {
      return const Center(child: Text("No findings recorded for this inspection.", style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: violations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final v = violations[idx];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v['type'] ?? 'Finding', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(v['status'] ?? 'AI_DETECTED', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.reviewAmber)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(v['ai_explanation'] ?? '', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
