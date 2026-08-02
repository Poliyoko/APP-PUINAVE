<#
.SYNOPSIS
    Instala y valida SPT-001B-P01, P02 y P03 para SGODA-PUINAVE.

.DESCRIPTION
    Este instalador consolida los comandos que ya fueron ejecutados
    correctamente en el equipo del proyecto. Es idempotente:
    puede ejecutarse nuevamente sin duplicar dependencias ni escribir
    fuera del repositorio.

    Componentes:
      - P01: schema_loader.py
      - P02: profile_models.py
      - P03: excel_reader.py
      - Validación de openpyxl
      - Validación de importaciones
      - Ejecución de pytest

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.
    Por defecto, usa la carpeta desde la cual se ejecuta el script.

.PARAMETER SkipPytest
    Omite la ejecución de pytest.

.PARAMETER Force
    Sobrescribe los tres archivos aunque ya existan.

.EXAMPLE
    .\Install-SPT001B-P01-P03.ps1

.EXAMPLE
    .\Install-SPT001B-P01-P03.ps1 -ProjectRoot "C:\Ruta\SGODA-PUINAVE"
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipPytest,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content,
        [switch]$Overwrite
    )

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $Path) -and -not $Overwrite) {
        Write-Host "Se conserva archivo existente: $Path" -ForegroundColor Yellow
        return
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear el archivo: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado correctamente: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

Write-Step "Validando repositorio"

Assert-Path -Path $ProjectRoot -Description "la raíz del proyecto"

$SrcRoot = Join-Path $ProjectRoot "src"
$RlbDir = Join-Path $SrcRoot "sgoda\rlb"
$SchemaPath = Join-Path $ProjectRoot "config\rlb\schema-v1.json"
$PytestIni = Join-Path $ProjectRoot "pytest.ini"

Assert-Path -Path $SrcRoot -Description "la carpeta src"
Assert-Path -Path (Join-Path $RlbDir "schema.py") -Description "schema.py de SPT-001A"
Assert-Path -Path (Join-Path $RlbDir "models.py") -Description "models.py de SPT-001A"
Assert-Path -Path $SchemaPath -Description "schema-v1.json"
Assert-Path -Path $PytestIni -Description "pytest.ini"

Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = $SrcRoot

Write-Host "Repositorio: $ProjectRoot" -ForegroundColor Green
Write-Host "PYTHONPATH: $env:PYTHONPATH" -ForegroundColor Green

Write-Step "Validando Python y openpyxl"

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible en la sesión actual."
}

& python -c "import openpyxl; print('openpyxl', openpyxl.__version__)"
if ($LASTEXITCODE -ne 0) {
    Write-Host "openpyxl no está disponible. Se instalará." -ForegroundColor Yellow
    & python -m pip install "openpyxl>=3.1,<4.0"

    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible instalar openpyxl."
    }
}

$SchemaLoader = @'
"""Carga del esquema versionado del Repositorio Léxico Base."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .schema import CampoEsquema, EsquemaRLB


class ErrorEsquemaRLB(ValueError):
    """Error de configuración del esquema institucional del RLB."""


def cargar_esquema(ruta: str | Path) -> EsquemaRLB:
    """Carga un esquema JSON y crea el contrato de mapeo."""

    ruta_esquema = Path(ruta)

    if not ruta_esquema.is_file():
        raise FileNotFoundError(
            f"No se encontró el esquema RLB: {ruta_esquema}"
        )

    try:
        contenido: dict[str, Any] = json.loads(
            ruta_esquema.read_text(encoding="utf-8")
        )
    except json.JSONDecodeError as error:
        raise ErrorEsquemaRLB(
            f"El esquema RLB no contiene JSON válido: {error}"
        ) from error

    version = str(contenido.get("version") or "").strip()
    campos_json = contenido.get("fields")

    if not version:
        raise ErrorEsquemaRLB(
            "El esquema RLB debe declarar una versión."
        )

    if not isinstance(campos_json, list) or not campos_json:
        raise ErrorEsquemaRLB(
            "El esquema RLB debe declarar una lista de campos."
        )

    campos: list[CampoEsquema] = []

    for posicion, campo_json in enumerate(campos_json, start=1):
        if not isinstance(campo_json, dict):
            raise ErrorEsquemaRLB(
                f"El campo {posicion} no es un objeto."
            )

        nombre = str(campo_json.get("name") or "").strip()

        if not nombre:
            raise ErrorEsquemaRLB(
                f"El campo {posicion} no tiene nombre."
            )

        aliases = campo_json.get("aliases", [])

        if not isinstance(aliases, list):
            raise ErrorEsquemaRLB(
                f"Los aliases de {nombre!r} deben ser una lista."
            )

        campos.append(
            CampoEsquema(
                nombre_canonico=nombre,
                aliases=tuple(str(alias) for alias in aliases),
                obligatorio=bool(campo_json.get("required", False)),
            )
        )

    return EsquemaRLB(version=version, campos=campos)
'@

$ProfileModels = @'
"""Modelos del perfil técnico del Repositorio Léxico Base."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(slots=True)
class PerfilHojaRLB:
    """Resultado del análisis estructural de una hoja Excel."""

    nombre: str
    fila_encabezado: int | None
    total_filas_fisicas: int
    total_columnas_fisicas: int
    total_registros: int = 0
    total_registros_validos: int = 0
    total_registros_con_errores: int = 0
    columnas: list[str] = field(default_factory=list)
    columnas_reconocidas: list[str] = field(default_factory=list)
    columnas_desconocidas: list[str] = field(default_factory=list)
    columnas_vacias: list[str] = field(default_factory=list)
    errores: list[str] = field(default_factory=list)


@dataclass(slots=True)
class PerfilRepositorioRLB:
    """Perfil integral del archivo Excel institucional."""

    archivo: str
    version_esquema: str
    total_hojas: int
    total_registros: int = 0
    total_registros_validos: int = 0
    total_registros_con_errores: int = 0
    hojas: list[PerfilHojaRLB] = field(default_factory=list)
    advertencias: list[str] = field(default_factory=list)
'@

$ExcelReader = @'
"""Lectura segura y trazable del Repositorio Léxico Base en Excel."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

from openpyxl import load_workbook

from .models import RegistroLexico
from .profile_models import PerfilHojaRLB, PerfilRepositorioRLB
from .schema import EsquemaRLB


@dataclass(slots=True)
class ErrorFilaRLB:
    """Error asociado con una fila concreta del Excel."""

    hoja: str
    fila: int
    mensajes: list[str]


@dataclass(slots=True)
class ResultadoLecturaRLB:
    """Resultado completo de una importación del RLB."""

    registros: list[RegistroLexico] = field(default_factory=list)
    errores: list[ErrorFilaRLB] = field(default_factory=list)
    perfil: PerfilRepositorioRLB | None = None


class LectorExcelRLB:
    """Lector institucional del Repositorio Léxico Base."""

    def __init__(
        self,
        esquema: EsquemaRLB,
        *,
        max_filas_busqueda_encabezado: int = 20,
    ) -> None:
        if max_filas_busqueda_encabezado < 1:
            raise ValueError(
                "max_filas_busqueda_encabezado debe ser mayor que cero."
            )

        self.esquema = esquema
        self.max_filas_busqueda_encabezado = (
            max_filas_busqueda_encabezado
        )

    def leer(
        self,
        ruta_excel: str | Path,
        *,
        hojas: Iterable[str] | None = None,
    ) -> ResultadoLecturaRLB:
        """Lee el Excel y conserva trazabilidad por archivo, hoja y fila."""

        ruta = Path(ruta_excel)

        if not ruta.is_file():
            raise FileNotFoundError(
                f"No se encontró el archivo RLB: {ruta}"
            )

        if ruta.suffix.lower() not in {".xlsx", ".xlsm"}:
            raise ValueError(
                "El RLB debe utilizar formato .xlsx o .xlsm."
            )

        workbook = load_workbook(
            filename=ruta,
            read_only=True,
            data_only=True,
        )

        try:
            nombres_hojas = list(hojas or workbook.sheetnames)

            faltantes = [
                nombre
                for nombre in nombres_hojas
                if nombre not in workbook.sheetnames
            ]

            if faltantes:
                raise ValueError(
                    "No existen las siguientes hojas: "
                    + ", ".join(faltantes)
                )

            perfil = PerfilRepositorioRLB(
                archivo=ruta.name,
                version_esquema=self.esquema.version,
                total_hojas=len(nombres_hojas),
            )

            resultado = ResultadoLecturaRLB(perfil=perfil)

            for nombre_hoja in nombres_hojas:
                hoja = workbook[nombre_hoja]
                perfil_hoja = self._procesar_hoja(
                    hoja=hoja,
                    archivo=ruta.name,
                    resultado=resultado,
                )
                perfil.hojas.append(perfil_hoja)

            perfil.total_registros = sum(
                hoja.total_registros
                for hoja in perfil.hojas
            )
            perfil.total_registros_validos = sum(
                hoja.total_registros_validos
                for hoja in perfil.hojas
            )
            perfil.total_registros_con_errores = sum(
                hoja.total_registros_con_errores
                for hoja in perfil.hojas
            )

            return resultado
        finally:
            workbook.close()

    def _procesar_hoja(
        self,
        *,
        hoja: Any,
        archivo: str,
        resultado: ResultadoLecturaRLB,
    ) -> PerfilHojaRLB:
        fila_encabezado, encabezados = self._detectar_encabezados(hoja)

        perfil = PerfilHojaRLB(
            nombre=hoja.title,
            fila_encabezado=fila_encabezado,
            total_filas_fisicas=hoja.max_row,
            total_columnas_fisicas=hoja.max_column,
        )

        if fila_encabezado is None:
            perfil.errores.append(
                "No fue posible identificar una fila de encabezados."
            )
            return perfil

        perfil.columnas = encabezados

        valores_por_columna = {
            encabezado: 0
            for encabezado in encabezados
        }

        conocidas: set[str] = set()
        desconocidas: set[str] = set()

        for numero_fila, valores in enumerate(
            hoja.iter_rows(
                min_row=fila_encabezado + 1,
                values_only=True,
            ),
            start=fila_encabezado + 1,
        ):
            if self._fila_vacia(valores):
                continue

            fila = {
                encabezado: (
                    valores[indice]
                    if indice < len(valores)
                    else None
                )
                for indice, encabezado in enumerate(encabezados)
            }

            for columna, valor in fila.items():
                if valor not in (None, ""):
                    valores_por_columna[columna] += 1

            mapeo = self.esquema.mapear_fila(
                fila,
                archivo=archivo,
                hoja=hoja.title,
                numero_fila=numero_fila,
            )

            perfil.total_registros += 1
            conocidas.update(mapeo.columnas_reconocidas.keys())
            desconocidas.update(mapeo.columnas_desconocidas)

            if mapeo.errores:
                perfil.total_registros_con_errores += 1
                resultado.errores.append(
                    ErrorFilaRLB(
                        hoja=hoja.title,
                        fila=numero_fila,
                        mensajes=mapeo.errores,
                    )
                )
            else:
                perfil.total_registros_validos += 1

            resultado.registros.append(mapeo.registro)

        perfil.columnas_reconocidas = sorted(conocidas)
        perfil.columnas_desconocidas = sorted(desconocidas)
        perfil.columnas_vacias = sorted(
            columna
            for columna, total in valores_por_columna.items()
            if total == 0
        )

        return perfil

    def _detectar_encabezados(
        self,
        hoja: Any,
    ) -> tuple[int | None, list[str]]:
        mejor_fila = None
        mejores_encabezados: list[str] = []
        mejor_puntaje = 0

        limite = min(
            hoja.max_row,
            self.max_filas_busqueda_encabezado,
        )

        for numero_fila, valores in enumerate(
            hoja.iter_rows(
                min_row=1,
                max_row=limite,
                values_only=True,
            ),
            start=1,
        ):
            encabezados = self._normalizar_encabezados(valores)
            no_vacios = [
                valor
                for valor in encabezados
                if valor.strip()
            ]

            if not no_vacios:
                continue

            puntaje = len(no_vacios)
            terminos = " ".join(no_vacios).lower()

            for termino in (
                "puinave",
                "español",
                "espanol",
                "ingles",
                "inglés",
                "palabra",
                "traduccion",
                "traducción",
            ):
                if termino in terminos:
                    puntaje += 5

            if puntaje > mejor_puntaje:
                mejor_puntaje = puntaje
                mejor_fila = numero_fila
                mejores_encabezados = encabezados

        if mejor_fila is None:
            return None, []

        return (
            mejor_fila,
            self._hacer_encabezados_unicos(mejores_encabezados),
        )

    @staticmethod
    def _normalizar_encabezados(
        valores: tuple[Any, ...],
    ) -> list[str]:
        encabezados = []

        for indice, valor in enumerate(valores, start=1):
            if valor is None or not str(valor).strip():
                encabezados.append(
                    f"columna_sin_nombre_{indice}"
                )
            else:
                encabezados.append(str(valor).strip())

        return encabezados

    @staticmethod
    def _hacer_encabezados_unicos(
        encabezados: list[str],
    ) -> list[str]:
        usados: dict[str, int] = {}
        resultado: list[str] = []

        for encabezado in encabezados:
            total = usados.get(encabezado, 0) + 1
            usados[encabezado] = total

            if total == 1:
                resultado.append(encabezado)
            else:
                resultado.append(
                    f"{encabezado}__{total}"
                )

        return resultado

    @staticmethod
    def _fila_vacia(
        valores: tuple[Any, ...],
    ) -> bool:
        return all(
            valor is None
            or (
                isinstance(valor, str)
                and not valor.strip()
            )
            for valor in valores
        )
'@

Write-Step "Instalando SPT-001B-P01"
Write-Utf8NoBom `
    -Path (Join-Path $RlbDir "schema_loader.py") `
    -Content $SchemaLoader `
    -Overwrite:$Force

Write-Step "Instalando SPT-001B-P02"
Write-Utf8NoBom `
    -Path (Join-Path $RlbDir "profile_models.py") `
    -Content $ProfileModels `
    -Overwrite:$Force

Write-Step "Instalando SPT-001B-P03"
Write-Utf8NoBom `
    -Path (Join-Path $RlbDir "excel_reader.py") `
    -Content $ExcelReader `
    -Overwrite:$Force

Write-Step "Validando importaciones"

& python -c "from sgoda.rlb.schema_loader import cargar_esquema; e=cargar_esquema(r'config/rlb/schema-v1.json'); print('Esquema:', e.version, '- Campos:', len(e.campos))"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la validación de schema_loader.py"
}

& python -c "from sgoda.rlb.profile_models import PerfilHojaRLB, PerfilRepositorioRLB; h=PerfilHojaRLB('Diccionario',1,10,5); p=PerfilRepositorioRLB('RLB.xlsx','1.0.0',1,hojas=[h]); print(p.archivo, p.version_esquema, len(p.hojas))"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la validación de profile_models.py"
}

& python -c "from sgoda.rlb.excel_reader import LectorExcelRLB, ResultadoLecturaRLB; print(LectorExcelRLB.__name__, ResultadoLecturaRLB.__name__)"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la validación de excel_reader.py"
}

if (-not $SkipPytest) {
    Write-Step "Ejecutando la suite completa de pruebas"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite de pruebas terminó con errores."
    }
}
else {
    Write-Host "pytest fue omitido por parámetro." -ForegroundColor Yellow
}

Write-Step "Resultado"

Write-Host "SPT-001B-P01, P02 y P03 instalados y validados." -ForegroundColor Green
Write-Host "Repositorio: $ProjectRoot" -ForegroundColor Green
Write-Host "Siguiente incremento: SPT-001B-P04." -ForegroundColor Cyan
