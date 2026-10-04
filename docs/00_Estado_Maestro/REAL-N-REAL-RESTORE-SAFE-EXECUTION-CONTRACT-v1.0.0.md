# REAL-N — Real Restore Safe Execution Contract v1.0.0

## Estado

- Contrato: FROZEN_READY_FOR_CONTROLLED_EXECUTION
- REAL-N: OPEN
- RN-I18: CLOSED_VERIFIED_FROZEN
- RN-I19 creado: NO
- SPT-026 creado: NO

## Línea base

- Commit: f2d2765590223bf3a71e0d8eb04d9c8207dd745d
- Rama: feature/SPT-001A-rlb-schema-foundation

## Brecha demostrada

- RESTORE_EXECUTED=false.
- No se encontró un backup físico PostgreSQL reutilizable de SGODA.
- La fundación DR existente SPT-024.13 se reutiliza.
- No se crea una arquitectura DR paralela.

## Fuente protegida

- Base productiva: sgoda.
- Tabla léxica de referencia: public.rlb_registro_lexico.
- Línea base: 508 registros.
- DROP productivo: PROHIBIDO.
- overwrite productivo: PROHIBIDO.
- restore sobre sgoda: PROHIBIDO.
- mutación productiva durante esta validación: PROHIBIDA.

## Backup controlado

- Motor: pg_dump.
- Formato: CUSTOM (-Fc).
- Directorio: /var/backups/sgoda-real-restore-validation.
- Archivo: /var/backups/sgoda-real-restore-validation/sgoda-real-restore-validation.dump.
- Ubicación: fuera del repositorio Git.
- SHA-256 obligatorio.
- Validación mediante pg_restore -l obligatoria.

## Restore aislado

- Destino: sgoda_restore_validation.
- Clasificación: ISOLATED_NONPRODUCTION.
- El destino estaba disponible durante PREPARE.
- No se autoriza restauración durante el freeze.
- La eliminación posterior del destino requiere autorización separada.

## Quality Gates de ejecución

1. Guardias previas y continuidad.
2. Backup físico real mediante pg_dump.
3. SHA-256 del backup.
4. Validación de catálogo mediante pg_restore.
5. Evidencia temporal/RPO.
6. Creación del destino aislado.
7. Restore real al destino aislado.
8. Medición real de RTO.
9. Validación de esquema.
10. Validación REAL-508 = 508.
11. Integridad de datos y preservación de producción.

## Umbrales históricos reutilizados

- RPO máximo: 30 minutos.
- RTO máximo: 120 minutos.
- Los valores históricos no se declararán como resultados observados.
- La ejecución real deberá medir y registrar sus propios valores.

## Deuda preservada

- MMAR: PRESERVED_NONBLOCKING_RECALIBRATION.
- No bloquea la validación real de restore.

## Siguiente acción

CONTROLLED_REAL_BACKUP_EXECUTION
