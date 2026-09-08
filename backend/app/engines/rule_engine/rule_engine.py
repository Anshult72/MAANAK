from typing import List, Dict, Any, Optional
from app.engines.rule_engine.condition_evaluator import condition_evaluator
from app.repositories import get_repository

class RuleEngine:
    async def get_applicable_rules(self, context: Dict[str, Any]) -> List[Dict[str, Any]]:
        repo = get_repository()
        inspection_date = context.get("inspectionDate") or "2026-09-08T00:00:00Z"
        
        active_versions = await repo.get_active_versions_for_date(inspection_date)
        applicable = []

        for v in active_versions:
            conditions = v.get("conditions", {})
            is_matched = condition_evaluator.evaluate_group(conditions, context)
            if is_matched:
                applicable.append(v)

        return applicable

    def determine_required_declarations(
        self,
        applicable_rules: List[Dict[str, Any]],
        context: Dict[str, Any]
    ) -> Dict[str, Dict[str, Any]]:
        """
        Returns a dict of required declarations with applicability reasons.
        e.g. {"country_of_origin": {"required": True, "reason": "Imported product"}}
        """
        requirements = {
            "commodity_name": {"required": True, "reason": "Mandatory under Rule 6(1)(a)"},
            "net_quantity": {"required": True, "reason": "Mandatory under Rule 6(1)(b)"},
            "mrp": {"required": True, "reason": "Mandatory retail sale price under Rule 6(1)(c)"},
            "manufacturer_name": {"required": True, "reason": "Mandatory manufacturer identity under Rule 6(1)(d)"},
            "manufacturer_address": {"required": True, "reason": "Mandatory complete address under Rule 6(1)(d) & Rule 10"},
            "manufacturing_date": {"required": True, "reason": "Mandatory manufacturing/packing date under Rule 6(1)(e)"},
            "consumer_care": {"required": True, "reason": "Mandatory consumer grievance contact under Rule 6(1)(g)"}
        }

        # Conditional declarations
        is_imported = context.get("isImported", False)
        if is_imported:
            requirements["country_of_origin"] = {"required": True, "reason": "Mandatory for imported commodities under Rule 6(1)(f)"}
            requirements["importer_name"] = {"required": True, "reason": "Mandatory importer identity under Rule 6(1)(d)"}
            requirements["importer_address"] = {"required": True, "reason": "Mandatory importer address under Rule 6(1)(d)"}
        else:
            requirements["country_of_origin"] = {"required": False, "reason": "Not applicable for domestic commodities"}
            requirements["importer_name"] = {"required": False, "reason": "Not applicable for domestic commodities"}
            requirements["importer_address"] = {"required": False, "reason": "Not applicable for domestic commodities"}

        if context.get("bestBeforeApplicable", False):
            requirements["best_before"] = {"required": True, "reason": "Applicable for perishable or sensitive commodities"}
        else:
            requirements["best_before"] = {"required": False, "reason": "Best before not mandated for this category"}

        if context.get("dimensionsRelevant", False):
            requirements["dimensions"] = {"required": True, "reason": "Mandated when size/dimensions are relevant to consumer"}
        else:
            requirements["dimensions"] = {"required": False, "reason": "Dimensions not applicable"}

        if context.get("unitSalePriceApplicable", False):
            requirements["unit_sale_price"] = {"required": True, "reason": "Mandatory unit sale price under amended rules"}
        else:
            requirements["unit_sale_price"] = {"required": False, "reason": "Unit sale price not applicable for this packaging"}

        return requirements

rule_engine = RuleEngine()
