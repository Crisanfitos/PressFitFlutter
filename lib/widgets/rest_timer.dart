import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pressfit/theme/app_theme.dart';

class RestTimer extends StatefulWidget {
  final VoidCallback onDismiss;
  final ValueChanged<int>? onTimerStop;

  const RestTimer({
    super.key,
    required this.onDismiss,
    this.onTimerStop,
  });

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> with SingleTickerProviderStateMixin {
  int _seconds = 0;
  bool _running = true;
  Timer? _timer;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running && mounted) {
        setState(() => _seconds++);
      }
    });
  }

  void _togglePause() {
    setState(() => _running = !_running);
  }

  void _stop() {
    _timer?.cancel();
    widget.onTimerStop?.call(_seconds);
    _dismiss();
  }

  Future<void> _dismiss() async {
    await _slideController.reverse();
    widget.onDismiss();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.timer, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Descanso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                const Spacer(),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close, size: 22, color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Timer display
            Text(
              _formatTime(_seconds),
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pause/Play
                GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withAlpha(80)),
                    ),
                    child: Icon(
                      _running ? Icons.pause : Icons.play_arrow,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Stop
                GestureDetector(
                  onTap: _stop,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.error.withAlpha(80)),
                    ),
                    child: const Icon(Icons.stop, color: AppColors.error, size: 28),
                  ),
                ),
              ],
            ),

            // Quick time presets
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [30, 60, 90, 120, 180].map((secs) {
                return GestureDetector(
                  onTap: () => setState(() {
                    _seconds = secs;
                    _running = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatTime(secs),
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
