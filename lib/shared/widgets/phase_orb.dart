import 'package:flutter/material.dart';
import '../../core/constants/phase_constants.dart';

class PhaseOrb extends StatefulWidget {
  final CyclePhase phase;
  final int dayNumber;
  final double size;

  const PhaseOrb({
    super.key,
    required this.phase,
    required this.dayNumber,
    this.size = 80,
  });

  @override
  State<PhaseOrb> createState() => _PhaseOrbState();
}

class _PhaseOrbState extends State<PhaseOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = PhaseConstants.getPhaseInfo(widget.phase).colors;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [
                  colors.primary.withValues(alpha: 0.9),
                  colors.secondary.withValues(alpha: 0.6),
                  colors.background.withValues(alpha: 0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.4),
                  blurRadius: 20 + (_pulse.value * 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.dayNumber > 0) ...[
                    Text(
                      '${widget.dayNumber}',
                      style: TextStyle(
                        fontSize: widget.size * 0.28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'day',
                      style: TextStyle(
                        fontSize: widget.size * 0.13,
                        color: Colors.white60,
                      ),
                    ),
                  ] else ...[
                    Text(
                      PhaseConstants.getPhaseInfo(widget.phase).emoji,
                      style: TextStyle(
                        fontSize: widget.size * 0.38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
