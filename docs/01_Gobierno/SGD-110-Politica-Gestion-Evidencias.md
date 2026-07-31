# SGD-110 â€” PolÃ­tica de GestiÃ³n de Evidencias

## Estado

Aprobada para implementaciÃ³n.

## Identificador de implementaciÃ³n

**SPB-006-EVIDENCE-GOVERNANCE**

## Objetivo

Establecer las reglas institucionales para conservar, clasificar,
versionar, externalizar y verificar las evidencias generadas por el
PMO Digital del proyecto SGODA-PUINAVE.

## Principio general

El repositorio principal deberÃ¡ contener cÃ³digo fuente, documentaciÃ³n
vigente, pruebas, manifiestos y evidencias consolidadas.

Las copias completas, respaldos, restauraciones, lÃ­neas base,
diagnÃ³sticos extensos y snapshots deberÃ¡n conservarse fuera del
repositorio principal cuando su volumen o duplicaciÃ³n afecte su
mantenibilidad.

## Evidencias que permanecen en Git

DeberÃ¡n permanecer versionados:

- CÃ³digo fuente oficial.
- Pruebas automatizadas.
- Scripts vigentes.
- Decisiones de arquitectura.
- PolÃ­ticas y estÃ¡ndares.
- Informes finales.
- Actas de cierre.
- Manifiestos de implementaciÃ³n.
- Inventarios consolidados.
- ResÃºmenes JSON, CSV o Markdown.
- Referencias a evidencias externas.
- Hashes criptogrÃ¡ficos de los paquetes archivados.

## Evidencias que deberÃ¡n externalizarse

DeberÃ¡n archivarse fuera del repositorio principal:

- Directorios de respaldo.
- Copias completas del repositorio.
- LÃ­neas base voluminosas.
- Restauraciones.
- Snapshots.
- DiagnÃ³sticos histÃ³ricos extensos.
- Instaladores obsoletos.
- Copias previas a parches.
- Duplicados de cÃ³digo ya preservados por Git.

## Requisitos del archivo externo

Cada paquete externo deberÃ¡ incluir:

1. Identificador Ãºnico.
2. Fecha de generaciÃ³n.
3. Commit y tag de origen.
4. Inventario de archivos.
5. TamaÃ±o de cada archivo.
6. Hash SHA-256 de cada archivo.
7. Hash SHA-256 del paquete final.
8. UbicaciÃ³n institucional autorizada.
9. Responsable de custodia.
10. Periodo de conservaciÃ³n.

## ProhibiciÃ³n de reescritura innecesaria

La adopciÃ³n de esta polÃ­tica no exige reescribir commits ni tags
histÃ³ricos previamente publicados.

Los respaldos ya incorporados en versiones oficiales podrÃ¡n
permanecer en el historial como evidencia del estado original.

Su retiro se realizarÃ¡ mediante un commit posterior, sin utilizar
git push --force, salvo autorizaciÃ³n formal y documentada.

## Ubicaciones autorizadas

Las evidencias podrÃ¡n conservarse en:

- Repositorio independiente de auditorÃ­a.
- GitHub Releases.
- Almacenamiento institucional.
- Unidad externa cifrada.
- Sistema documental con control de acceso.
- Servicio de almacenamiento con versionado.

## Integridad

Los paquetes de evidencia deberÃ¡n verificarse mediante SHA-256 antes
y despuÃ©s de cualquier traslado.

Una diferencia de hash deberÃ¡ tratarse como incidente de integridad.

## RetenciÃ³n

Los paquetes asociados con cierres oficiales deberÃ¡n conservarse
durante toda la vigencia del proyecto y segÃºn las disposiciones
institucionales aplicables.

No podrÃ¡n eliminarse sin autorizaciÃ³n formal del responsable del
PMO Digital.

## Responsabilidades

### PMO Digital

- Aprobar la polÃ­tica.
- Mantener la trazabilidad.
- Autorizar eliminaciÃ³n o traslado.
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

## ImplementaciÃ³n inicial

La primera aplicaciÃ³n de esta polÃ­tica corresponde a:

- Entregable: SPB-005.3.
- VersiÃ³n: 1.4.
- Tag: SPB-005.3-v1.4.
- Commit de cierre: ce11985.
- Archivo externo: SGODA-AUDIT-ARCHIVE/SPB-005.3-v1.4.
- Algoritmo de integridad: SHA-256.

## Criterio de conformidad

La transiciÃ³n serÃ¡ conforme cuando:

- el paquete externo exista;
- el manifiesto SHA-256 exista;
- los respaldos dejen de estar rastreados en la rama activa;
- las evidencias consolidadas permanezcan en el repositorio;
- .gitignore impida reincorporaciones accidentales;
- las pruebas y auditorÃ­as continÃºen aprobadas;
- no se haya reescrito el historial publicado.
