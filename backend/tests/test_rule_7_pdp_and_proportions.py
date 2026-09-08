import pytest
from app.services.vision.pdp_measurement_service import (
    pdp_measurement_service, CalibrationStatus
)

def test_rule_7_table_1_exact_ranges():
    # Range 1: A <= 50 cm2
    h1_norm, r1 = pdp_measurement_service.resolve_rule_7_threshold(45.0, "NORMAL")
    assert h1_norm == 1.0
    assert r1 == "A_LE_50"
    h1_blown, _ = pdp_measurement_service.resolve_rule_7_threshold(45.0, "BLOWN_FORMED_MOLDED")
    assert h1_blown == 2.0

    # Range 2: 50 < A <= 100 cm2
    h2_norm, r2 = pdp_measurement_service.resolve_rule_7_threshold(80.0, "NORMAL")
    assert h2_norm == 1.5
    assert r2 == "50_LT_A_LE_100"
    h2_blown, _ = pdp_measurement_service.resolve_rule_7_threshold(80.0, "BLOWN_FORMED_MOLDED")
    assert h2_blown == 3.0

    # Range 3: 100 < A <= 500 cm2 (Strictly 2.5 mm normal, not 2.0 mm!)
    h3_norm, r3 = pdp_measurement_service.resolve_rule_7_threshold(300.0, "NORMAL")
    assert h3_norm == 2.5
    assert r3 == "100_LT_A_LE_500"
    h3_blown, _ = pdp_measurement_service.resolve_rule_7_threshold(300.0, "BLOWN_FORMED_MOLDED")
    assert h3_blown == 4.0

    # Range 4: 500 < A <= 2500 cm2
    h4_norm, r4 = pdp_measurement_service.resolve_rule_7_threshold(1000.0, "NORMAL")
    assert h4_norm == 4.0
    assert r4 == "500_LT_A_LE_2500"
    h4_blown, _ = pdp_measurement_service.resolve_rule_7_threshold(1000.0, "BLOWN_FORMED_MOLDED")
    assert h4_blown == 6.0

    # Range 5: A > 2500 cm2
    h5_norm, r5 = pdp_measurement_service.resolve_rule_7_threshold(3000.0, "NORMAL")
    assert h5_norm == 6.0
    assert r5 == "GT_2500"

def test_uncalibrated_status_yields_unverified():
    # If not calibrated, never fabricate mm!
    eval_uncalib = pdp_measurement_service.evaluate_character_dimensions(
        char_pixel_height=50.0,
        char_pixel_width=25.0,
        pixels_per_mm=None,
        calibration_status=CalibrationStatus.NOT_CALIBRATED,
        required_min_height_mm=2.5,
        character_str="5"
    )
    assert eval_uncalib["height_status"] == "UNVERIFIED"
    assert eval_uncalib["measured_height_mm"] is None
    assert "calibration required" in eval_uncalib["explanation"].lower()

def test_character_width_proportion_requirement():
    # Calibrated: 2 px/mm. Height = 6 px = 3.0 mm (pass against 2.5 mm).
    # Width = 1.0 px -> ratio = 1/6 = 0.166 < 0.333 (fail proportion check)
    eval_narrow = pdp_measurement_service.evaluate_character_dimensions(
        char_pixel_height=6.0,
        char_pixel_width=1.0,
        pixels_per_mm=2.0,
        calibration_status=CalibrationStatus.CALIBRATED,
        required_min_height_mm=2.5,
        character_str="B"
    )
    assert eval_narrow["height_status"] == "PASS"
    assert eval_narrow["proportion_status"] == "POTENTIAL_VIOLATION"
    assert "1/3" in eval_narrow["explanation"]

def test_character_proportion_exemptions():
    # Numeral '1' and letters 'i', 'I', 'l' are exempt from 1/3 proportion
    for exempt_char in ["1", "i", "I", "l"]:
        eval_exempt = pdp_measurement_service.evaluate_character_dimensions(
            char_pixel_height=6.0,
            char_pixel_width=1.0,
            pixels_per_mm=2.0,
            calibration_status=CalibrationStatus.CALIBRATED,
            required_min_height_mm=2.5,
            character_str=exempt_char
        )
        assert eval_exempt["proportion_status"] == "PASS"
        assert "exempt" in eval_exempt["explanation"].lower()

def test_known_distance_scale_derivation():
    # Point1 at (0, 0), Point2 at (300, 0) => 300 px
    # Known distance = 150 mm => 300 / 150 = 2.0 px/mm
    px_per_mm, status, conf = pdp_measurement_service.derive_scale_from_known_distance(
        point1={"x": 0, "y": 0},
        point2={"x": 300, "y": 0},
        known_distance_mm=150.0
    )
    assert px_per_mm == 2.0
    assert status == CalibrationStatus.CALIBRATED
    assert conf >= 0.90
