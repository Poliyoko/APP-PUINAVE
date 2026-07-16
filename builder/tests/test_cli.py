"""Pruebas de la interfaz de lÃ­nea de comandos."""
from sgoda.cli.main import main

def test_version_command(capsys):
    assert main(["version"]) == 0
    output = capsys.readouterr().out
    assert "SGODA Project Builder" in output
    assert "1.7.0" in output

def test_init_and_validate_commands(tmp_path):
    assert main(["init",str(tmp_path),"--project-name","SGODA Prueba"]) == 0
    assert (tmp_path/"data"/"json"/"palabras.json").is_file()
    assert main(["validate",str(tmp_path)]) == 0










