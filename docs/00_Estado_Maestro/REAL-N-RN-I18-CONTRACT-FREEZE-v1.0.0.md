# REAL-N RN-I18 - Contract Freeze v1.0.0

## Estado

- Incremento: RN-I18
- Nombre: SPT025_INSTANCE_LIFECYCLE_INTEGRATION_RECERTIFICATION
- Tipo: INTEGRATION_AND_RECERTIFICATION
- Estado: CONTRACT_FROZEN_IMPLEMENTATION_NOT_STARTED
- Baseline de autoridad: b8673e13bdc97e058ec750e24358b441ee078729
- Predecesor: RN-I17 CLOSED_VERIFIED_FROZEN

## Objetivo

Integrar y recertificar el ciclo de vida de instancia ya existente en SPT-025 sobre la plataforma SGODA existente y la baseline runtime RN-I17.

## Fuentes canónicas

- SPT-025.10: registro de instancias.
- SPT-025.11: perfiles y plantillas.
- SPT-025.12: validación.
- SPT-025.13: composición.
- SPT-025.14: materialización declarativa.
- SPT-025.15: publicación controlada.
- SPT-025.16: recertificación.

## Datos y arquitectura

- Dataset: REAL-508.
- Registros certificados: 508.
- Una lengua nativa principal por instancia.
- Idiomas auxiliares configurables: 0..N.
- Estrategia: REUSE_AND_INTEGRATE.

## Prohibiciones

- No crear arquitectura paralela.
- No crear un nuevo FastAPI.
- No rediseñar PostgreSQL.
- No crear un nuevo cliente Flutter.
- No crear otro motor de instancias.
- No reimportar REAL-508.
- No corregir ni normalizar automáticamente la grafía Puinave.
- No desplegar Kurripaco como instancia real.
- No importar multimedia masiva a Git.
- No crear SPT-026.

## Quality Gates

RN-I18 se ejecutará mediante QG01-QG11:
continuidad; fuentes canónicas; registro; perfil/plantilla;
validación; composición; materialización; publicación;
recertificación; seguridad/gobierno; integridad final.

## Deuda controlada

- MMAR: recalibración preservada y no bloqueante para RN-I18.
- Disaster Recovery: restore real todavía no demostrado.
- El restore real deberá resolverse antes del cierre productivo final pertinente.

## Regla de cierre

RN-I18 solo podrá declararse CLOSED_VERIFIED cuando QG01-QG11 estén en PASS y la evidencia de cierre haya sido publicada en el repositorio oficial.
