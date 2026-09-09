class ApiConstants {
  // Production API by default. Override for a local backend when needed.
  // Example: --dart-define=API_BASE_URL=http://10.0.2.2:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://maanak-85bh.onrender.com',
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
