import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/responsive/web_page_container.dart';
import '../inspections/inspections_controller.dart';

class AnalysisProgressScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const AnalysisProgressScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<AnalysisProgressScreen> createState() => _AnalysisProgressScreenState();
}

class _AnalysisProgressScreenState extends ConsumerState<AnalysisProgressScreen> {
  int _currentStep = 0;
  bool _isComplete = false;
  String? _errorMessage;

  final List<String> _steps = [
    "Checking captured image quality",
    "Reading visible package text with Groq Vision OCR",
    "Extracting product declarations from captured text",
    "Checking declaration completeness and consistency",
    "Applying applicable Legal Metrology rules",
    "Preparing the evidence-backed inspection result",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAnalysisFlow();
    });
  }

  Future<void> _runAnalysisFlow() async {
    setState(() {
      _errorMessage = null;
      _currentStep = 0;
      _isComplete = false;
    });

    // 1. Quick check: Is this inspection case already completed or evaluated on server?
    try {
      final detail = await ref.read(inspectionsProvider.notifier).fetchInspectionDetail(widget.inspectionId);
      if (detail != null) {
        final s = detail.status.toUpperCase();
        if (['NEEDS_REVIEW', 'READY', 'COMPLIANT', 'VIOLATION', 'FINALIZED', 'COMPLETED'].contains(s) &&
            (detail.declarations.isNotEmpty || detail.checks.isNotEmpty || (detail.score != null && detail.score! > 0))) {
          if (mounted) {
            setState(() {
              _currentStep = _steps.length - 1;
              _isComplete = true;
            });
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              context.go('/inspections/${widget.inspectionId}');
            }
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Start backend analysis call
    final analysisFuture = ref.read(inspectionsProvider.notifier).triggerAnalysis(widget.inspectionId);

    // Visual cues while the real server-side analysis runs.
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentStep = i;
      });
      await Future.delayed(const Duration(milliseconds: 600));
    }

    try {
      final res = await analysisFuture;
      if (!mounted) return;
      if (res != null && res["success"] == true) {
        setState(() {
          _isComplete = true;
        });
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          context.go('/inspections/${widget.inspectionId}');
        }
      } else {
        // Even if res was null (e.g. timeout), check if the server finished
        final lastCheck = await ref.read(inspectionsProvider.notifier).fetchInspectionDetail(widget.inspectionId);
        if (lastCheck != null) {
          final s = lastCheck.status.toUpperCase();
          if (['NEEDS_REVIEW', 'READY', 'COMPLIANT', 'VIOLATION', 'FINALIZED', 'COMPLETED'].contains(s) &&
              (lastCheck.declarations.isNotEmpty || lastCheck.checks.isNotEmpty || (lastCheck.score != null && lastCheck.score! > 0))) {
            if (mounted) {
              setState(() {
                _isComplete = true;
              });
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                context.go('/inspections/${widget.inspectionId}');
              }
              return;
            }
          }
        }

        final error = ref.read(inspectionsProvider).errorMessage ?? "Analysis pipeline failed. Please retry.";
        setState(() {
          _errorMessage = error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isWebDesktop(context);

    Widget progressCard = Card(
      elevation: isDesktop ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: _isComplete
                    ? const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.passGreen)
                    : const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: AppColors.primaryNavy,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _isComplete ? "Analysis Complete" : "Evaluating Legal Metrology Standards",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                "Applying Rule 6, Rule 7 (Table-I), Rule 9 & e-commerce compliance provisions.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 28),

            // Progress Steps
            for (int idx = 0; idx < _steps.length; idx++) ...[
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: idx < _currentStep || _isComplete
                          ? AppColors.passGreen
                          : (idx == _currentStep ? AppColors.secondaryBlue : AppColors.borderLight),
                    ),
                    child: idx < _currentStep || _isComplete
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : (idx == _currentStep
                            ? const Center(
                                child: SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const SizedBox()),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _steps[idx],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: idx == _currentStep ? FontWeight.w600 : FontWeight.normal,
                        color: idx <= _currentStep || _isComplete ? AppColors.textDark : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (idx < _steps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 16,
                    color: idx < _currentStep || _isComplete ? AppColors.passGreen : AppColors.borderLight,
                  ),
                ),
            ],

            const SizedBox(height: 28),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.violationRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.violationRed.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.violationRed, fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: _runAnalysisFlow,
                    label: const Text("Retry Pipeline"),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    onPressed: () => context.go('/inspections/${widget.inspectionId}'),
                    label: const Text("View Case File"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (isDesktop) {
      return WebPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryNavy),
                  onPressed: () => context.go('/scanner?inspectionId=${widget.inspectionId}'),
                  tooltip: 'Back to Scanner',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Package Scanner / Statutory AI Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: progressCard,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightNeutral,
      appBar: AppBar(
        title: const Text("Analysing Product Packaging"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: progressCard,
          ),
        ),
      ),
    );
  }
}
