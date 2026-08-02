# SPT-003A â€” Arquitectura de colas y eventos

```text
RMR ADR-010
    |
    v
Planificador SPT-003A
    |
    v
Cola multimedia SQLite
    |
    +--> imagen IA
    +--> grabaciÃ³n Puinave
    +--> TTS espaÃ±ol
    +--> TTS inglÃ©s
    |
    v
n8n / trabajadores / proveedores
    |
    v
Eventos de finalizaciÃ³n o fallo
```

La cola separa planificaciÃ³n, ejecuciÃ³n y validaciÃ³n humana. Esto
permite operar desde 80 hasta 120.000 trabajos sin modificar el contrato.