"""Navigation decisions derived from perception and collision-risk results."""

from enum import Enum
from typing import Any, Dict, Iterable, List, Optional

from collision_risk import CollisionRisk, HorizontalPosition


class NavigationDecisionEngine:
    """Select a safe, actionable navigation decision for detected obstacles."""

    _RISK_PRIORITY = {
        CollisionRisk.HIGH.value: 3,
        CollisionRisk.MEDIUM.value: 2,
        CollisionRisk.LOW.value: 1,
    }

    def decide(self, detections: Iterable[Dict[str, Any]]) -> Dict[str, str]:
        """Return a navigation decision for enriched perception detections.

        ``detections`` may also be the complete result dictionary returned by
        ``PerceptionModule.process_frame``; its ``detections`` value is used.
        """
        if isinstance(detections, dict):
            detections = detections.get("detections", [])

        normalized = [self._normalize_detection(detection) for detection in detections]
        normalized = [detection for detection in normalized if detection is not None]

        if not normalized:
            return {
                "action": "CONTINUE",
                "reason": "No detected obstacles",
                "priority": "LOW",
                "relevant_object": None,
            }

        highest_priority = max(
            self._RISK_PRIORITY[detection["risk"]] for detection in normalized
        )
        relevant = [
            detection
            for detection in normalized
            if self._RISK_PRIORITY[detection["risk"]] == highest_priority
        ]
        highest_risk = relevant[0]["risk"]

        if highest_risk == CollisionRisk.LOW.value:
            return self._decision(
                "CONTINUE",
                "Only low-risk or far obstacles detected",
                highest_risk,
                relevant[0]["object_name"],
            )

        positions = {detection["position"] for detection in relevant}
        if HorizontalPosition.CENTER.value in positions:
            action = "STOP" if highest_risk == CollisionRisk.HIGH.value else "CAUTION / SLOW DOWN"
            return self._decision(
                action,
                self._reason(relevant[0], "ahead"),
                highest_risk,
                relevant[0]["object_name"],
            )

        # A route toward one side is unsafe when a non-low-risk obstacle is
        # already present on that side, so conflicting side hazards stop us.
        all_non_low_positions = {
            detection["position"]
            for detection in normalized
            if detection["risk"] != CollisionRisk.LOW.value
        }
        if {
            HorizontalPosition.LEFT.value,
            HorizontalPosition.RIGHT.value,
        }.issubset(all_non_low_positions):
            return self._decision(
                "STOP",
                "Obstacles on both sides leave no clearly safe direction",
                highest_risk,
                "multiple obstacles",
            )

        position = relevant[0]["position"]
        action = "MOVE RIGHT" if position == HorizontalPosition.LEFT.value else "MOVE LEFT"
        return self._decision(
            action,
            self._reason(relevant[0], position.lower()),
            highest_risk,
            relevant[0]["object_name"],
        )

    def _normalize_detection(self, detection: Dict[str, Any]) -> Optional[Dict[str, str]]:
        risk = self._enum_value(detection.get("collision_risk"))
        position = self._enum_value(detection.get("horizontal_position"))
        if risk not in self._RISK_PRIORITY:
            return None

        if position not in {
            HorizontalPosition.LEFT.value,
            HorizontalPosition.CENTER.value,
            HorizontalPosition.RIGHT.value,
        }:
            position = HorizontalPosition.CENTER.value

        object_name = detection.get("class_name") or detection.get("object_name") or "obstacle"
        proximity = self._enum_value(detection.get("proximity_category"))
        return {
            "risk": risk,
            "position": position,
            "object_name": str(object_name),
            "proximity": proximity,
        }

    @staticmethod
    def _enum_value(value: Any) -> Optional[str]:
        if value is None:
            return None
        value = getattr(value, "value", value)
        return str(value).upper()

    @staticmethod
    def _reason(detection: Dict[str, str], location: str) -> str:
        proximity = detection["proximity"]
        object_name = detection["object_name"]
        if proximity:
            proximity_text = proximity.lower()
            return f"{object_name} {proximity_text} {location}"
        return f"{object_name} presents a {detection['risk'].lower()} collision risk {location}"

    @staticmethod
    def _decision(
        action: str, reason: str, priority: str, relevant_object: Optional[str]
    ) -> Dict[str, Any]:
        return {
            "action": action,
            "reason": reason,
            "priority": priority,
            "relevant_object": relevant_object,
        }


def decide_navigation(detections: Iterable[Dict[str, Any]]) -> Dict[str, Any]:
    """Convenience wrapper for one-off navigation decisions."""
    return NavigationDecisionEngine().decide(detections)


NavigationEngine = NavigationDecisionEngine
