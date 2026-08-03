from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.test_evidence import (
    parse_junit_report,
    synchronize_evidence_file,
    write_summary,
)


def _write_xml(
    path: Path,
    *,
    tests: int = 21,
    failures: int = 0,
    errors: int = 0,
    skipped: int = 0,
    time: float = 1.25,
) -> None:
    path.write_text(
        (
            '<testsuites>'
            f'<testsuite tests="{tests}" '
            f'failures="{failures}" '
            f'errors="{errors}" '
            f'skipped="{skipped}" '
            f'time="{time}">'
            '</testsuite>'
            '</testsuites>'
        ),
        encoding="utf-8",
    )


def test_SGD_114F_parses_executed_count(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.executed == 21


def test_SGD_114F_calculates_passed_count(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, tests=21, skipped=1)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.passed == 20


def test_SGD_114F_detects_failures(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, failures=1)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.failures == 1
    assert summary.approved is False


def test_SGD_114F_detects_errors(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, errors=1)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.errors == 1
    assert summary.approved is False


def test_SGD_114F_preserves_duration(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, time=2.75)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.duration_seconds == 2.75


def test_SGD_114F_approves_clean_report(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.approved is True


def test_SGD_114F_writes_json_summary(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    json_path = tmp_path / "summary.json"
    md_path = tmp_path / "summary.md"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    write_summary(summary, json_path, md_path)

    payload = json.loads(
        json_path.read_text(encoding="utf-8")
    )

    assert payload["executed"] == 21


def test_SGD_114F_writes_markdown_summary(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    json_path = tmp_path / "summary.json"
    md_path = tmp_path / "summary.md"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    write_summary(summary, json_path, md_path)

    text = md_path.read_text(encoding="utf-8")

    assert "Ejecutadas: 21" in text
    assert "Resultado: APROBADO" in text


def test_SGD_114F_updates_existing_evidence(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    evidence = tmp_path / "evidence.json"
    evidence.write_text(
        json.dumps(
            {
                "increment_code": "SPT-015",
                "specific_tests": 20,
            }
        ),
        encoding="utf-8",
    )
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    synchronize_evidence_file(
        evidence,
        summary,
    )

    payload = json.loads(
        evidence.read_text(encoding="utf-8")
    )

    assert payload["increment_code"] == "SPT-015"
    assert payload["specific_tests"]["executed"] == 21


def test_SGD_114F_adds_compatibility_count(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    evidence = tmp_path / "evidence.json"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    synchronize_evidence_file(
        evidence,
        summary,
    )

    payload = json.loads(
        evidence.read_text(encoding="utf-8")
    )

    assert payload["specific_tests_count"] == 21


def test_SGD_114F_supports_single_testsuite(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    xml.write_text(
        (
            '<testsuite tests="3" failures="0" '
            'errors="0" skipped="0" time="0.4">'
            '</testsuite>'
        ),
        encoding="utf-8",
    )

    summary = parse_junit_report(
        xml,
        component="TEST",
        scope="specific",
    )

    assert summary.executed == 3
    assert summary.passed == 3


def test_SGD_114F_aggregates_multiple_suites(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    xml.write_text(
        (
            '<testsuites>'
            '<testsuite tests="2" failures="0" '
            'errors="0" skipped="0" time="0.2"/>'
            '<testsuite tests="3" failures="0" '
            'errors="0" skipped="1" time="0.3"/>'
            '</testsuites>'
        ),
        encoding="utf-8",
    )

    summary = parse_junit_report(
        xml,
        component="TEST",
        scope="full",
    )

    assert summary.executed == 5
    assert summary.passed == 4
    assert summary.skipped == 1
    assert summary.duration_seconds == 0.5