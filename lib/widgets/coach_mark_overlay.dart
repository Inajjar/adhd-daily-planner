import 'package:flutter/material.dart';

class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.accentColor = const Color(0xFF1D8BF1),
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final Color accentColor;
}

class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  final List<CoachMarkStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _targetReady = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _prepareStep();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _prepareStep() async {
    setState(() => _targetReady = false);

    while (_currentStep < widget.steps.length) {
      final context = widget.steps[_currentStep].targetKey.currentContext;
      if (context != null) {
        break;
      }
      _currentStep += 1;
    }

    if (_currentStep >= widget.steps.length) {
      widget.onComplete();
      return;
    }

    final context = widget.steps[_currentStep].targetKey.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.28,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) {
      setState(() => _targetReady = true);
    }
  }

  Rect? _targetRect() {
    if (!_targetReady) {
      return null;
    }
    final renderBox =
        widget.steps[_currentStep].targetKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }

    final topLeft = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      topLeft.dx - 8,
      topLeft.dy - 8,
      renderBox.size.width + 16,
      renderBox.size.height + 16,
    );
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep += 1);
      _prepareStep();
      return;
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final targetRect = _targetRect();
    final screenHeight = MediaQuery.of(context).size.height;
    final showAbove =
        targetRect != null && targetRect.center.dy > screenHeight * 0.55;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CoachScrimPainter(
                    targetRect: targetRect,
                    accentColor: step.accentColor,
                    pulse: _pulseController.value,
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _next,
                ),
              ),
              if (targetRect != null)
                Positioned(
                  left: 20,
                  right: 20,
                  top: showAbove ? null : targetRect.bottom + 16,
                  bottom: showAbove ? screenHeight - targetRect.top + 16 : null,
                  child: _TooltipCard(
                    step: step,
                    stepIndex: _currentStep + 1,
                    totalSteps: widget.steps.length,
                    isLastStep: _currentStep == widget.steps.length - 1,
                    onNext: _next,
                    onSkip: widget.onSkip,
                    isReady: _targetReady,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLastStep,
    required this.onNext,
    required this.onSkip,
    required this.isReady,
  });

  final CoachMarkStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isReady ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: step.accentColor.withValues(alpha: 0.32),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '$stepIndex of $totalSteps',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!isLastStep)
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: step.accentColor,
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: onNext,
                    child: Text(isLastStep ? 'Got it' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachScrimPainter extends CustomPainter {
  _CoachScrimPainter({
    required this.targetRect,
    required this.accentColor,
    required this.pulse,
  });

  final Rect? targetRect;
  final Color accentColor;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.saveLayer(screen, Paint());
    canvas.drawRect(
      screen,
      Paint()..color = Colors.black.withValues(alpha: 0.74),
    );

    if (targetRect != null) {
      final hole = RRect.fromRectAndRadius(
        targetRect!,
        const Radius.circular(20),
      );
      canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    }
    canvas.restore();

    if (targetRect == null) {
      return;
    }

    final rrect = RRect.fromRectAndRadius(
      targetRect!,
      const Radius.circular(20),
    );
    final glowPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 + (pulse * 4)
          ..color = accentColor.withValues(alpha: 0.20 + (pulse * 0.22))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + pulse * 8);
    canvas.drawRRect(rrect, glowPaint);

    final borderPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accentColor;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CoachScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.pulse != pulse;
  }
}
