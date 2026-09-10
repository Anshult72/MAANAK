from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

class ConditionEvaluator:
    @staticmethod
    def _parse_date(val: Any) -> Optional[datetime]:
        if isinstance(val, datetime):
            if val.tzinfo is None:
                return val.replace(tzinfo=timezone.utc)
            return val
        if isinstance(val, str):
            try:
                cleaned = val.replace("Z", "+00:00")
                if len(cleaned) == 10:  # e.g. '2027-07-01'
                    dt = datetime.fromisoformat(cleaned)
                    return dt.replace(tzinfo=timezone.utc)
                dt = datetime.fromisoformat(cleaned)
                if dt.tzinfo is None:
                    return dt.replace(tzinfo=timezone.utc)
                return dt
            except Exception:
                pass
        return None

    @classmethod
    def evaluate_condition(cls, condition: Any, context: Dict[str, Any]) -> bool:
        if not isinstance(condition, dict) or not isinstance(context, dict):
            return False
        field = condition.get("field")
        op = (condition.get("operator") or "EQUALS").upper()
        target_val = condition.get("value")

        actual_val = context.get(field)

        # Handle existence operators
        if op == "EXISTS":
            return actual_val is not None
        if op == "NOT_EXISTS":
            return actual_val is None

        if actual_val is None and op not in ["NOT_EQUALS", "NOT_IN"]:
            return False

        # Date handling
        actual_date = cls._parse_date(actual_val)
        target_date = cls._parse_date(target_val)
        if actual_date and target_date:
            if op == "EQUALS":
                return actual_date == target_date
            if op == "NOT_EQUALS":
                return actual_date != target_date
            if op == "GREATER_THAN":
                return actual_date > target_date
            if op == "GREATER_THAN_OR_EQUAL":
                return actual_date >= target_date
            if op == "LESS_THAN":
                return actual_date < target_date
            if op == "LESS_THAN_OR_EQUAL":
                return actual_date <= target_date

        # String / Numeric / Boolean comparisons
        if op == "EQUALS":
            if isinstance(actual_val, str) and isinstance(target_val, str):
                return actual_val.lower() == target_val.lower()
            return actual_val == target_val

        if op == "NOT_EQUALS":
            if isinstance(actual_val, str) and isinstance(target_val, str):
                return actual_val.lower() != target_val.lower()
            return actual_val != target_val

        if op == "GREATER_THAN":
            try:
                return float(actual_val) > float(target_val)
            except Exception:
                return str(actual_val) > str(target_val)

        if op == "GREATER_THAN_OR_EQUAL":
            try:
                return float(actual_val) >= float(target_val)
            except Exception:
                return str(actual_val) >= str(target_val)

        if op == "LESS_THAN":
            try:
                return float(actual_val) < float(target_val)
            except Exception:
                return str(actual_val) < str(target_val)

        if op == "LESS_THAN_OR_EQUAL":
            try:
                return float(actual_val) <= float(target_val)
            except Exception:
                return str(actual_val) <= str(target_val)

        if op == "IN":
            if isinstance(target_val, list):
                return actual_val in target_val
            return False

        if op == "NOT_IN":
            if isinstance(target_val, list):
                return actual_val not in target_val
            return True

        return False

    @classmethod
    def evaluate_group(cls, condition_group: Any, context: Dict[str, Any]) -> bool:
        if not condition_group:
            return True
        if isinstance(condition_group, list):
            results = [cls.evaluate_condition(c, context) for c in condition_group if isinstance(c, dict)]
            return all(results) if results else True
        if not isinstance(condition_group, dict):
            return True

        group_type = (condition_group.get("conditionGroup") or "ALL").upper()
        conditions = condition_group.get("conditions", [])

        if not conditions or not isinstance(conditions, list):
            return True

        results = [cls.evaluate_condition(c, context) for c in conditions]

        if group_type == "ALL" or group_type == "AND":
            return all(results)
        elif group_type == "ANY" or group_type == "OR":
            return any(results)
        elif group_type == "NOT":
            return not any(results)
        return all(results)

condition_evaluator = ConditionEvaluator()
