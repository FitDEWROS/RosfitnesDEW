import 'dart:async';
import 'dart:convert';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepsService {
  static const _baseKey = 'steps_base';
  static const _baseDateKey = 'steps_base_date';
  static const _lastCounterKey = 'steps_last_counter';
  static const _lastValueKey = 'steps_today';
  static const _seedKey = 'steps_seed';
  static const _seedDateKey = 'steps_seed_date';
  static const _historyKey = 'steps_history';

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

  Future<bool> resetForNewDayIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final baseDate = prefs.getString(_baseDateKey);
    if (baseDate == today) return false;

    final lastValue = prefs.getInt(_lastValueKey);
    if (baseDate != null && lastValue != null && lastValue >= 0) {
      await _storeHistory(prefs, baseDate, lastValue);
    }

    await prefs.setString(_baseDateKey, today);
    await prefs.setInt(_seedKey, 0);
    await prefs.setString(_seedDateKey, today);
    await prefs.setInt(_lastValueKey, 0);
    await prefs.remove(_baseKey);
    return true;
  }

  Future<List<StepsRollover>> getPendingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = _readHistory(prefs);
    final keys = history.keys.toList()..sort();
    return keys
        .map((key) => StepsRollover(key, history[key] ?? 0))
        .toList();
  }

  Future<void> markHistorySent(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final history = _readHistory(prefs);
    if (!history.containsKey(date)) return;
    history.remove(date);
    await _saveHistory(prefs, history);
  }

  Future<void> seedStepsForToday(int steps) async {
    if (steps < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    await prefs.setInt(_seedKey, steps);
    await prefs.setString(_seedDateKey, today);
    await prefs.setInt(_lastValueKey, steps);
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
    final lastValue = prefs.getInt(_lastValueKey);
    final seedDate = prefs.getString(_seedDateKey);
    final seedValue = prefs.getInt(_seedKey);

    if (base == null || baseDate != today) {
      if (baseDate != null && baseDate != today && lastValue != null && lastValue >= 0) {
        await _storeHistory(prefs, baseDate, lastValue);
      }
      int? seed;
      if (seedDate == today && seedValue != null && seedValue >= 0) {
        seed = seedValue;
      } else if (lastValue != null && lastValue >= 0) {
        seed = lastValue;
      }
      if (seed != null) {
        base = counter - seed;
        if (base < 0) base = counter;
      } else {
        base = counter;
      }
      baseDate = today;
    } else if (lastCounter != null && counter < lastCounter) {
      if (lastValue != null && lastValue >= 0) {
        base = counter - lastValue;
        if (base < 0) base = counter;
      } else {
        base = counter;
      }
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

  Map<String, int> _readHistory(SharedPreferences prefs) {
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      final result = <String, int>{};
      data.forEach((key, value) {
        final date = key?.toString();
        if (date == null || date.length < 10) return;
        final numValue = value is num ? value.toInt() : int.tryParse('$value');
        if (numValue == null || numValue < 0) return;
        result[date] = numValue;
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveHistory(
    SharedPreferences prefs,
    Map<String, int> history,
  ) async {
    if (history.length > 31) {
      final keys = history.keys.toList()..sort();
      while (keys.length > 31) {
        history.remove(keys.first);
        keys.removeAt(0);
      }
    }
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> _storeHistory(
    SharedPreferences prefs,
    String date,
    int steps,
  ) async {
    if (steps < 0) return;
    final history = _readHistory(prefs);
    final existing = history[date];
    if (existing == null || steps > existing) {
      history[date] = steps;
      await _saveHistory(prefs, history);
    }
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class StepsRollover {
  final String date;
  final int steps;
  const StepsRollover(this.date, this.steps);
}
