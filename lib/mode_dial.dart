import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AtmosphereMood {
  dusk,
  midnight,
  eclipse,
  emerald,
  aurora,
  dawn;

  String get displayName {
    switch (this) {
      case AtmosphereMood.dusk:
        return 'Dusk';
      case AtmosphereMood.midnight:
        return 'Midnight';
      case AtmosphereMood.eclipse:
        return 'Eclipse';
      case AtmosphereMood.emerald:
        return 'Emerald';
      case AtmosphereMood.aurora:
        return 'Aurora';
      case AtmosphereMood.dawn:
        return 'Dawn';
    }
  }

  String get spacedTitle {
    switch (this) {
      case AtmosphereMood.dusk:
        return 'D U S K';
      case AtmosphereMood.midnight:
        return 'M I D N I G H T';
      case AtmosphereMood.eclipse:
        return 'E C L I P S E';
      case AtmosphereMood.emerald:
        return 'E M E R A L D';
      case AtmosphereMood.aurora:
        return 'A U R O R A';
      case AtmosphereMood.dawn:
        return 'D A W N';
    }
  }

  String get subtitle {
    switch (this) {
      case AtmosphereMood.dusk:
        return 'Warm • Atmospheric';
      case AtmosphereMood.midnight:
        return 'Quiet • Starlit';
      case AtmosphereMood.eclipse:
        return 'Mystic • Solar Corona';
      case AtmosphereMood.emerald:
        return 'Fresh • Bioluminescent';
      case AtmosphereMood.aurora:
        return 'Calm • Borealis Sky';
      case AtmosphereMood.dawn:
        return 'Soft • Golden Mist';
    }
  }

  String get audioAsset {
    switch (this) {
      case AtmosphereMood.dusk:
        return 'audio/dusk.mp3';
      case AtmosphereMood.midnight:
        return 'audio/Midnight.mp3';
      case AtmosphereMood.eclipse:
        return 'audio/Eclipse.mp3';
      case AtmosphereMood.emerald:
        return 'audio/Emerald.mp3';
      case AtmosphereMood.aurora:
        return 'audio/Aurora.mp3';
      case AtmosphereMood.dawn:
        return 'audio/Dawn.mp3';
    }
  }

  Color get primaryColor {
    switch (this) {
      case AtmosphereMood.dusk:
        return const Color(0xFFFF5E1E);
      case AtmosphereMood.midnight:
        return const Color(0xFF6B9FFF);
      case AtmosphereMood.eclipse:
        return const Color(0xFFC06AFF);
      case AtmosphereMood.emerald:
        return const Color(0xFF2EEDB0);
      case AtmosphereMood.aurora:
        return const Color(0xFF26E6E6);
      case AtmosphereMood.dawn:
        return const Color(0xFFFFB338);
    }
  }

  Color get glowColor {
    switch (this) {
      case AtmosphereMood.dusk:
        return const Color(0xFFFF3D00);
      case AtmosphereMood.midnight:
        return const Color(0xFF3377FF);
      case AtmosphereMood.eclipse:
        return const Color(0xFFA62BFF);
      case AtmosphereMood.emerald:
        return const Color(0xFF00D692);
      case AtmosphereMood.aurora:
        return const Color(0xFF00BFBF);
      case AtmosphereMood.dawn:
        return const Color(0xFFFF9400);
    }
  }

  Color get deepCoreColor {
    switch (this) {
      case AtmosphereMood.dusk:
        return const Color(0xFF2B1018);
      case AtmosphereMood.midnight:
        return const Color(0xFF07112B);
      case AtmosphereMood.eclipse:
        return const Color(0xFF090612);
      case AtmosphereMood.emerald:
        return const Color(0xFF06241B);
      case AtmosphereMood.aurora:
        return const Color(0xFF052229);
      case AtmosphereMood.dawn:
        return const Color(0xFF2B1A12);
    }
  }
}

/// Purely procedural 3D planet orb widget (zero image assets).
class ProceduralPlanetSphere extends StatelessWidget {
  final AtmosphereMood mood;
  final double size;
  final double activeAmount;

  const ProceduralPlanetSphere({
    super.key,
    required this.mood,
    this.size = 52.0,
    this.activeAmount = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProceduralPlanetSpherePainter(
          mood: mood,
          activeAmount: activeAmount,
        ),
      ),
    );
  }
}

class _ProceduralPlanetSpherePainter extends CustomPainter {
  final AtmosphereMood mood;
  final double activeAmount;

  const _ProceduralPlanetSpherePainter({
    required this.mood,
    required this.activeAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Base procedural atmosphere sphere
    if (mood == AtmosphereMood.eclipse) {
      // Corona ring + dark obsidian eclipse core
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF06040A),
              const Color(0xFF06040A),
              mood.primaryColor,
              Colors.white,
            ],
            stops: const [0.0, 0.62, 0.88, 1.0],
          ).createShader(rect),
      );
    } else {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 1.1,
            colors: [
              Colors.white.withValues(alpha: 0.9),
              mood.primaryColor,
              mood.glowColor,
              mood.deepCoreColor,
            ],
            stops: const [0.0, 0.28, 0.68, 1.0],
          ).createShader(rect),
      );

      // Procedural atmospheric swirl bands inside the planet
      final bandPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14;
      canvas.drawArc(
        Rect.fromCenter(
          center: center + Offset(0, -radius * 0.15),
          width: radius * 2.2,
          height: radius * 0.9,
        ),
        0.1,
        math.pi * 0.8,
        false,
        bandPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: center + Offset(0, radius * 0.25),
          width: radius * 2.0,
          height: radius * 0.7,
        ),
        0.2,
        math.pi * 0.7,
        false,
        bandPaint..color = mood.deepCoreColor.withValues(alpha: 0.35),
      );
    }

    // Dimming overlay when inactive
    if (activeAmount < 0.99) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35 * (1.0 - activeAmount)),
      );
    }

    // Specular 3D glass rim highlight
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    canvas.restore();

    // Crisp rim border
    canvas.drawCircle(
      center,
      radius - 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = activeAmount > 0.5 ? 1.8 : 0.8
        ..color = Color.lerp(
          Colors.white.withValues(alpha: 0.22),
          mood.primaryColor,
          activeAmount,
        )!,
    );
  }

  @override
  bool shouldRepaint(covariant _ProceduralPlanetSpherePainter old) =>
      old.mood != mood || old.activeAmount != activeAmount;
}

class ModeDial extends StatefulWidget {
  final AtmosphereMood selectedMood;
  final ValueChanged<AtmosphereMood> onMoodChanged;
  final ValueChanged<double>? onProgressChanged;
  final bool hapticsEnabled;

  const ModeDial({
    super.key,
    required this.selectedMood,
    required this.onMoodChanged,
    this.onProgressChanged,
    this.hapticsEnabled = true,
  });

  @override
  State<ModeDial> createState() => _ModeDialState();
}

class _ModeDialState extends State<ModeDial> with TickerProviderStateMixin {
  late final AnimationController _snapController;
  late final AnimationController _orbitController;
  Animation<double>? _snapAnimation;
  late double _currentProgress;
  int _lastHapticSegment = 0;
  bool _isDragging = false;

  static const double _startAngleDeg = 165.0;
  static const double _endAngleDeg = 15.0;
  static const double _angleSpanDeg = _startAngleDeg - _endAngleDeg;
  static const double _angleStepDeg = _angleSpanDeg / 5.0;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.selectedMood.index.toDouble();
    _lastHapticSegment = widget.selectedMood.index;

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant ModeDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMood != widget.selectedMood && !_isDragging) {
      final targetProgress = widget.selectedMood.index.toDouble();
      if ((_currentProgress - targetProgress).abs() > 0.05 &&
          !_snapController.isAnimating) {
        _animateToMode(targetProgress);
      }
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  void _animateToMode(double targetProgress) {
    _snapController.stop();
    final startVal = _currentProgress;
    _snapAnimation = Tween<double>(
      begin: startVal,
      end: targetProgress,
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )..addListener(() {
        final val = _snapAnimation!.value;
        setState(() {
          _currentProgress = val;
        });
        widget.onProgressChanged?.call(val);
      });

    _snapController.forward(from: 0.0).then((_) {
      if (mounted) {
        final finalIndex = _currentProgress
            .round()
            .clamp(0, AtmosphereMood.values.length - 1);
        widget.onMoodChanged(AtmosphereMood.values[finalIndex]);
      }
    });
  }

  double _angleFromProgress(double progress) {
    final deg = _startAngleDeg - progress * _angleStepDeg;
    return deg * math.pi / 180.0;
  }

  double _progressFromAngle(double angleRad) {
    double deg = angleRad * 180.0 / math.pi;
    if (deg < -90) deg += 360;
    final raw = (_startAngleDeg - deg) / _angleStepDeg;
    return raw.clamp(0.0, 5.0);
  }

  Offset _getPivot(Size size) => Offset(size.width * 0.50, size.height * 0.70);
  double _getOrbitRadius(Size size) => size.width * 0.42;

  void _handleTouch(Offset localPos, Size size) {
    final pivot = _getPivot(size);
    final dx = localPos.dx - pivot.dx;
    final dy = pivot.dy - localPos.dy;

    if (dy <= -20) return;

    final angle = math.atan2(dy, dx);
    final newProgress = _progressFromAngle(angle);

    final segment = newProgress.round();
    if (segment != _lastHapticSegment) {
      _lastHapticSegment = segment;
      if (widget.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    setState(() {
      _currentProgress = newProgress;
    });
    widget.onProgressChanged?.call(_currentProgress);
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _isDragging = true;
    _snapController.stop();
    _handleTouch(details.localPosition, size);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    _handleTouch(details.localPosition, size);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    final targetIndex =
        _currentProgress.round().clamp(0, AtmosphereMood.values.length - 1);
    if (widget.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    _animateToMode(targetIndex.toDouble());
  }

  void _onPlanetTapped(int index) {
    if (widget.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    _animateToMode(index.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final moods = AtmosphereMood.values;
    final activeIndex = _currentProgress.round().clamp(0, moods.length - 1);
    final activeMood = moods[activeIndex];

    final lowerIndex = _currentProgress.floor().clamp(0, moods.length - 1);
    final upperIndex = _currentProgress.ceil().clamp(0, moods.length - 1);
    final remainder = _currentProgress - lowerIndex;
    final interpolatedColor = Color.lerp(
      moods[lowerIndex].primaryColor,
      moods[upperIndex].primaryColor,
      remainder,
    )!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dialWidth = math.min(constraints.maxWidth, 380.0);
        final dialHeight = dialWidth * 0.72;
        final size = Size(dialWidth, dialHeight);

        final pivot = _getPivot(size);
        final orbitRadius = _getOrbitRadius(size);

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _orbitController,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _onPanStart(d, size),
                    onPanUpdate: (d) => _onPanUpdate(d, size),
                    onPanEnd: _onPanEnd,
                    child: SizedBox(
                      width: dialWidth,
                      height: dialHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              size: size,
                              painter: _CelestialOrreryPainter(
                                pivot: pivot,
                                orbitRadius: orbitRadius,
                                progress: _currentProgress,
                                interpolatedColor: interpolatedColor,
                                needleAngle:
                                    _angleFromProgress(_currentProgress),
                              ),
                            ),
                          ),
                          for (int i = 0; i < moods.length; i++)
                            _buildPlanetOrb(
                              index: i,
                              pivot: pivot,
                              orbitRadius: orbitRadius,
                              mood: moods[i],
                              progress: _currentProgress,
                              orbitAnimValue: _orbitController.value,
                            ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                size: size,
                                painter: _CentralCorePainter(
                                  pivot: pivot,
                                  interpolatedColor: interpolatedColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      key: ValueKey(activeMood.spacedTitle),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeMood.spacedTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: activeMood.primaryColor,
                            fontSize: 17.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5.5,
                            shadows: [
                              Shadow(
                                color: activeMood.primaryColor
                                    .withValues(alpha: 0.9),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activeMood.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 28,
                          height: 2.4,
                          decoration: BoxDecoration(
                            color: activeMood.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: activeMood.primaryColor
                                    .withValues(alpha: 0.85),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlanetOrb({
    required int index,
    required Offset pivot,
    required double orbitRadius,
    required AtmosphereMood mood,
    required double progress,
    required double orbitAnimValue,
  }) {
    final angleRad = _angleFromProgress(index.toDouble());
    final planetX = pivot.dx + math.cos(angleRad) * orbitRadius;
    final planetY = pivot.dy - math.sin(angleRad) * orbitRadius;

    final distance = (progress - index).abs();
    final activeAmount = (1.0 - distance).clamp(0.0, 1.0);

    const double baseDiameter = 52.0;

    return Positioned(
      left: planetX - 44,
      top: planetY - 44,
      width: 88,
      height: 88,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onPlanetTapped(index),
        child: Center(
          child: Transform.scale(
            scale: 1.0 + 0.25 * activeAmount,
            child: SizedBox(
              width: baseDiameter,
              height: baseDiameter,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -20,
                    top: -16,
                    width: baseDiameter + 40,
                    height: baseDiameter + 32,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _PlanetaryRingPainter(
                          isFront: false,
                          activeAmount: activeAmount,
                          glowColor: mood.glowColor,
                          primaryColor: mood.primaryColor,
                          animValue: orbitAnimValue,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: baseDiameter,
                    height: baseDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (activeAmount > 0.08)
                          BoxShadow(
                            color: mood.glowColor.withValues(
                              alpha: 0.65 * activeAmount,
                            ),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: ProceduralPlanetSphere(
                      mood: mood,
                      size: baseDiameter,
                      activeAmount: activeAmount,
                    ),
                  ),
                  Positioned(
                    left: -20,
                    top: -16,
                    width: baseDiameter + 40,
                    height: baseDiameter + 32,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _PlanetaryRingPainter(
                          isFront: true,
                          activeAmount: activeAmount,
                          glowColor: mood.glowColor,
                          primaryColor: mood.primaryColor,
                          animValue: orbitAnimValue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CelestialOrreryPainter extends CustomPainter {
  final Offset pivot;
  final double orbitRadius;
  final double progress;
  final Color interpolatedColor;
  final double needleAngle;

  const _CelestialOrreryPainter({
    required this.pivot,
    required this.orbitRadius,
    required this.progress,
    required this.interpolatedColor,
    required this.needleAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 0.9;
    const startRad = 165.0 * math.pi / 180.0;
    const sweepRad = -150.0 * math.pi / 180.0;

    final orbitRect = Rect.fromCircle(center: pivot, radius: orbitRadius);
    canvas.drawArc(orbitRect, -startRad, -sweepRad, false, orbitPaint);
    final innerChronometerRadius = orbitRadius * 0.62;
    final innerRect =
        Rect.fromCircle(center: pivot, radius: innerChronometerRadius);

    canvas.drawArc(
      innerRect,
      -startRad,
      -sweepRad,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 0.8,
    );
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    const int totalTicks = 36;
    for (int t = 0; t <= totalTicks; t++) {
      final tickAngleDeg = 165.0 - t * (150.0 / totalTicks);
      final tickAngleRad = tickAngleDeg * math.pi / 180.0;
      final isMajor = t % 6 == 0;
      final tickLength = isMajor ? 5.0 : 2.5;

      final tX1 = pivot.dx + math.cos(tickAngleRad) * innerChronometerRadius;
      final tY1 = pivot.dy - math.sin(tickAngleRad) * innerChronometerRadius;
      final tX2 = pivot.dx +
          math.cos(tickAngleRad) * (innerChronometerRadius - tickLength);
      final tY2 = pivot.dy -
          math.sin(tickAngleRad) * (innerChronometerRadius - tickLength);

      tickPaint
        ..strokeWidth = isMajor ? 1.0 : 0.6
        ..color = isMajor
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.10);

      canvas.drawLine(Offset(tX1, tY1), Offset(tX2, tY2), tickPaint);
    }
    for (int i = 0; i < 6; i++) {
      final pAngle = (165.0 - i * 30.0) * math.pi / 180.0;
      final sX = pivot.dx + math.cos(pAngle) * (innerChronometerRadius + 2);
      final sY = pivot.dy - math.sin(pAngle) * (innerChronometerRadius + 2);
      final eX = pivot.dx + math.cos(pAngle) * (orbitRadius - 28);
      final eY = pivot.dy - math.sin(pAngle) * (orbitRadius - 28);

      canvas.drawLine(
        Offset(sX, sY),
        Offset(eX, eY),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..strokeWidth = 0.6,
      );
    }
    final targetRadius = orbitRadius;
    final tipX = pivot.dx + math.cos(needleAngle) * targetRadius;
    final tipY = pivot.dy - math.sin(needleAngle) * targetRadius;
    canvas.drawLine(
      Offset(pivot.dx, pivot.dy + 3),
      Offset(tipX, tipY + 3),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.50)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      pivot,
      Offset(tipX, tipY),
      Paint()
        ..color = interpolatedColor.withValues(alpha: 0.45)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      pivot,
      Offset(tipX, tipY),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            interpolatedColor,
          ],
          stops: const [0.15, 0.95],
        ).createShader(Rect.fromPoints(pivot, Offset(tipX, tipY)))
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(tipX, tipY),
      5.5,
      Paint()
        ..color = interpolatedColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(
      Offset(tipX, tipY),
      3.8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    canvas.drawCircle(
      Offset(tipX, tipY),
      1.8,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CelestialOrreryPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.interpolatedColor != interpolatedColor ||
      oldDelegate.needleAngle != needleAngle;
}

class _CentralCorePainter extends CustomPainter {
  final Offset pivot;
  final Color interpolatedColor;

  const _CentralCorePainter({
    required this.pivot,
    required this.interpolatedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double coreRadius = 38.0;
    canvas.drawCircle(
      pivot,
      coreRadius + 5,
      Paint()
        ..color = interpolatedColor.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      pivot,
      coreRadius,
      Paint()
        ..color = interpolatedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(
      pivot,
      coreRadius - 1.2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.3),
          radius: 0.9,
          colors: [
            Color(0xFF192734),
            Color(0xFF0C141C),
            Color(0xFF03070A),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: pivot, radius: coreRadius)),
    );
    final glossPath = Path()
      ..addArc(
        Rect.fromCircle(center: pivot, radius: coreRadius - 3.0),
        math.pi * 0.9,
        math.pi * 0.7,
      );
    canvas.drawPath(
      glossPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawCircle(
      pivot,
      12.0,
      Paint()
        ..color = interpolatedColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      pivot,
      3.6,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CentralCorePainter oldDelegate) =>
      oldDelegate.interpolatedColor != interpolatedColor;
}

class _PlanetaryRingPainter extends CustomPainter {
  final bool isFront;
  final double activeAmount;
  final Color glowColor;
  final Color primaryColor;
  final double animValue;

  const _PlanetaryRingPainter({
    required this.isFront,
    required this.activeAmount,
    required this.glowColor,
    required this.primaryColor,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.50);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-22.0 * math.pi / 180.0);

    final ringRadiusX = size.width * 0.48;
    final ringRadiusY = size.height * 0.20;

    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: ringRadiusX * 2,
      height: ringRadiusY * 2,
    );

    final startAngle = isFront ? 0.0 : math.pi;
    const sweepAngle = math.pi;

    if (activeAmount > 0.05) {
      canvas.drawArc(
        ringRect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = glowColor.withValues(alpha: 0.40 * activeAmount)
          ..strokeWidth = 4.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawArc(
      ringRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.lerp(
          Colors.white.withValues(alpha: isFront ? 0.30 : 0.14),
          primaryColor.withValues(alpha: isFront ? 0.90 : 0.45),
          activeAmount,
        )!
        ..strokeWidth = 1.0 + 0.9 * activeAmount,
    );

    if (activeAmount > 0.2) {
      final moonAngle = animValue * 2 * math.pi;
      final isMoonInFront = math.sin(moonAngle) >= 0;
      if (isMoonInFront == isFront) {
        final moonX = math.cos(moonAngle) * ringRadiusX;
        final moonY = math.sin(moonAngle) * ringRadiusY;
        canvas.drawCircle(
          Offset(moonX, moonY),
          2.2,
          Paint()
            ..color = Colors.white
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanetaryRingPainter oldDelegate) =>
      oldDelegate.activeAmount != activeAmount ||
      oldDelegate.animValue != animValue ||
      oldDelegate.primaryColor != primaryColor;
}
