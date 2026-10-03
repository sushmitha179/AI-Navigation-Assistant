import unittest

from collision_risk import CollisionRisk, HorizontalPosition
from navigation_engine import NavigationDecisionEngine


class TestNavigationDecisionEngine(unittest.TestCase):
    def setUp(self):
        self.engine = NavigationDecisionEngine()

    @staticmethod
    def obstacle(name, risk, position, proximity=None):
        return {
            "class_name": name,
            "collision_risk": risk,
            "horizontal_position": position,
            "proximity_category": proximity,
        }

    def test_no_obstacles(self):
        result = self.engine.decide([])
        self.assertEqual(result["action"], "CONTINUE")
        self.assertIsNone(result["relevant_object"])

    def test_high_center_stops(self):
        result = self.engine.decide([self.obstacle("person", CollisionRisk.HIGH, HorizontalPosition.CENTER, "VERY CLOSE")])
        self.assertEqual(result, {
            "action": "STOP",
            "reason": "person very close ahead",
            "priority": "HIGH",
            "relevant_object": "person",
        })

    def test_high_left_moves_right(self):
        result = self.engine.decide([self.obstacle("car", CollisionRisk.HIGH, HorizontalPosition.LEFT)])
        self.assertEqual(result["action"], "MOVE RIGHT")
        self.assertEqual(result["priority"], "HIGH")

    def test_high_right_moves_left(self):
        result = self.engine.decide([self.obstacle("car", CollisionRisk.HIGH, HorizontalPosition.RIGHT)])
        self.assertEqual(result["action"], "MOVE LEFT")

    def test_medium_center_cautions(self):
        result = self.engine.decide([self.obstacle("chair", CollisionRisk.MEDIUM, HorizontalPosition.CENTER)])
        self.assertEqual(result["action"], "CAUTION / SLOW DOWN")
        self.assertEqual(result["priority"], "MEDIUM")

    def test_medium_left_moves_right(self):
        result = self.engine.decide([self.obstacle("person", CollisionRisk.MEDIUM, HorizontalPosition.LEFT)])
        self.assertEqual(result["action"], "MOVE RIGHT")

    def test_medium_right_moves_left(self):
        result = self.engine.decide([self.obstacle("person", CollisionRisk.MEDIUM, HorizontalPosition.RIGHT)])
        self.assertEqual(result["action"], "MOVE LEFT")

    def test_low_continues(self):
        result = self.engine.decide([self.obstacle("bench", CollisionRisk.LOW, HorizontalPosition.CENTER)])
        self.assertEqual(result["action"], "CONTINUE")

    def test_far_continues(self):
        result = self.engine.decide([self.obstacle("car", CollisionRisk.LOW, HorizontalPosition.CENTER, "FAR")])
        self.assertEqual(result["action"], "CONTINUE")

    def test_highest_risk_is_selected(self):
        result = self.engine.decide([
            self.obstacle("chair", CollisionRisk.LOW, HorizontalPosition.CENTER),
            self.obstacle("person", CollisionRisk.HIGH, HorizontalPosition.LEFT, "VERY CLOSE"),
            self.obstacle("car", CollisionRisk.LOW, HorizontalPosition.RIGHT),
        ])
        self.assertEqual(result["action"], "MOVE RIGHT")
        self.assertEqual(result["priority"], "HIGH")
        self.assertEqual(result["relevant_object"], "person")

    def test_different_sides_use_highest_obstacle(self):
        result = self.engine.decide([
            self.obstacle("person", CollisionRisk.MEDIUM, HorizontalPosition.LEFT),
            self.obstacle("chair", CollisionRisk.LOW, HorizontalPosition.RIGHT),
        ])
        self.assertEqual(result["action"], "MOVE RIGHT")
        self.assertEqual(result["relevant_object"], "person")

    def test_conflicting_side_obstacles_stop(self):
        result = self.engine.decide([
            self.obstacle("person", CollisionRisk.HIGH, HorizontalPosition.LEFT),
            self.obstacle("car", CollisionRisk.HIGH, HorizontalPosition.RIGHT),
        ])
        self.assertEqual(result["action"], "STOP")
        self.assertEqual(result["priority"], "HIGH")
        self.assertEqual(result["relevant_object"], "multiple obstacles")

    def test_accepts_perception_result_dictionary(self):
        result = self.engine.decide({
            "detections": [self.obstacle("person", CollisionRisk.MEDIUM, HorizontalPosition.CENTER)]
        })
        self.assertEqual(result["action"], "CAUTION / SLOW DOWN")


if __name__ == "__main__":
    unittest.main()
