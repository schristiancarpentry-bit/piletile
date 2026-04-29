import 'dart:async';

class TimerManager {
  double _remaining = 0;
  double _slowMoRemaining = 0;
  bool _running = false;
  Timer? _ticker;
  final void Function(double remaining) onTick;
  final void Function() onExpired;

  TimerManager({required this.onTick, required this.onExpired});

  double get remaining => _remaining;
  bool get isRunning => _running;

  void start(double seconds) {
    _remaining = seconds;
    _running = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  void _tick(Timer t) {
    if (!_running) return;
    final speed = _slowMoRemaining > 0 ? 0.25 : 1.0;
    _remaining -= 0.1 * speed;
    if (_slowMoRemaining > 0) _slowMoRemaining -= 0.1;

    onTick(_remaining);

    if (_remaining <= 0) {
      _remaining = 0;
      _running = false;
      _ticker?.cancel();
      onExpired();
    }
  }

  void adjustTime(double delta) {
    _remaining = (_remaining + delta).clamp(0, 9999);
  }

  void applySlowMo(double seconds) {
    _slowMoRemaining = seconds;
  }

  void stop() {
    _running = false;
    _ticker?.cancel();
  }

  void dispose() {
    _ticker?.cancel();
  }
}
