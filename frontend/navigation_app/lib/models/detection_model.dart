class DetectionModel {
  const DetectionModel({
    required this.className,
    required this.confidence,
    required this.collisionRisk,
    required this.horizontalPosition,
    this.proximityCategory,
  });

  final String className;
  final double confidence;
  final String collisionRisk;
  final String horizontalPosition;
  final String? proximityCategory;

  factory DetectionModel.fromJson(Map<String, dynamic> json) {
    return DetectionModel(
      className: json['class_name'] as String? ?? 'obstacle',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      collisionRisk: json['collision_risk'] as String? ?? 'LOW',
      horizontalPosition: json['horizontal_position'] as String? ?? 'CENTER',
      proximityCategory: json['proximity_category'] as String?,
    );
  }
}
