import 'package:flutter/material.dart';

/// Records the most recent pointer position without consuming the gesture.
class TapOrigin {
  static Alignment _alignment = Alignment.center;
  static DateTime? _time;
  static void record(Offset position, Size size) {
    if (size.isEmpty) return;
    _alignment = Alignment((position.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (position.dy / size.height * 2 - 1).clamp(-1.0, 1.0));
    _time = DateTime.now();
  }

  static Alignment take() {
    final recent = _time != null &&
        DateTime.now().difference(_time!) < const Duration(seconds: 1);
    _time = null;
    return recent ? _alignment : Alignment.center;
  }
}
