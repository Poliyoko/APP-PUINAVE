# AuditorÃ­a solamente
$env:PYTHONPATH = "src"
python -m sgoda.pmo.utf8.repository_utf8 --root .

# NormalizaciÃ³n con copias de seguridad y evidencias
$env:PYTHONPATH = "src"
python -m sgoda.pmo.utf8.repository_utf8 --root . --apply

# Pruebas
$env:PYTHONPATH = "src"
python -m pytest tests/pmo/utf8/test_repository_utf8.py -q