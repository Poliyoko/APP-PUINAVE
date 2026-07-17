import pytest

from sgoda.extensions import CompatibilityError, requirement_satisfied


def test_compound_builder_requirement() -> None:
    assert requirement_satisfied(">=1.10.0,<2.0.0", "1.10.0")
    assert not requirement_satisfied(">=2.0.0", "1.10.0")


def test_invalid_requirement() -> None:
    with pytest.raises(CompatibilityError):
        requirement_satisfied("^1.10.0", "1.10.0")
