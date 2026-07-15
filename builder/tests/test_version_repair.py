from sgoda.cli.main import main
def test_version(capsys):assert main(['version'])==0;assert '1.5.0' in capsys.readouterr().out
