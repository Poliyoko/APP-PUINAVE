# EstÃ¡ndar UTF-8 del Repositorio SGODA-PUINAVE

## Identificador

SPB-005.3 â€” UTF-8 Repository Standard

## Objetivo

Garantizar que el cÃ³digo fuente, los scripts, la documentaciÃ³n, los datos, la configuraciÃ³n y los artefactos del PMO Digital utilicen UTF-8 de forma consistente.

## Reglas obligatorias

1. Los archivos de texto del repositorio deben almacenarse en UTF-8.
2. El cÃ³digo fuente y los scripts deben usar UTF-8 sin BOM.
3. Python debe leer y escribir texto indicando `encoding="utf-8"`.
4. PowerShell debe usar funciones basadas en `System.IO.File` con `UTF8Encoding($false)` cuando se requiera comportamiento uniforme entre versiones.
5. No se permite introducir caracteres de reemplazo `ï¿½`.
6. No se permite introducir secuencias de mojibake como `Ãƒ`, `Ã‚`, `Ã¢â‚¬â„¢`, `Ã¢â‚¬Å“` o `Ã¢â‚¬`.
7. La auditorÃ­a UTF-8 debe ejecutarse antes del cierre de entregables y antes de releases.
8. Los archivos binarios quedan excluidos de la normalizaciÃ³n textual.

## Lectura y escritura en Python

```python
from pathlib import Path

text = Path("archivo.md").read_text(encoding="utf-8")
Path("salida.md").write_text(text, encoding="utf-8")
```

## Lectura y escritura en PowerShell

```powershell
$content = [System.IO.File]::ReadAllText(
    $Path,
    [System.Text.Encoding]::UTF8
)

[System.IO.File]::WriteAllText(
    $Path,
    $content,
    [System.Text.UTF8Encoding]::new($false)
)
```

## Evidencias

La auditorÃ­a genera inventario, resumen JSON, informe Markdown y listado de incidencias bajo:

`artifacts/pmo/SPB-005.3-UTF8-REPOSITORY-STANDARD/`