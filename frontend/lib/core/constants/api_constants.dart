class ApiConstants {
  // ---------------------------------------------------------------------------
  // Production API (Railway).
  // Override at build-time for local development:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  //   flutter build apk --release --dart-define=API_BASE_URL=https://maanak-production.up.railway.app
  // ---------------------------------------------------------------------------
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://maanak-production.up.railway.app',
  );

  static const String login = "/api/auth/login";
  static const String me = "/api/auth/me";
  
  static const String inspections = "/api/inspections";
  static const String rules = "/api/rules";
  static const String products = "/api/products";
  static const String reports = "/api/reports";
  static const String dashboard = "/api/dashboard";
  static const String auditLogs = "/api/audit-logs";
  static const String onlineListings = "/api/listings";
}
