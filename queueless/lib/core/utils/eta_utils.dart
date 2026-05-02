import 'dart:math' as math;

class NonLinearEtaConfig {
  final double prepMinutes;
  final double unitMinutes;
  final double sigma;

  const NonLinearEtaConfig({
    required this.prepMinutes,
    required this.unitMinutes,
    required this.sigma,
  });

  factory NonLinearEtaConfig.fromAvgServiceSeconds(int avgServiceSeconds) {
    final avgMinutes = _clamp((avgServiceSeconds <= 0 ? 480 : avgServiceSeconds) / 60, 2, 180);
    final prepMinutes = _clamp(avgMinutes * 0.32, 1, 24);
    final unitMinutes = _clamp(avgMinutes - prepMinutes, 1, 120);
    return NonLinearEtaConfig(
      prepMinutes: prepMinutes,
      unitMinutes: unitMinutes,
      sigma: 0.42,
    );
  }

  static double _clamp(num value, num min, num max) {
    return math.min(max.toDouble(), math.max(min.toDouble(), value.toDouble()));
  }
}

class NonLinearEtaRange {
  final int minMinutes;
  final int maxMinutes;

  const NonLinearEtaRange({required this.minMinutes, required this.maxMinutes});

  String get label {
    if (maxMinutes <= 0) return '<1 min';
    if (minMinutes <= 0) return '1 - $maxMinutes min';
    if (minMinutes == maxMinutes) return '$minMinutes min';
    return '$minMinutes - $maxMinutes min';
  }

  int get midpointSeconds => (((minMinutes + maxMinutes) / 2) * 60).round();
}

class NonLinearEtaCalculator {
  static int equivalentUnits({
    required int itemCount,
    required int durationMinutes,
    required NonLinearEtaConfig config,
  }) {
    if (itemCount > 0) return itemCount;
    if (durationMinutes > 0) {
      return math.max(1, (durationMinutes / math.max(config.unitMinutes, 1)).round());
    }
    return 1;
  }

  static NonLinearEtaRange estimateServiceRange({
    required int unitCount,
    required NonLinearEtaConfig config,
  }) {
    final safeUnits = math.max(1, unitCount);
    final fasterSigma = math.min(0.95, config.sigma + 0.12);
    final slowerSigma = math.max(0.05, config.sigma - 0.10);
    final contextBuffer = math.max(1, (config.prepMinutes * 0.25).round());

    final minMinutes = _roundMinutes(
      config.prepMinutes + (config.unitMinutes * _dampedWorkload(safeUnits, fasterSigma)),
    );
    final maxMinutes = math.max(
      minMinutes,
      _roundMinutes(
        config.prepMinutes + (config.unitMinutes * _dampedWorkload(safeUnits, slowerSigma)) + contextBuffer,
      ),
    );

    return NonLinearEtaRange(minMinutes: minMinutes, maxMinutes: maxMinutes);
  }

  static NonLinearEtaRange estimateAggregateRange({
    required Iterable<int> unitCounts,
    required NonLinearEtaConfig config,
  }) {
    var minMinutes = 0;
    var maxMinutes = 0;
    for (final unitCount in unitCounts) {
      final range = estimateServiceRange(unitCount: math.max(1, unitCount), config: config);
      minMinutes += range.minMinutes;
      maxMinutes += range.maxMinutes;
    }
    return NonLinearEtaRange(minMinutes: minMinutes, maxMinutes: maxMinutes);
  }

  static double _dampedWorkload(int unitCount, double sigma) {
    var total = 0.0;
    for (var index = 1; index <= unitCount; index += 1) {
      total += 1 / math.pow(index, sigma);
    }
    return total;
  }

  static int _roundMinutes(double value) {
    if (!value.isFinite || value <= 0) return 0;
    return math.max(1, value.round());
  }
}

NonLinearEtaRange estimateNonlinearEtaRange({required int unitCount, required int avgServiceSeconds}) {
  return NonLinearEtaCalculator.estimateServiceRange(
    unitCount: math.max(0, unitCount),
    config: NonLinearEtaConfig.fromAvgServiceSeconds(avgServiceSeconds),
  );
}