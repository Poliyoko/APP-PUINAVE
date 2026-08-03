"""Lector robusto de reportes JUnit XML."""

from __future__ import annotations

from pathlib import Path
from xml.etree import ElementTree

from .models import TestEvidenceSummary


def _integer(value: str | None) -> int:
    try:
        return int(float(value or "0"))
    except (TypeError, ValueError):
        return 0


def _decimal(value: str | None) -> float:
    try:
        return float(value or "0")
    except (TypeError, ValueError):
        return 0.0


def parse_junit_report(
    path: str | Path,
    *,
    component: str,
    scope: str,
) -> TestEvidenceSummary:
    report = Path(path)
    root = ElementTree.parse(report).getroot()

    suites = (
        [root]
        if root.tag == "testsuite"
        else list(root.findall("testsuite"))
    )

    if not suites:
        suites = list(root.findall(".//testsuite"))

    executed = sum(
        _integer(suite.attrib.get("tests"))
        for suite in suites
    )
    failures = sum(
        _integer(suite.attrib.get("failures"))
        for suite in suites
    )
    errors = sum(
        _integer(suite.attrib.get("errors"))
        for suite in suites
    )
    skipped = sum(
        _integer(
            suite.attrib.get("skipped")
            or suite.attrib.get("disabled")
        )
        for suite in suites
    )
    duration = round(
        sum(
            _decimal(suite.attrib.get("time"))
            for suite in suites
        ),
        4,
    )

    passed = max(
        executed - failures - errors - skipped,
        0,
    )
    approved = (
        executed > 0
        and failures == 0
        and errors == 0
    )

    return TestEvidenceSummary(
        component=component,
        scope=scope,
        executed=executed,
        passed=passed,
        failures=failures,
        errors=errors,
        skipped=skipped,
        duration_seconds=duration,
        approved=approved,
        source_report=str(report),
    )