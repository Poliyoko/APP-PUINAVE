param(
    [string]$RepositoryRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepositoryRoot = (Resolve-Path $RepositoryRoot).Path
Set-Location $RepositoryRoot

$DeliverableId = "SPB-006-EVIDENCE-GOVERNANCE"
$SourceArtifactRelative = "artifacts/pmo/SPB-005.3-UTF8-REPOSITORY-STANDARD"
$SourceArtifact = Join-Path $RepositoryRoot $SourceArtifactRelative

$RepositoryParent = Split-Path $RepositoryRoot -Parent
$ExternalArchiveRoot = Join-Path $RepositoryParent "SGODA-AUDIT-ARCHIVE"
$ArchivePackageRoot = Join-Path $ExternalArchiveRoot "SPB-005.3-v1.4"
$ArchivePayloadRoot = Join-Path $ArchivePackageRoot "payload"
$ArchiveManifest = Join-Path $ArchivePackageRoot "evidence-manifest.csv"
$ArchiveMetadata = Join-Path $ArchivePackageRoot "archive-metadata.json"
$ArchiveZip = Join-Path $ExternalArchiveRoot "SPB-005.3-v1.4-audit-archive.zip"

$PolicyPath = Join-Path $RepositoryRoot "docs/01_Gobierno/SGD-110-Politica-Gestion-Evidencias.md"
$PointerPath = Join-Path $SourceArtifact "EXTERNAL-EVIDENCE-REFERENCE.md"
$MigrationManifestPath = Join-Path $SourceArtifact "evidence-transition-manifest.json"

$ExternalizedDirectories = @(
    "backups",
    "patch-backups",
    "obsolete-installers"
)

Write-Host ""
Write-Host "====================================================="
Write-Host " SGODA - Implementacion Opcion B"
Write-Host " Gobierno y archivado externo de evidencias"
Write-Host "====================================================="
Write-Host ""

if (-not (Test-Path ".git")) {
    throw "La carpeta actual no es la raiz de un repositorio Git."
}

if (-not (Test-Path $SourceArtifact)) {
    throw "No existe el artefacto esperado: $SourceArtifactRelative"
}

$CurrentBranch = (git branch --show-current).Trim()
$CurrentCommit = (git rev-parse HEAD).Trim()

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible consultar el estado del repositorio."
}

Write-Host "Repositorio : $RepositoryRoot"
Write-Host "Rama        : $CurrentBranch"
Write-Host "Commit base : $CurrentCommit"
Write-Host "Archivo ext.: $ArchivePackageRoot"
Write-Host ""

# ---------------------------------------------------------
# 1. Crear estructura externa
# ---------------------------------------------------------

New-Item -ItemType Directory -Force -Path $ArchivePayloadRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $PolicyPath -Parent) | Out-Null

# ---------------------------------------------------------
# 2. Copiar evidencias voluminosas al archivo externo
# ---------------------------------------------------------

$CopiedDirectories = New-Object System.Collections.Generic.List[string]

foreach ($DirectoryName in $ExternalizedDirectories) {
    $SourceDirectory = Join-Path $SourceArtifact $DirectoryName

    if (Test-Path $SourceDirectory) {
        $DestinationDirectory = Join-Path $ArchivePayloadRoot $DirectoryName

        if (Test-Path $DestinationDirectory) {
            Remove-Item -Recurse -Force $DestinationDirectory
        }

        Copy-Item `
            -Path $SourceDirectory `
            -Destination $DestinationDirectory `
            -Recurse `
            -Force

        $CopiedDirectories.Add($DirectoryName)
        Write-Host "ARCHIVADO: $DirectoryName"
    }
    else {
        Write-Host "NO ENCONTRADO: $DirectoryName"
    }
}

if ($CopiedDirectories.Count -eq 0) {
    throw "No se encontro ninguna carpeta para externalizar."
}

# ---------------------------------------------------------
# 3. Crear manifiesto SHA-256 del archivo externo
# ---------------------------------------------------------

$ManifestRows = Get-ChildItem `
    -Path $ArchivePayloadRoot `
    -Recurse `
    -File |
    Sort-Object FullName |
    ForEach-Object {
        $BasePath = $ArchivePayloadRoot.TrimEnd("\") + "\"
        $FilePath = $_.FullName

        if (-not $FilePath.StartsWith(
            $BasePath,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "El archivo no pertenece al directorio de evidencias: $FilePath"
        }

        $RelativePath = $FilePath.Substring(
            $BasePath.Length
        ).Replace("\", "/")

        $Hash = Get-FileHash `
            -Algorithm SHA256 `
            -LiteralPath $_.FullName

        [PSCustomObject]@{
            relative_path = $RelativePath
            size_bytes    = $_.Length
            sha256        = $Hash.Hash.ToLowerInvariant()
            modified_utc  = $_.LastWriteTimeUtc.ToString("o")
        }
    }

$ManifestRows |
    Export-Csv `
        -LiteralPath $ArchiveManifest `
        -NoTypeInformation `
        -Encoding utf8

$TotalFiles = @($ManifestRows).Count
$TotalBytes = (
    $ManifestRows |
    Measure-Object -Property size_bytes -Sum
).Sum

if ($null -eq $TotalBytes) {
    $TotalBytes = 0
}

# ---------------------------------------------------------
# 4. Crear metadatos del archivo
# ---------------------------------------------------------

$Metadata = [ordered]@{
    identifier              = $DeliverableId
    archive_id              = "SPB-005.3-v1.4-AUDIT-ARCHIVE"
    created_at_utc          = [DateTimeOffset]::UtcNow.ToString("o")
    source_repository       = $RepositoryRoot
    source_branch           = $CurrentBranch
    source_commit           = $CurrentCommit
    source_tag              = "SPB-005.3-v1.4"
    source_artifact         = $SourceArtifactRelative.Replace("\", "/")
    externalized_directories = @($CopiedDirectories)
    files_archived          = $TotalFiles
    total_bytes             = [int64]$TotalBytes
    hash_algorithm          = "SHA-256"
    manifest                = "evidence-manifest.csv"
    history_rewritten       = $false
    local_source_deleted    = $false
    git_tracking_removed    = $true
}

$Metadata |
    ConvertTo-Json -Depth 10 |
    Set-Content `
        -LiteralPath $ArchiveMetadata `
        -Encoding utf8

# ---------------------------------------------------------
# 5. Crear paquete ZIP externo
# ---------------------------------------------------------

if (Test-Path $ArchiveZip) {
    Remove-Item -Force $ArchiveZip
}

Compress-Archive `
    -Path (Join-Path $ArchivePackageRoot "*") `
    -DestinationPath $ArchiveZip `
    -CompressionLevel Optimal

$ArchiveZipHash = (
    Get-FileHash `
        -Algorithm SHA256 `
        -LiteralPath $ArchiveZip
).Hash.ToLowerInvariant()

$ArchiveZipHash |
    Set-Content `
        -LiteralPath "$ArchiveZip.sha256" `
        -Encoding ascii

Write-Host ""
Write-Host "PAQUETE EXTERNO: $ArchiveZip"
Write-Host "SHA-256 ZIP    : $ArchiveZipHash"

# ---------------------------------------------------------
# 6. Actualizar .gitignore
# ---------------------------------------------------------

$GitIgnorePath = Join-Path $RepositoryRoot ".gitignore"

if (-not (Test-Path $GitIgnorePath)) {
    New-Item -ItemType File -Path $GitIgnorePath | Out-Null
}

$GitIgnoreBlock = @"

# =========================================================
# SGODA Evidence Governance - Opcion B
# Evidencias voluminosas conservadas fuera del repositorio
# =========================================================
artifacts/**/backups/
artifacts/**/patch-backups/
artifacts/**/obsolete-installers/
artifacts/**/baseline*/
artifacts/**/baselines/
artifacts/**/restore*/
artifacts/**/restoration*/
artifacts/**/snapshot*/
artifacts/**/_diagnostics/
*.audit-archive.zip
"@

$ExistingGitIgnore = Get-Content `
    -LiteralPath $GitIgnorePath `
    -Raw `
    -ErrorAction SilentlyContinue

if ($ExistingGitIgnore -notmatch "SGODA Evidence Governance - Opcion B") {
    Add-Content `
        -LiteralPath $GitIgnorePath `
        -Value $GitIgnoreBlock `
        -Encoding utf8

    Write-Host "ACTUALIZADO: .gitignore"
}
else {
    Write-Host "SIN CAMBIOS: .gitignore ya contiene la politica."
}

# ---------------------------------------------------------
# 7. Crear política institucional
# ---------------------------------------------------------

$PolicyContent = @"
# SGD-110 — Política de Gestión de Evidencias

## Estado

Aprobada para implementación.

## Identificador de implementación

**$DeliverableId**

## Objetivo

Establecer las reglas institucionales para conservar, clasificar,
versionar, externalizar y verificar las evidencias generadas por el
PMO Digital del proyecto SGODA-PUINAVE.

## Principio general

El repositorio principal deberá contener código fuente, documentación
vigente, pruebas, manifiestos y evidencias consolidadas.

Las copias completas, respaldos, restauraciones, líneas base,
diagnósticos extensos y snapshots deberán conservarse fuera del
repositorio principal cuando su volumen o duplicación afecte su
mantenibilidad.

## Evidencias que permanecen en Git

Deberán permanecer versionados:

- Código fuente oficial.
- Pruebas automatizadas.
- Scripts vigentes.
- Decisiones de arquitectura.
- Políticas y estándares.
- Informes finales.
- Actas de cierre.
- Manifiestos de implementación.
- Inventarios consolidados.
- Resúmenes JSON, CSV o Markdown.
- Referencias a evidencias externas.
- Hashes criptográficos de los paquetes archivados.

## Evidencias que deberán externalizarse

Deberán archivarse fuera del repositorio principal:

- Directorios de respaldo.
- Copias completas del repositorio.
- Líneas base voluminosas.
- Restauraciones.
- Snapshots.
- Diagnósticos históricos extensos.
- Instaladores obsoletos.
- Copias previas a parches.
- Duplicados de código ya preservados por Git.

## Requisitos del archivo externo

Cada paquete externo deberá incluir:

1. Identificador único.
2. Fecha de generación.
3. Commit y tag de origen.
4. Inventario de archivos.
5. Tamaño de cada archivo.
6. Hash SHA-256 de cada archivo.
7. Hash SHA-256 del paquete final.
8. Ubicación institucional autorizada.
9. Responsable de custodia.
10. Periodo de conservación.

## Prohibición de reescritura innecesaria

La adopción de esta política no exige reescribir commits ni tags
históricos previamente publicados.

Los respaldos ya incorporados en versiones oficiales podrán
permanecer en el historial como evidencia del estado original.

Su retiro se realizará mediante un commit posterior, sin utilizar
`git push --force`, salvo autorización formal y documentada.

## Ubicaciones autorizadas

Las evidencias podrán conservarse en:

- Repositorio independiente de auditoría.
- GitHub Releases.
- Almacenamiento institucional.
- Unidad externa cifrada.
- Sistema documental con control de acceso.
- Servicio de almacenamiento con versionado.

## Integridad

Los paquetes de evidencia deberán verificarse mediante SHA-256 antes
y después de cualquier traslado.

Una diferencia de hash deberá tratarse como incidente de integridad.

## Retención

Los paquetes asociados con cierres oficiales deberán conservarse
durante toda la vigencia del proyecto y según las disposiciones
institucionales aplicables.

No podrán eliminarse sin autorización formal del responsable del
PMO Digital.

## Responsabilidades

### PMO Digital

- Aprobar la política.
- Mantener la trazabilidad.
- Autorizar eliminación o traslado.
- Validar informes y actas.

### Auditor del Repositorio

- Verificar integridad.
- Generar manifiestos.
- Confirmar hashes.
- Detectar evidencias faltantes.

### Responsable de custodia

- Mantener la disponibilidad del archivo externo.
- Controlar accesos.
- Conservar copias redundantes.
- Documentar traslados.

## Implementación inicial

La primera aplicación de esta política corresponde a:

- Entregable: SPB-005.3.
- Versión: 1.4.
- Tag: `SPB-005.3-v1.4`.
- Commit de cierre: `ce11985`.
- Archivo externo: `SGODA-AUDIT-ARCHIVE/SPB-005.3-v1.4`.
- Algoritmo de integridad: SHA-256.

## Criterio de conformidad

La transición será conforme cuando:

- el paquete externo exista;
- el manifiesto SHA-256 exista;
- los respaldos dejen de estar rastreados en la rama activa;
- las evidencias consolidadas permanezcan en el repositorio;
- `.gitignore` impida reincorporaciones accidentales;
- las pruebas y auditorías continúen aprobadas;
- no se haya reescrito el historial publicado.
"@

$PolicyContent |
    Set-Content `
        -LiteralPath $PolicyPath `
        -Encoding utf8

Write-Host "CREADO: docs/01_Gobierno/SGD-110-Politica-Gestion-Evidencias.md"

# ---------------------------------------------------------
# 8. Crear referencia externa dentro del artefacto
# ---------------------------------------------------------

$PointerContent = @"
# Referencia de Evidencia Externa — SPB-005.3

## Estado

Los respaldos voluminosos asociados con SPB-005.3 fueron
externalizados conforme a la política SGD-110.

## Fuente histórica

- Commit de cierre: `ce11985`
- Tag oficial: `SPB-005.3-v1.4`
- Rama de transición: `$CurrentBranch`

## Archivo externo

- Carpeta: `SGODA-AUDIT-ARCHIVE/SPB-005.3-v1.4`
- Paquete: `SPB-005.3-v1.4-audit-archive.zip`
- Archivos archivados: $TotalFiles
- Tamaño total en bytes: $TotalBytes
- Algoritmo: SHA-256
- SHA-256 del paquete ZIP: `$ArchiveZipHash`

## Manifiestos

El archivo externo incluye:

- `evidence-manifest.csv`
- `archive-metadata.json`
- `SPB-005.3-v1.4-audit-archive.zip.sha256`

## Alcance externalizado

$(
    ($CopiedDirectories | ForEach-Object { "- ``$_/``" }) -join [Environment]::NewLine
)

## Política aplicable

`docs/01_Gobierno/SGD-110-Politica-Gestion-Evidencias.md`

## Nota de trazabilidad

El historial de Git y el tag oficial no fueron reescritos.

Las copias siguen disponibles en el commit y tag históricos, mientras
que la rama activa adopta un modelo de evidencia consolidada.
"@

$PointerContent |
    Set-Content `
        -LiteralPath $PointerPath `
        -Encoding utf8

# ---------------------------------------------------------
# 9. Crear manifiesto de transición dentro de Git
# ---------------------------------------------------------

$MigrationManifest = [ordered]@{
    identifier               = $DeliverableId
    transition               = "OPTION-B-EXTERNAL-EVIDENCE"
    generated_at_utc         = [DateTimeOffset]::UtcNow.ToString("o")
    repository_branch        = $CurrentBranch
    source_commit            = $CurrentCommit
    protected_closure_commit = "ce11985"
    protected_tag            = "SPB-005.3-v1.4"
    external_archive_name    = "SPB-005.3-v1.4-audit-archive.zip"
    external_archive_sha256  = $ArchiveZipHash
    archived_files           = $TotalFiles
    archived_bytes           = [int64]$TotalBytes
    externalized_directories = @($CopiedDirectories)
    history_rewritten        = $false
    force_push_required      = $false
    local_files_preserved    = $true
}

$MigrationManifest |
    ConvertTo-Json -Depth 10 |
    Set-Content `
        -LiteralPath $MigrationManifestPath `
        -Encoding utf8

# ---------------------------------------------------------
# 10. Retirar respaldos del índice Git
#     --cached: conserva los archivos en el computador
# ---------------------------------------------------------

Write-Host ""
Write-Host "Retirando respaldos del seguimiento de Git..."
Write-Host "Los archivos seguiran existiendo localmente."
Write-Host ""

foreach ($DirectoryName in $CopiedDirectories) {
    $RelativeDirectory = (
        "$SourceArtifactRelative/$DirectoryName"
    ).Replace("\", "/")

    $TrackedFiles = git ls-files -- $RelativeDirectory

    if ($TrackedFiles) {
        git rm `
            -r `
            --cached `
            --ignore-unmatch `
            -- $RelativeDirectory

        if ($LASTEXITCODE -ne 0) {
            throw "Fallo al retirar del indice: $RelativeDirectory"
        }

        Write-Host "DESVINCULADO DE GIT: $RelativeDirectory"
    }
    else {
        Write-Host "NO RASTREADO: $RelativeDirectory"
    }
}

# ---------------------------------------------------------
# 11. Agregar evidencia consolidada
# ---------------------------------------------------------

git add `
    .gitignore `
    "docs/01_Gobierno/SGD-110-Politica-Gestion-Evidencias.md" `
    "$SourceArtifactRelative/EXTERNAL-EVIDENCE-REFERENCE.md" `
    "$SourceArtifactRelative/evidence-transition-manifest.json"

if ($LASTEXITCODE -ne 0) {
    throw "No fue posible preparar los documentos de la migracion."
}

# ---------------------------------------------------------
# 12. Verificaciones
# ---------------------------------------------------------

$RemainingTracked = New-Object System.Collections.Generic.List[string]

foreach ($DirectoryName in $CopiedDirectories) {
    $RelativeDirectory = (
        "$SourceArtifactRelative/$DirectoryName"
    ).Replace("\", "/")

    $Tracked = git ls-files -- $RelativeDirectory

    if ($Tracked) {
        $RemainingTracked.Add($RelativeDirectory)
    }
}

if ($RemainingTracked.Count -gt 0) {
    throw "Aun existen directorios externalizados bajo seguimiento Git: $($RemainingTracked -join ', ')"
}

if (-not (Test-Path $ArchiveManifest)) {
    throw "No se genero el manifiesto externo."
}

if (-not (Test-Path $ArchiveZip)) {
    throw "No se genero el paquete ZIP externo."
}

Write-Host ""
Write-Host "====================================================="
Write-Host " TRANSICION COMPLETADA"
Write-Host "====================================================="
Write-Host "Archivos archivados : $TotalFiles"
Write-Host "Bytes archivados    : $TotalBytes"
Write-Host "ZIP externo         : $ArchiveZip"
Write-Host "SHA-256             : $ArchiveZipHash"
Write-Host "Historial reescrito : No"
Write-Host "Archivos locales    : Conservados"
Write-Host ""
Write-Host "Cambios preparados en Git:"
git status --short
