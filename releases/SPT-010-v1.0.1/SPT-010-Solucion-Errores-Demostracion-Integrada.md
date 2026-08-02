# SPT-010 — Solución de errores de la demostración integrada

**Proyecto:** SGODA-PUINAVE  
**Componente:** SPT-010 v1.0.0 — Plataforma Digital Integrada  
**Fase:** Fase Tecnológica II  
**Tipo de documento:** Diagnóstico, corrección y validación técnica  
**Estado inicial:** Instalación parcial con error en la demostración integrada  
**Estado objetivo:** Ejecución completa, pruebas aprobadas, gobernanza aprobada y publicación institucional

---

## 1. Antecedentes

Durante la ejecución del instalador:

```powershell
.\Install-SPT010-v1.0.0-Integrated-Digital-Platform.ps1
```

se completaron correctamente las siguientes actividades:

- creación de los módulos de la plataforma;
- creación de configuración y documentación;
- validación de sintaxis;
- ejecución de 12 pruebas específicas;
- ejecución de la suite completa;
- aprobación de 310 pruebas.

La ejecución falló posteriormente en la etapa:

```text
==> Ejecutando demostración integrada
==> Consultando la Plataforma Digital Integrada
```

El error fue:

```text
json.decoder.JSONDecodeError:
Expecting property name enclosed in double quotes:
line 1 column 2 (char 1)
```

El traceback ubicó el fallo en:

```text
src/sgoda/platform/cli.py
```

específicamente en:

```python
payload = json.loads(args.payload)
```

---

## 2. Diagnóstico

### 2.1 Componente afectado

```text
src/sgoda/platform/cli.py
```

### 2.2 Punto de entrada afectado

```text
python -m sgoda.platform.cli
```

### 2.3 Parámetro afectado

```text
--payload
```

### 2.4 Causa raíz

El instalador envía el contenido del parámetro `--payload` desde PowerShell:

```powershell
--payload '{"message":"Quiero aprender esta palabra"}'
```

La cadena no llegó al proceso Python en un formato JSON válido para `json.loads()`.

El problema no corresponde a:

- los modelos de SPT-010;
- la fachada integrada;
- el registro de capacidades;
- los motores SPT-007C, SPT-007D, SPT-008 o SPT-009;
- la suite de pruebas;
- SGD-114C;
- SGD-115;
- SGD-116.

El fallo está limitado a la transferencia de una cadena JSON entre PowerShell y la CLI de Python.

---

## 3. Solución definitiva

La corrección debe aplicarse en:

```text
src/sgoda/platform/cli.py
```

La CLI debe aceptar:

1. JSON válido estándar;
2. JSON que llegue con comillas simples por efecto del shell;
3. JSON escapado;
4. un archivo JSON opcional para evitar problemas de interpretación del shell.

### 3.1 Función de carga segura

Incorporar la siguiente función después de los imports:

```python
def _load_payload(
    raw_payload: str,
    payload_file: str | None = None,
) -> dict:
    if payload_file:
        payload_path = Path(payload_file)

        if not payload_path.is_file():
            raise ValueError(
                f"No se encontró el archivo de payload: {payload_path}"
            )

        raw_payload = payload_path.read_text(
            encoding="utf-8-sig"
        )

    candidates = [
        raw_payload,
        raw_payload.replace('\\"', '"'),
        raw_payload.replace("'", '"'),
        raw_payload.replace('\\"', '"').replace("'", '"'),
    ]

    last_error: json.JSONDecodeError | None = None

    for candidate in candidates:
        try:
            payload = json.loads(candidate)

            if not isinstance(payload, dict):
                raise ValueError(
                    "El payload debe ser un objeto JSON."
                )

            return payload

        except json.JSONDecodeError as error:
            last_error = error

    raise ValueError(
        "El payload no contiene JSON válido."
    ) from last_error
```

### 3.2 Nuevo argumento opcional

Agregar al analizador de argumentos:

```python
parser.add_argument("--payload-file")
```

### 3.3 Reemplazo de la carga actual

Reemplazar:

```python
payload = json.loads(args.payload)
```

por:

```python
payload = _load_payload(
    args.payload,
    args.payload_file,
)
```

---

## 4. Corrección recomendada para el script PowerShell

Aunque la CLI quedará protegida, el medio más estable para Windows PowerShell es utilizar un archivo JSON temporal.

En el instalador, reemplazar la invocación directa del payload por:

```powershell
$DemoPayloadPath = Join-Path `
    $ArtifactsDir `
    "demo-platform-payload.json"

Write-Json $DemoPayloadPath ([ordered]@{
    message = "Quiero aprender esta palabra"
})

Run-Checked "Consultando la Plataforma Digital Integrada" {
    python -m sgoda.platform.cli `
        --graph "$DemoGraphPath" `
        --operation "conversation" `
        --payload "{}" `
        --payload-file "$DemoPayloadPath" `
        --session "DEMO-001" `
        --language "es" `
        --node "LEX-001" `
        --output "$DemoResultPath" `
        --root "$ProjectRoot"
}
```

Esta modalidad evita que PowerShell transforme las comillas internas del JSON.

---

## 5. Aplicación directa mediante PowerShell

Desde la raíz del repositorio:

```powershell
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Path = ".\src\sgoda\platform\cli.py"
$Backup = ".\artifacts\pmo\SPT-010\cli-backup-" +
    (Get-Date -Format "yyyyMMdd-HHmmss") +
    ".py"

New-Item `
    -ItemType Directory `
    -Path (Split-Path $Backup -Parent) `
    -Force | Out-Null

Copy-Item `
    -LiteralPath $Path `
    -Destination $Backup `
    -Force

Write-Host "Respaldo: $Backup" -ForegroundColor Cyan
```

Después de editar `cli.py`, ejecutar:

```powershell
python -m py_compile `
    .\src\sgoda\platform\cli.py

if ($LASTEXITCODE -ne 0) {
    throw "La compilación de cli.py falló."
}
```

---

## 6. Pruebas que deben agregarse

Agregar pruebas al archivo:

```text
tests/platform/test_SPT_010_integrated_digital_platform.py
```

### 6.1 JSON estándar

```python
def test_SPT_010_loads_standard_json_payload():
    from sgoda.platform.cli import _load_payload

    assert _load_payload(
        '{"message":"Quiero aprender"}'
    ) == {
        "message": "Quiero aprender"
    }
```

### 6.2 JSON con comillas simples

```python
def test_SPT_010_repairs_single_quoted_payload():
    from sgoda.platform.cli import _load_payload

    assert _load_payload(
        "{'message':'Quiero aprender'}"
    ) == {
        "message": "Quiero aprender"
    }
```

### 6.3 Payload desde archivo

```python
def test_SPT_010_loads_payload_file(
    tmp_path,
):
    from sgoda.platform.cli import _load_payload

    path = tmp_path / "payload.json"
    path.write_text(
        '{"message":"AMDA"}',
        encoding="utf-8",
    )

    assert _load_payload(
        "{}",
        str(path),
    ) == {
        "message": "AMDA"
    }
```

### 6.4 Rechazo de listas

```python
def test_SPT_010_rejects_non_object_payload():
    from sgoda.platform.cli import _load_payload

    try:
        _load_payload("[1, 2, 3]")
    except ValueError:
        pass
    else:
        raise AssertionError(
            "La CLI aceptó un payload que no es objeto."
        )
```

### 6.5 Rechazo de contenido inválido

```python
def test_SPT_010_rejects_invalid_payload():
    from sgoda.platform.cli import _load_payload

    try:
        _load_payload("{invalid}")
    except ValueError:
        pass
    else:
        raise AssertionError(
            "La CLI aceptó JSON inválido."
        )
```

---

## 7. Secuencia de validación

### 7.1 Compilación

```powershell
python -m py_compile `
    .\src\sgoda\platform\cli.py
```

### 7.2 Pruebas específicas

```powershell
pytest `
    .\tests\platform\test_SPT_010_integrated_digital_platform.py `
    -vv
```

### 7.3 Suite completa

```powershell
pytest
```

### 7.4 Prueba manual del archivo de payload

```powershell
$PayloadPath = ".\artifacts\platform\SPT-010\manual-payload.json"

@{
    message = "Quiero aprender esta palabra"
} |
ConvertTo-Json |
Set-Content `
    -LiteralPath $PayloadPath `
    -Encoding UTF8

python -m sgoda.platform.cli `
    --graph ".\artifacts\platform\SPT-010\demo-platform-graph.json" `
    --operation "conversation" `
    --payload "{}" `
    --payload-file $PayloadPath `
    --session "MANUAL-001" `
    --language "es" `
    --node "LEX-001" `
    --output ".\artifacts\platform\SPT-010\manual-result.json" `
    --root "."
```

### 7.5 Verificación del resultado

```powershell
$Result = Get-Content `
    -LiteralPath ".\artifacts\platform\SPT-010\manual-result.json" `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Result |
    Select-Object operation, status, no_invention
```

Resultado esperado:

```text
operation     status no_invention
---------     ------ ------------
conversation  ok     True
```

---

## 8. Reejecución institucional

Una vez corregida y probada la CLI:

```powershell
.\Install-SPT010-v1.0.0-Integrated-Digital-Platform.ps1
```

El proceso debe continuar por:

```text
Demostración integrada
SGD-116
SGD-114C
SGD-115
Evidencia
Release
Resultado final
```

---

## 9. Criterios de aceptación

SPT-010 solo podrá considerarse aprobado cuando se cumpla:

- compilación de `cli.py` aprobada;
- pruebas específicas aprobadas;
- suite completa aprobada;
- demostración integrada aprobada;
- `status = ok`;
- `no_invention = true`;
- SGD-116 aprobado;
- SGD-114C aprobado;
- SGD-115 actualizado;
- evidencia generada;
- release generado;
- publicación SPB-007 aprobada;
- auditoría estricta final aprobada;
- Git limpio.

---

## 10. Publicación institucional

Después del cierre técnico:

```powershell
git status -sb
```

Publicar:

```powershell
.\scripts\Invoke-SPB007-InstitutionalPublish.ps1 `
    -Publish `
    -CommitMessage "fix(platform): harden SPT-010 JSON payload handling" `
    -EvidenceCommitMessage "chore(platform): publish SPT-010 correction evidence"
```

Confirmar:

```powershell
git status -sb
git log --oneline -5
```

Resultado esperado:

```text
Auditoría estricta final: APROBADA
Evidencias posteriores: PUBLICADAS
Git limpio: True
```

---

## 11. Reversión

Si la corrección genera un error:

```powershell
Copy-Item `
    -LiteralPath $Backup `
    -Destination ".\src\sgoda\platform\cli.py" `
    -Force
```

Después:

```powershell
python -m py_compile `
    .\src\sgoda\platform\cli.py
```

La reversión no debe eliminar evidencias ni modificar componentes cerrados.

---

## 12. Conclusión

La suite completa demostró que la arquitectura y los componentes funcionales de SPT-010 estaban operativos. El fallo fue producido exclusivamente por el transporte del argumento JSON desde PowerShell hacia Python.

La solución definitiva consiste en:

1. endurecer la carga del payload en `src/sgoda/platform/cli.py`;
2. admitir un archivo JSON mediante `--payload-file`;
3. utilizar un archivo de payload en el instalador;
4. agregar pruebas específicas de compatibilidad;
5. reejecutar la suite y los gates institucionales.

Esta solución evita nuevos errores de comillas entre Windows PowerShell, PowerShell 7, Linux y los procesos de CI/CD.
