import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/cycle_engine.dart';
import 'core/services/deepseek_service.dart';
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
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('Orientation configuration error: $e');
  }

  // Init storage service
  try {
    await StorageService.init();
    // Silently pull remote API key in background
    DeepSeekService.syncApiKeyFromRemote();
  } catch (e) {
    debugPrint('StorageService init error: $e');
  }

  // Init notifications and schedule
  try {
    await NotificationService.init();
    final profile = StorageService.getProfile();
    if (profile != null) {
      final state = CycleEngine.calculate(profile);
      await NotificationService.schedulePhaseNotifications(state);
    }
  } catch (e) {
    debugPrint('Notification startup error: $e');
  }

  // Transparent status bar
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  } catch (e) {
    debugPrint('System UI overlay style error: $e');
  }

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
      pageBuilder: (_, __) => const NoTransitionPage(child: LunaAiScreen()),
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
      pageBuilder: (_, state) {
        final date = state.extra as DateTime?;
        return NoTransitionPage(child: LogScreen(initialDate: date));
      },
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
