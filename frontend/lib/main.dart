import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/constants/app_brand.dart';
import 'features/auth/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MaanakApp(),
    ),
  );
}

class MaanakApp extends ConsumerStatefulWidget {
  const MaanakApp({super.key});

  @override
  ConsumerState<MaanakApp> createState() => _MaanakAppState();
}

class _MaanakAppState extends ConsumerState<MaanakApp> {
  /// Notifier that GoRouter listens to for redirect re-evaluation.
  final _authNotifier = ValueNotifier<int>(0);

  /// The GoRouter instance — created exactly once and never replaced.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(ref, _authNotifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen is allowed in build — bump the notifier so GoRouter
    // re-evaluates its redirect whenever auth state changes.
    ref.listen<AuthState>(authProvider, (previous, current) {
      _authNotifier.value++;
    });

    return MaterialApp.router(
      title: '${AppBrand.name} — Legal Metrology Inspection Platform',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
