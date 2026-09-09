import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
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
    "Preparing surface captures & CV quality validation",
    "Detecting Principal Display Panel & text boundaries",
    "Extracting coordinate text blocks via OCR",
    "Normalizing declarations with Gemini LLM",
    "Validating declaration correctness & consistency",
    "Applying Rule 7 Table-I character scale & proportions",
    "Evaluating compliance & generating visual evidence",
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

    // Start backend analysis call
    final analysisFuture = ref.read(inspectionsProvider.notifier).triggerAnalysis(widget.inspectionId);

    // Simulate animated step transitions for realistic government inspector experience
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
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
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
                            child: Center(
                              child: idx < _currentStep || _isComplete
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : (idx == _currentStep
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          "${idx + 1}",
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        )),
                            ),
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.violationRed, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _runAnalysisFlow,
                        child: const Text("Retry Pipeline"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
