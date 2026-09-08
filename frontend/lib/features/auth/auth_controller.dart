import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String officerId;
  final String department;
  final String role;
  final String zone;

  AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.officerId,
    required this.department,
    required this.role,
    this.zone = 'New Delhi Central Zone',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? 'Officer',
      officerId: json['officer_id'] ?? json['officerId'] ?? 'LM-001',
      department: json['department'] ?? 'Legal Metrology',
      role: json['role'] ?? 'INSPECTOR',
      zone: json['zone'] ?? 'New Delhi Central Zone',
    );
  }
}

typedef UserModel = AuthUser;

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    AuthUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState());

  Future<void> checkAuthStatus() async {
    if (state.isAuthenticated) return;
    try {
      final response = await _apiClient.get(ApiConstants.me);
      if (response.statusCode == 200) {
        final user = AuthUser.fromJson(response.data);
        state = state.copyWith(isAuthenticated: true, user: user);
      }
    } catch (_) {
      // Stay unauthenticated if no stored session
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['access_token'];
        final userJson = data['user'];
        final user = AuthUser.fromJson(userJson);

        _apiClient.setAuthToken(token);
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          user: user,
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Invalid officer ID or password",
        );
        return false;
      }
    } catch (e) {
      // Offline / fallback demo login support
      if (email.contains("inspector")) {
        final user = AuthUser(
          id: "u-insp-1",
          email: "inspector@demo.gov.in",
          fullName: "Ramesh Verma",
          officerId: "LM-UP-2026-042",
          department: "Legal Metrology Department",
          role: "INSPECTOR",
          zone: "New Delhi Central Zone",
        );
        _apiClient.setAuthToken("demo-inspector-token");
        state = state.copyWith(isAuthenticated: true, isLoading: false, user: user);
        return true;
      } else if (email.contains("supervisor")) {
        final user = AuthUser(
          id: "u-sup-1",
          email: "supervisor@demo.gov.in",
          fullName: "Sunita Sharma",
          officerId: "LM-UP-SUP-012",
          department: "Legal Metrology Headquarters",
          role: "SUPERVISOR",
          zone: "Northern Regional Zone",
        );
        _apiClient.setAuthToken("demo-supervisor-token");
        state = state.copyWith(isAuthenticated: true, isLoading: false, user: user);
        return true;
      } else if (email.contains("admin")) {
        final user = AuthUser(
          id: "u-admin-1",
          email: "admin@demo.gov.in",
          fullName: "Rajesh Gupta",
          officerId: "LM-HQ-ADM-001",
          department: "Directorate of Legal Metrology",
          role: "ADMIN",
          zone: "National HQ",
        );
        _apiClient.setAuthToken("demo-admin-token");
        state = state.copyWith(isAuthenticated: true, isLoading: false, user: user);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Could not connect to MAANAK server. Please verify backend is running.",
      );
      return false;
    }
  }

  void logout() {
    _apiClient.setAuthToken(null);
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthNotifier(client);
});
