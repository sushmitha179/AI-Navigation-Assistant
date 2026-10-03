import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/models/navigation_model.dart';

void main() {
  group('NavigationModel JSON Parsing', () {
    test('validates response structure - all required fields present', () {
      final validJson = {
        'action': 'CONTINUE',
        'reason': 'No detected obstacles',
        'priority': 'LOW',
        'relevant_object': null,
        'detections': []
      };

      final model = NavigationModel.fromJson(validJson);
      expect(model.action, 'CONTINUE');
      expect(model.reason, 'No detected obstacles');
      expect(model.priority, 'LOW');
      expect(model.detections, isEmpty);
    });

    test('handles missing action field with default', () {
      final invalidJson = {
        'reason': 'No action',
        'priority': 'LOW',
        'detections': []
      };

      final model = NavigationModel.fromJson(invalidJson);
      expect(model.action, 'CONTINUE'); // Default value
    });

    test('handles missing reason field with default', () {
      final invalidJson = {
        'action': 'STOP',
        'priority': 'HIGH',
        'detections': []
      };

      final model = NavigationModel.fromJson(invalidJson);
      expect(model.reason, 'No navigation instruction'); // Default value
    });

    test('handles missing priority field with default', () {
      final invalidJson = {
        'action': 'CONTINUE',
        'reason': 'No priority',
        'detections': []
      };

      final model = NavigationModel.fromJson(invalidJson);
      expect(model.priority, 'LOW'); // Default value
    });

    test('handles missing detections field with empty list', () {
      final invalidJson = {
        'action': 'CONTINUE',
        'reason': 'No detections',
        'priority': 'LOW'
      };

      final model = NavigationModel.fromJson(invalidJson);
      expect(model.detections, isEmpty);
    });

    test('provides defaults for optional fields', () {
      final minimalJson = {
        'action': 'STOP',
        'reason': 'Obstacle ahead',
        'priority': 'HIGH',
        'detections': []
      };

      final model = NavigationModel.fromJson(minimalJson);
      expect(model.relevantObject, isNull);
    });

    test('parses detection array with valid detection', () {
      final jsonWithDetections = {
        'action': 'CAUTION / SLOW DOWN',
        'reason': 'Person close ahead',
        'priority': 'MEDIUM',
        'relevant_object': 'person',
        'detections': [
          {
            'class_name': 'person',
            'bbox': [100, 100, 200, 200],
            'confidence': 0.9,
            'proximity_category': 'CLOSE',
            'collision_risk': 'MEDIUM',
            'horizontal_position': 'CENTER'
          }
        ]
      };

      final model = NavigationModel.fromJson(jsonWithDetections);
      expect(model.detections.length, 1);
      expect(model.detections[0].className, 'person');
    });

    test('handles mixed valid and invalid detections', () {
      final jsonWithMixedDetections = {
        'action': 'CONTINUE',
        'reason': 'Mixed detections',
        'priority': 'LOW',
        'detections': [
          {
            'class_name': 'person',
            'bbox': [100, 100, 200, 200],
            'confidence': 0.9
          },
          'invalid_detection_string',
          null,
          {
            'class_name': 'car',
            'bbox': [300, 300, 400, 400],
            'confidence': 0.8
          }
        ]
      };

      final model = NavigationModel.fromJson(jsonWithMixedDetections);
      expect(model.detections.length, 2); // Only valid Map detections
    });

    test('handles CONTINUE action', () {
      final json = {
        'action': 'CONTINUE',
        'reason': 'Clear path',
        'priority': 'LOW',
        'detections': []
      };

      final model = NavigationModel.fromJson(json);
      expect(model.action, 'CONTINUE');
    });

    test('handles STOP action', () {
      final json = {
        'action': 'STOP',
        'reason': 'Immediate danger',
        'priority': 'HIGH',
        'relevant_object': 'wall',
        'detections': []
      };

      final model = NavigationModel.fromJson(json);
      expect(model.action, 'STOP');
      expect(model.relevantObject, 'wall');
    });

    test('handles MOVE LEFT action', () {
      final json = {
        'action': 'MOVE LEFT',
        'reason': 'Obstacle on right',
        'priority': 'MEDIUM',
        'detections': []
      };

      final model = NavigationModel.fromJson(json);
      expect(model.action, 'MOVE LEFT');
    });

    test('handles MOVE RIGHT action', () {
      final json = {
        'action': 'MOVE RIGHT',
        'reason': 'Obstacle on left',
        'priority': 'MEDIUM',
        'detections': []
      };

      final model = NavigationModel.fromJson(json);
      expect(model.action, 'MOVE RIGHT');
    });

    test('handles CAUTION / SLOW DOWN action', () {
      final json = {
        'action': 'CAUTION / SLOW DOWN',
        'reason': 'Approaching obstacle',
        'priority': 'MEDIUM',
        'detections': []
      };

      final model = NavigationModel.fromJson(json);
      expect(model.action, 'CAUTION / SLOW DOWN');
    });
  });
}
