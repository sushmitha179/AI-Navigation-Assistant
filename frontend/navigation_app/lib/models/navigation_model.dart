import 'detection_model.dart';

class NavigationModel {
  const NavigationModel({
    required this.action,
    required this.reason,
    required this.priority,
    required this.relevantObject,
    required this.detections,
  });

  final String action;
  final String reason;
  final String priority;
  final String? relevantObject;
  final List<DetectionModel> detections;

  factory NavigationModel.fromJson(Map<String, dynamic> json) {
    final rawDetections = json['detections'] as List<dynamic>? ?? const [];
    return NavigationModel(
      action: json['action'] as String? ?? 'CONTINUE',
      reason: json['reason'] as String? ?? 'No navigation instruction',
      priority: json['priority'] as String? ?? 'LOW',
      relevantObject: json['relevant_object'] as String?,
      detections: rawDetections
          .whereType<Map<String, dynamic>>()
          .map(DetectionModel.fromJson)
          .toList(growable: false),
    );
  }
}
