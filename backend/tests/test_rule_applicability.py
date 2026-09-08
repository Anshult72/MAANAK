import pytest
from app.engines.rule_engine.rule_engine import rule_engine
from app.engines.rule_engine.condition_evaluator import condition_evaluator

def test_condition_evaluator_operators():
    # Equals
    assert condition_evaluator.evaluate_condition({"field": "isImported", "operator": "EQUALS", "value": True}, {"isImported": True}) is True
    assert condition_evaluator.evaluate_condition({"field": "isImported", "operator": "EQUALS", "value": True}, {"isImported": False}) is False
    # Not Equals
    assert condition_evaluator.evaluate_condition({"field": "status", "operator": "NOT_EQUALS", "value": "FINALIZED"}, {"status": "DRAFT"}) is True
    # In / Not In
    assert condition_evaluator.evaluate_condition({"field": "role", "operator": "IN", "value": ["ADMIN", "SUPERVISOR"]}, {"role": "ADMIN"}) is True
    assert condition_evaluator.evaluate_condition({"field": "role", "operator": "NOT_IN", "value": ["ADMIN"]}, {"role": "INSPECTOR"}) is True

def test_ecommerce_rule_effective_date_gate():
    # Before 1 July 2027: Condition should fail
    cond = {
        "field": "inspectionDate",
        "operator": "GREATER_THAN_OR_EQUAL",
        "value": "2027-07-01"
    }
    assert condition_evaluator.evaluate_condition(cond, {"inspectionDate": "2026-09-08T00:00:00Z"}) is False
    # On or after 1 July 2027: Condition succeeds
    assert condition_evaluator.evaluate_condition(cond, {"inspectionDate": "2027-07-01T10:00:00Z"}) is True
    assert condition_evaluator.evaluate_condition(cond, {"inspectionDate": "2027-08-15T12:00:00Z"}) is True

def test_declaration_requirements_domestic_vs_imported():
    # Domestic commodity: Country of Origin and Importer NOT required
    req_domestic = rule_engine.determine_required_declarations([], {"isImported": False})
    assert req_domestic["country_of_origin"]["required"] is False
    assert req_domestic["importer_name"]["required"] is False

    # Imported commodity: Country of Origin and Importer ARE required
    req_imported = rule_engine.determine_required_declarations([], {"isImported": True})
    assert req_imported["country_of_origin"]["required"] is True
    assert req_imported["importer_name"]["required"] is True
    assert "imported" in req_imported["country_of_origin"]["reason"].lower()

def test_conditional_declarations_best_before_and_dimensions():
    # When flags are false: not required
    req_off = rule_engine.determine_required_declarations([], {"bestBeforeApplicable": False, "dimensionsRelevant": False})
    assert req_off["best_before"]["required"] is False
    assert req_off["dimensions"]["required"] is False

    # When flags are true: required
    req_on = rule_engine.determine_required_declarations([], {"bestBeforeApplicable": True, "dimensionsRelevant": True})
    assert req_on["best_before"]["required"] is True
    assert req_on["dimensions"]["required"] is True
