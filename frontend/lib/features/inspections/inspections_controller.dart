import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

class EvidenceModel {
  final String id;
  final String inspectionId;
  final String? imageId;
  final String? findingId;
  final String evidenceType;
  final String? originalPath;
  final String? cropPath;
  final Map<String, dynamic>? bbox;
  final String? description;
  final String? cloudinaryPublicId;
  final String? cloudinarySecureUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? fileSizeBytes;
  final String? sha256;
  final String status;
  final String? createdBy;
  final String? createdAt;

  EvidenceModel({
    required this.id,
    required this.inspectionId,
    this.imageId,
    this.findingId,
    this.evidenceType = 'DECLARATION_CROP',
    this.originalPath,
    this.cropPath,
    this.bbox,
    this.description,
    this.cloudinaryPublicId,
    this.cloudinarySecureUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fileSizeBytes,
    this.sha256,
    this.status = 'STORED',
    this.createdBy,
    this.createdAt,
  });

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    return EvidenceModel(
      id: json['id']?.toString() ?? '',
      inspectionId: json['inspection_id']?.toString() ?? '',
      imageId: json['image_id']?.toString(),
      findingId: json['finding_id']?.toString(),
      evidenceType: json['evidence_type']?.toString() ?? 'DECLARATION_CROP',
      originalPath: json['original_path']?.toString(),
      cropPath: json['crop_path']?.toString(),
      bbox: json['bbox'] is Map ? Map<String, dynamic>.from(json['bbox']) : null,
      description: json['description']?.toString(),
      cloudinaryPublicId: json['cloudinary_public_id']?.toString(),
      cloudinarySecureUrl: json['cloudinary_secure_url']?.toString() ?? json['cloudinaryUrl']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString() ?? json['thumbnailUrl']?.toString(),
      width: json['width'] is int ? json['width'] : (json['width'] as num?)?.toInt(),
      height: json['height'] is int ? json['height'] : (json['height'] as num?)?.toInt(),
      fileSizeBytes: json['file_size_bytes'] is int ? json['file_size_bytes'] : (json['file_size_bytes'] as num?)?.toInt(),
      sha256: json['sha256']?.toString(),
      status: json['status']?.toString() ?? 'STORED',
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

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
  final List<EvidenceModel> evidenceItems;

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
    this.evidenceItems = const [],
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    List<EvidenceModel> evItems = [];
    final rawEv = json['evidence_items'] ?? json['evidence'];
    if (rawEv is List) {
      evItems = rawEv
          .whereType<Map>()
          .map((e) => EvidenceModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

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
      evidenceItems: evItems,
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
      // Check if the server finished processing in the background
      try {
        final verifiedDetail = await fetchInspectionDetail(inspectionId);
        if (verifiedDetail != null) {
          final s = verifiedDetail.status.toUpperCase();
          if (['NEEDS_REVIEW', 'READY', 'COMPLIANT', 'VIOLATION', 'COMPLETED', 'FINALIZED'].contains(s) &&
              (verifiedDetail.declarations.isNotEmpty ||
                  verifiedDetail.checks.isNotEmpty ||
                  (verifiedDetail.score != null && verifiedDetail.score! > 0))) {
            state = state.copyWith(isLoading: false, errorMessage: null);
            return {
              "success": true,
              "status": s,
              "score": verifiedDetail.score,
            };
          }
        }
      } catch (_) {}

      String message = "Analysis could not be completed. Please retry in a moment.";
      if (e is DioException) {
        if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
          message = "Analysis is still processing on the server. Please click Retry Pipeline to check status.";
        } else {
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

  Future<List<EvidenceModel>> fetchEvidence(String inspectionId) async {
    try {
      final response = await _apiClient.get("${ApiConstants.inspections}/$inspectionId/evidence");
      if (response.statusCode == 200 && response.data is List) {
        final items = (response.data as List)
            .whereType<Map>()
            .map((e) => EvidenceModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // Update selected inspection with fresh evidence items
        if (state.selectedInspection != null && state.selectedInspection!.id == inspectionId) {
          final updated = InspectionModel(
            id: state.selectedInspection!.id,
            inspectionCode: state.selectedInspection!.inspectionCode,
            inspectorId: state.selectedInspection!.inspectorId,
            productId: state.selectedInspection!.productId,
            inspectionType: state.selectedInspection!.inspectionType,
            inspectionDate: state.selectedInspection!.inspectionDate,
            location: state.selectedInspection!.location,
            sellerName: state.selectedInspection!.sellerName,
            businessName: state.selectedInspection!.businessName,
            status: state.selectedInspection!.status,
            score: state.selectedInspection!.score,
            packageType: state.selectedInspection!.packageType,
            packageConstructionType: state.selectedInspection!.packageConstructionType,
            calibrationStatus: state.selectedInspection!.calibrationStatus,
            calibrationData: state.selectedInspection!.calibrationData,
            pdpData: state.selectedInspection!.pdpData,
            appliedRuleVersion: state.selectedInspection!.appliedRuleVersion,
            notes: state.selectedInspection!.notes,
            images: state.selectedInspection!.images,
            declarations: state.selectedInspection!.declarations,
            checks: state.selectedInspection!.checks,
            violations: state.selectedInspection!.violations,
            evidenceItems: items,
          );
          state = state.copyWith(selectedInspection: updated);
        }
        return items;
      }
    } catch (_) {}
    return [];
  }

  Future<bool> retryEvidenceUpload(String inspectionId, String evidenceId) async {
    try {
      final response = await _apiClient.post(
        "${ApiConstants.inspections}/$inspectionId/evidence/$evidenceId/retry",
      );
      if (response.statusCode == 200) {
        await fetchEvidence(inspectionId);
        return true;
      }
    } catch (_) {}
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
