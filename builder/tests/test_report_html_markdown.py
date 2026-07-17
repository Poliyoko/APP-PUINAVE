from sgoda.cli.main import main


def test_html_converts_inline_markdown(tmp_path, capsys) -> None:
    reports = tmp_path / "reports"

    assert main([
        "init",
        str(tmp_path / "project"),
        "--project-name",
        "HTML Semántico",
    ]) == 0
    capsys.readouterr()

    assert main([
        "report",
        str(tmp_path / "project"),
        "--format",
        "html",
        "--output",
        str(reports),
    ]) == 0
    capsys.readouterr()

    content = (reports / "executive-report.html").read_text(encoding="utf-8")

    assert "<strong>Proyecto:</strong> HTML Semántico" in content
    assert "<strong>Builder:</strong> 1.8.0" in content
    assert "<strong>Estado general:</strong> <strong>HEALTHY</strong>" in content
    assert "<strong>LOW — INFORMATION_FINDINGS:</strong>" in content
    assert "**Proyecto:**" not in content
    assert "**Builder:**" not in content


def test_html_converts_inline_code(tmp_path, capsys) -> None:
    reports = tmp_path / "reports"

    assert main([
        "init",
        str(tmp_path / "project"),
        "--project-name",
        "Código HTML",
    ]) == 0
    capsys.readouterr()

    assert main([
        "report",
        str(tmp_path / "project"),
        "--format",
        "html",
        "--output",
        str(reports),
    ]) == 0
    capsys.readouterr()

    content = (reports / "executive-report.html").read_text(encoding="utf-8")

    assert "<code>" in content
    assert "`" not in content
