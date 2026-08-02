# Migración de SGD-114C a SGD-114D

SGD-114C conserva sus reglas generales. SGD-114D reemplaza la resolución
rígida de R003 y R007 por resolución adaptativa.

Los nuevos gates deben ejecutar:

`python -m sgoda.governance.adaptive_policy_cli`

SGD-114D no aprueba directorios vacíos y no crea evidencia ficticia.