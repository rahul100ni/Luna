import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/providers/theme_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/log/log_screen.dart';
import 'features/luna_ai/luna_ai_screen.dart';
import 'features/comfort/comfort_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/knowledge/knowledge_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init services
  await StorageService.init();
  await NotificationService.init();


  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: LunaApp()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, __) => const NoTransitionPage(child: SplashScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, __) => const NoTransitionPage(child: OnboardingScreen()),
    ),
    // Top-level tab destinations
    GoRoute(
      path: '/home',
      pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
    ),
    GoRoute(
      path: '/calendar',
      pageBuilder: (_, __) => const NoTransitionPage(child: CalendarScreen()),
    ),
    GoRoute(
      path: '/luna',
      pageBuilder: (_, __) => const MaterialPage(child: LunaAiScreen()),
    ),
    GoRoute(
      path: '/knowledge',
      pageBuilder: (_, __) => const NoTransitionPage(child: KnowledgeScreen()),
    ),
    GoRoute(
      path: '/insights',
      pageBuilder: (_, __) => const NoTransitionPage(child: InsightsScreen()),
    ),

    // Pushable modal / utility screens
    GoRoute(
      path: '/log',
      pageBuilder: (_, __) => const MaterialPage(child: LogScreen()),
    ),
    GoRoute(
      path: '/comfort',
      pageBuilder: (_, __) => const MaterialPage(child: ComfortScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (_, __) => const MaterialPage(child: SettingsScreen()),
    ),
  ],
);

class LunaApp extends ConsumerWidget {
  const LunaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Luna',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
