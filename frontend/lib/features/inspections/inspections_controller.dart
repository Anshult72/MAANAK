import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

class InspectionModel {
  final String id;
  final String inspectionCode;
  final String? inspectorId;
  final String? productId;
  final String inspectionType;
  final String inspectionDate;
  final String location;
  final String? sellerName;
  final String? businessName;
  final String status;
  final double? score;
  final String? packageType;
  final String? packageConstructionType;
  final String? calibrationStatus;
  final Map<String, dynamic>? calibrationData;
  final Map<String, dynamic>? pdpData;
  final String? appliedRuleVersion;
  final String? notes;
  final List<dynamic> images;
  final List<dynamic> declarations;
  final List<dynamic> checks;
  final List<dynamic> violations;

  InspectionModel({
    required this.id,
    required this.inspectionCode,
    this.inspectorId,
    this.productId,
    this.inspectionType = 'PHYSICAL',
    required this.inspectionDate,
    required this.location,
    this.sellerName,
    this.businessName,
    this.status = 'DRAFT',
    this.score,
    this.packageType = 'RECTANGULAR',
    this.packageConstructionType = 'NORMAL',
    this.calibrationStatus = 'NOT_CALIBRATED',
    this.calibrationData,
    this.pdpData,
    this.appliedRuleVersion,
    this.notes,
    this.images = const [],
    this.declarations = const [],
    this.checks = const [],
    this.violations = const [],
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'] ?? '',
      inspectionCode: json['inspection_code'] ?? json['inspectionCode'] ?? 'INS-000',
      inspectorId: json['inspector_id'],
      productId: json['product_id'],
      inspectionType: json['inspection_type'] ?? 'PHYSICAL',
      inspectionDate: json['inspection_date'] ?? json['createdAt'] ?? '',
      location: json['location'] ?? 'Site',
      sellerName: json['seller_name'],
      businessName: json['business_name'],
      status: json['status'] ?? 'DRAFT',
      score: (json['score'] as num?)?.toDouble(),
      packageType: json['package_type'] ?? 'RECTANGULAR',
      packageConstructionType: json['package_construction_type'] ?? 'NORMAL',
      calibrationStatus: json['calibration_status'] ?? 'NOT_CALIBRATED',
      calibrationData: json['calibration_data'],
      pdpData: json['pdp_data'],
      appliedRuleVersion: json['applied_rule_version'],
      notes: json['notes'],
      images: json['images'] ?? [],
      declarations: json['declarations'] ?? [],
      checks: json['checks'] ?? [],
      violations: json['violations'] ?? [],
    );
  }
}

class InspectionState {
  final bool isLoading;
  final List<InspectionModel> inspections;
  final InspectionModel? selectedInspection;
  final String? errorMessage;
  final Map<String, dynamic>? currentAnalysisResult;

  InspectionState({
    this.isLoading = false,
    this.inspections = const [],
    this.selectedInspection,
    this.errorMessage,
    this.currentAnalysisResult,
  });

  InspectionState copyWith({
    bool? isLoading,
    List<InspectionModel>? inspections,
    InspectionModel? selectedInspection,
    String? errorMessage,
    Map<String, dynamic>? currentAnalysisResult,
  }) {
    return InspectionState(
      isLoading: isLoading ?? this.isLoading,
      inspections: inspections ?? this.inspections,
      selectedInspection: selectedInspection ?? this.selectedInspection,
      errorMessage: errorMessage,
      currentAnalysisResult: currentAnalysisResult ?? this.currentAnalysisResult,
    );
  }
}

class InspectionsNotifier extends StateNotifier<InspectionState> {
  final ApiClient _apiClient;

  InspectionsNotifier(this._apiClient) : super(InspectionState());

  Future<void> fetchInspections() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.get(ApiConstants.inspections);
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => InspectionModel.fromJson(item))
            .toList();
        state = state.copyWith(isLoading: false, inspections: list);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<InspectionModel?> fetchInspectionDetail(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.get("${ApiConstants.inspections}/$id");
      if (response.statusCode == 200) {
        final model = InspectionModel.fromJson(response.data);
        state = state.copyWith(isLoading: false, selectedInspection: model);
        return model;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return null;
  }

  Future<InspectionModel?> createInspection({
    required String location,
    String? sellerName,
    String? businessName,
    String productCategory = "Packaged Food",
    String inspectionType = "PHYSICAL",
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiConstants.inspections,
        data: {
          'location': location,
          'seller_name': sellerName,
          'business_name': businessName,
          'product_category': productCategory,
          'inspection_type': inspectionType,
          'notes': notes,
        },
      );
      if (response.statusCode == 200) {
        final model = InspectionModel.fromJson(response.data);
        state = state.copyWith(
          isLoading: false,
          inspections: [model, ...state.inspections],
          selectedInspection: model,
        );
        return model;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return null;
  }

  Future<Map<String, dynamic>?> triggerAnalysis(String inspectionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        "${ApiConstants.inspections}/$inspectionId/analyze",
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await fetchInspectionDetail(inspectionId);
        state = state.copyWith(isLoading: false, currentAnalysisResult: data);
        return data;
      }
    } catch (e) {
      String message = "Analysis could not be completed. Please retry in a moment.";
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map) {
          if (responseData['detail'] is String) {
            message = responseData['detail'] as String;
          } else if (responseData['error'] is Map) {
            final errorMap = responseData['error'] as Map;
            message = (errorMap['details'] as String?) ??
                (errorMap['message'] as String?) ??
                message;
          } else if (responseData['message'] is String) {
            message = responseData['message'] as String;
          }
        } else if (responseData is String && responseData.isNotEmpty && !responseData.contains("<html")) {
          message = responseData;
        } else if (e.response?.statusCode == 503) {
          message = "Image analysis service is temporarily busy. Please retry in a moment.";
        } else if (e.response?.statusCode != null) {
          message = "The server could not complete this analysis (${e.response?.statusCode}). Please retry.";
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
    return null;
  }

  Future<bool> editDeclaration(String declarationId, String verifiedValue, {String? notes}) async {
    try {
      final response = await _apiClient.patch(
        "/api/declarations/$declarationId",
        data: {
          'verified_value': verifiedValue,
          'notes': notes,
        },
      );
      if (response.statusCode == 200 && state.selectedInspection != null) {
        await fetchInspectionDetail(state.selectedInspection!.id);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> updateCalibration({
    required String inspectionId,
    required double pxPerMm,
    required double knownDistanceMm,
    required Map<String, double> pt1,
    required Map<String, double> pt2,
  }) async {
    try {
      final calibData = {
        'calibration_status': 'CALIBRATED',
        'calibration_data': {
          'method': 'KNOWN_DISTANCE',
          'knownDistance': knownDistanceMm,
          'pixelsPerMm': pxPerMm,
          'point1': pt1,
          'point2': pt2,
        }
      };
      final response = await _apiClient.patch(
        "${ApiConstants.inspections}/$inspectionId",
        data: calibData,
      );
      if (response.statusCode == 200) {
        await fetchInspectionDetail(inspectionId);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> confirmFinding(String findingId, {String? comment}) async {
    try {
      final response = await _apiClient.post(
        "/api/findings/$findingId/confirm",
        data: {'inspector_comment': comment},
      );
      if (response.statusCode == 200 && state.selectedInspection != null) {
        await fetchInspectionDetail(state.selectedInspection!.id);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> rejectFinding(String findingId, {String? comment}) async {
    try {
      final response = await _apiClient.post(
        "/api/findings/$findingId/reject",
        data: {'inspector_comment': comment},
      );
      if (response.statusCode == 200 && state.selectedInspection != null) {
        await fetchInspectionDetail(state.selectedInspection!.id);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> addManualFinding(String inspectionId, {required String title, required String description}) async {
    try {
      final response = await _apiClient.post(
        "/api/inspections/$inspectionId/findings/manual",
        data: {
          'title': title,
          'description': description,
          'severity': 'MEDIUM',
          'type': 'MANUAL_OBSERVATION',
        },
      );
      if (response.statusCode == 200) {
        await fetchInspectionDetail(inspectionId);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> finalizeInspection(String inspectionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        "${ApiConstants.inspections}/$inspectionId/finalize",
      );
      if (response.statusCode == 200) {
        await fetchInspectionDetail(inspectionId);
        state = state.copyWith(isLoading: false);
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> archivePdfBytes(String inspectionId, List<int> pdfBytes) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(pdfBytes, filename: 'report_$inspectionId.pdf'),
      });
      final response = await _apiClient.uploadFile(
        "${ApiConstants.reports}/$inspectionId/pdf",
        formData,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

final inspectionsProvider = StateNotifierProvider<InspectionsNotifier, InspectionState>((ref) {
  final client = ref.watch(apiClientProvider);
  return InspectionsNotifier(client);
});
