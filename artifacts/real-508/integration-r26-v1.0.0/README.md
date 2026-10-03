# REAL-508 - Integración FastAPI R26

## Estado

R26: CLOSED_VERIFIED

REAL-508: CLOSED_VERIFIED_FROZEN

R25: CLOSED_VERIFIED_FROZEN

## Objetivo

Integrar el contrato REAL-508 validado en R25 con la API operativa
FastAPI existente de SGODA-PUINAVE, sin crear una API paralela ni
duplicar el endpoint léxico.

## Arquitectura validada

API canónica:

src/sgoda/operational_platform/api.py

Endpoint canónico:

GET /lexical/{entry_id}

Operación:

get_lexical_card

La función create_app admite inyección opcional de
OperationalRepository y conserva compatibilidad con la arquitectura
operativa existente.

## Contrato multimedia

Se preservan ambos contratos:

- histórico: media_type / uri
- REAL-508: resource_type / path

La adaptación se realiza en la frontera de presentación sin modificar
el baseline REAL-508 certificado.

## Quality Gate

- R26: 6/6 PASS
- R25: 6/6 PASS
- R22: 15/15 PASS
- SPT-011: 14/14 PASS
- PY_COMPILE: PASS
- API paralela: NO
- endpoint duplicado: NO
- PostgreSQL productivo modificado: NO
- WAV modificados: 0
- MP3 modificados: 0
- AUP3 modificados: 0

## Hashes SHA-256

API:
46A190104C31D65C5381C0EAA1C7835EF9C16E7F5A9531CABA0386FBF07AFF18

Flutter contract:
40C54CD01C48E95E73B61F0A0FE5213CE9B966B20D12455C7B7F427D7756E0C9

Test R26:
DF25FAD3D38169872BA64FF23A0B49D660E45FB149FE5F8C8741F19191615D08

Evidencia R26.3:
AF57C626F6EADB3E0B86F931FAE6696C37857F03827AE46B1573944AF5DF2A76

## Política multimedia

Los WAV, MP3 y proyectos AUP3 permanecen fuera de esta publicación Git.

No se modifica la grafía Puinave.

No se reabre R25.

No se reabre REAL-508.
