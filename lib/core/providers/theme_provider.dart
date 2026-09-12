import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/phase_constants.dart';
import '../theme/luna_theme.dart';
import 'cycle_provider.dart';

final themeProvider = Provider<ThemeData>((ref) {
  final phase = ref.watch(currentPhaseProvider);
  return LunaTheme.themeForPhase(phase);
});

final phaseColorsProvider = Provider<PhaseColors>((ref) {
  final phase = ref.watch(currentPhaseProvider);
  return PhaseConstants.getPhaseInfo(phase).colors;
});

final isComfortModeProvider = Provider<bool>((ref) {
  final phase = ref.watch(currentPhaseProvider);
  return PhaseConstants.isComfortMode(phase);
});
