/// Injectable wall-clock so "today" can be fixed in tests instead of reading
/// the real system time.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
