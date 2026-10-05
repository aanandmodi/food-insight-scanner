import 'dart:ui';
import 'package:flutter/widgets.dart';

/// Local QA diagnostics only: no food, account or conversation content.
void installQaFrameMetrics(void Function(String) output) {
  final builds = <int>[];
  final rasters = <int>[];
  final refreshRate =
      PlatformDispatcher.instance.views.first.display.refreshRate;
  final budget = (1000000 / (refreshRate > 0 ? refreshRate : 60)).round();
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final frame in timings) {
      builds.add(frame.buildDuration.inMicroseconds);
      rasters.add(frame.rasterDuration.inMicroseconds);
    }
    if (builds.length < 100) return;
    builds.sort();
    rasters.sort();
    final index = ((builds.length - 1) * .95).round();
    output('QA_FRAME_METRICS frames=${builds.length} budget_us=$budget '
        'build_p95_us=${builds[index]} raster_p95_us=${rasters[index]} '
        'build_over_budget=${builds.where((value) => value > budget).length} '
        'raster_over_budget=${rasters.where((value) => value > budget).length}');
    builds.clear();
    rasters.clear();
  });
}
