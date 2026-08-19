class HealthData {
  final int? batteryLevel;
  final int? steps;
  final double? distanceKm;
  final int? calories;
  final List<HeartRateRecord> heartRateHistory;
  final int? currentBPM;
  
  const HealthData({
    this.batteryLevel,
    this.steps,
    this.distanceKm,
    this.calories,
    this.heartRateHistory = const [],
    this.currentBPM,
  });
  
  HealthData copyWith({
    int? batteryLevel,
    int? steps,
    double? distanceKm,
    int? calories,
    List<HeartRateRecord>? heartRateHistory,
    int? currentBPM,
  }) {
    return HealthData(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      steps: steps ?? this.steps,
      distanceKm: distanceKm ?? this.distanceKm,
      calories: calories ?? this.calories,
      heartRateHistory: heartRateHistory ?? this.heartRateHistory,
      currentBPM: currentBPM ?? this.currentBPM,
    );
  }
}

class HeartRateRecord {
  final DateTime timestamp;
  final int bpm;
  
  const HeartRateRecord({
    required this.timestamp,
    required this.bpm,
  });
}
