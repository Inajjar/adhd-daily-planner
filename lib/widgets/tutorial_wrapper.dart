import 'package:flutter/material.dart';

import '../services/tutorial_service.dart';
import 'coach_mark_overlay.dart';

class TutorialWrapper extends StatefulWidget {
  const TutorialWrapper({
    super.key,
    required this.tutorialId,
    required this.steps,
    required this.child,
  });

  final String tutorialId;
  final List<CoachMarkStep> steps;
  final Widget child;

  @override
  State<TutorialWrapper> createState() => _TutorialWrapperState();
}

class _TutorialWrapperState extends State<TutorialWrapper> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _checkTutorial() async {
    final seen = await TutorialService.hasSeenTutorial(widget.tutorialId);
    if (seen || !mounted || widget.steps.isEmpty) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }

    final route = ModalRoute.of(context);
    var attempts = 0;
    while (mounted) {
      final isCurrent = route?.isCurrent ?? true;
      if (isCurrent) {
        _showOverlay();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      attempts += 1;
      if (attempts > 80) {
        return;
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      return;
    }
    _overlayEntry = OverlayEntry(
      builder:
          (_) => CoachMarkOverlay(
            steps: widget.steps,
            onComplete: _completeTutorial,
            onSkip: _completeTutorial,
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _completeTutorial() {
    TutorialService.markTutorialSeen(widget.tutorialId);
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
