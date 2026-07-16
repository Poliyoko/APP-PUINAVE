from sgoda.cli.main import main


def test_html_report_is_generated(tmp_path, capsys) -> None:
    project = tmp_path / "project"
    reports = tmp_path / "reports"
    assert main(["init", str(project), "--project-name", "HTML"]) == 0
    capsys.readouterr()

    assert main([
        "report",
        str(project),
        "--format",
        "html",
        "--output",
        str(reports),
        "--profile",
        "technical",
    ]) == 0
    capsys.readouterr()

    output = reports / "executive-report.html"
    content = output.read_text(encoding="utf-8")
    assert "<!doctype html>" in content
    assert "Reporte Ejecutivo SGODA" in content
    assert "Ciclo de Vida" in content


def test_custom_sections_limit_output(tmp_path, capsys) -> None:
    assert main(["init", str(tmp_path), "--project-name", "Secciones"]) == 0
    capsys.readouterr()

    assert main([
        "report",
        str(tmp_path),
        "--sections",
        "summary,resources",
    ]) == 0
    output = capsys.readouterr().out

    assert "## Resumen Ejecutivo" in output
    assert "## Recursos" in output
    assert "## Componentes" not in output
