from sgoda.operations import calculate_health


def test_health_states() -> None:
    assert calculate_health(errors=1, warnings=0) == "ERROR"
    assert calculate_health(errors=0, warnings=1) == "WARNING"
    assert calculate_health(errors=0, warnings=0) == "HEALTHY"
