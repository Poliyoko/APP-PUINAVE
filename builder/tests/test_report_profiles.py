import pytest

from sgoda.operations import ReportProfileError, resolve_sections


def test_default_profiles() -> None:
    assert "summary" in resolve_sections("executive")
    assert "resources" in resolve_sections("technical")
    assert "audit" in resolve_sections("audit")


def test_custom_sections_are_normalized() -> None:
    assert resolve_sections(
        "executive",
        ("summary", " history ", "summary"),
    ) == ("summary", "history")


def test_unknown_section_is_rejected() -> None:
    with pytest.raises(ReportProfileError):
        resolve_sections("executive", ("unknown",))
