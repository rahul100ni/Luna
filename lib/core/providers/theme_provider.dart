import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/phase_constants.dart';
import '../theme/luna_theme.dart';
import 'cycle_provider.dart';

final hasCycleAnchor = Provider<bool>((ref) {
  return ref.watch(hasCycleAnchorProvider);
});

final phaseColorsProvider = Provider<PhaseColors>((ref) {
  final hasCycle = ref.watch(hasCycleAnchorProvider);
  if (!hasCycle) {
    return PhaseConstants.neutralColors;
  }
  final phase = ref.watch(currentPhaseProvider);
  return PhaseConstants.getPhaseInfo(phase).colors;
});

final themeProvider = Provider<ThemeData>((ref) {
  final colors = ref.watch(phaseColorsProvider);
  return LunaTheme.themeForColors(colors);
});

final isComfortModeProvider = Provider<bool>((ref) {
  final hasCycle = ref.watch(hasCycleAnchorProvider);
  if (!hasCycle) return false;
  final phase = ref.watch(currentPhaseProvider);
  return PhaseConstants.isComfortMode(phase);
});
