import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    if (StorageService.onboardingComplete) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated orb
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.lerp(
                          const Color(0xFF9B84D4),
                          const Color(0xFFE07070),
                          _orbController.value,
                        )!,
                        Color.lerp(
                          const Color(0xFF6B5AA0),
                          const Color(0xFFB04040),
                          _orbController.value,
                        )!.withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.lerp(
                          const Color(0xFF9B84D4),
                          const Color(0xFFE07070),
                          _orbController.value,
                        )!.withValues(alpha: 0.4),
                        blurRadius: 40 + (_orbController.value * 20),
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🌙', style: TextStyle(fontSize: 48)),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Luna',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Your cycle companion',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
