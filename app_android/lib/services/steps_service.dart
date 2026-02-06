import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepsService {
  static const _baseKey = 'steps_base';
  static const _baseDateKey = 'steps_base_date';
  static const _lastCounterKey = 'steps_last_counter';
  static const _lastValueKey = 'steps_today';

  StreamSubscription<StepCount>? _sub;
  final StreamController<int> _controller = StreamController<int>.broadcast();

  Stream<int> get stepsStream => _controller.stream;

  Future<bool> ensurePermission() async {
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) return true;
    final result = await Permission.activityRecognition.request();
    return result.isGranted;
  }

  Future<int?> loadCachedSteps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastValueKey);
  }

  Future<void> start() async {
    if (_sub != null) return;
    _sub = Pedometer.stepCountStream.listen(_onStepCount, onError: _onError);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final counter = event.steps;

    int? base = prefs.getInt(_baseKey);
    String? baseDate = prefs.getString(_baseDateKey);
    final lastCounter = prefs.getInt(_lastCounterKey);

    if (base == null || baseDate != today) {
      base = counter;
      baseDate = today;
    } else if (lastCounter != null && counter < lastCounter) {
      base = counter;
    }

    int steps = counter - base;
    if (steps < 0) steps = 0;

    final safeDate = baseDate ?? today;
    await prefs.setInt(_baseKey, base);
    await prefs.setString(_baseDateKey, safeDate);
    await prefs.setInt(_lastCounterKey, counter);
    await prefs.setInt(_lastValueKey, steps);

    if (!_controller.isClosed) {
      _controller.add(steps);
    }
  }

  void _onError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
