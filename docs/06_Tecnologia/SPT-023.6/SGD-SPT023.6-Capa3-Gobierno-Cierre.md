# SPT-023.6 â€” Orquestador Inteligente â€” Capa 3

## Objetivo

Cerrar funcional e institucionalmente SPT-023.6 incorporando gobierno de
ejecuciÃ³n, reintentos controlados, compensaciÃ³n, auditorÃ­a de eventos,
health gates y certificaciÃ³n final del Orquestador Inteligente.

## Gobierno de ejecuciÃ³n

La Capa 3 incorpora una polÃ­tica explÃ­cita de reintentos. Solo excepciones
clasificadas como transitorias son reintentadas; los errores permanentes se
detienen inmediatamente.

## CompensaciÃ³n

Cada componente puede registrar una acciÃ³n de compensaciÃ³n. Una falla terminal
ejecuta la compensaciÃ³n correspondiente y registra el resultado en el ledger.

## AuditorÃ­a de eventos

El ledger de eventos mantiene secuencia contigua y hash SHA-256 encadenado.
Cualquier alteraciÃ³n rompe la verificaciÃ³n de integridad.

## Health gates

Antes del cierre institucional deben estar saludables:

- Orquestador;
- State Store;
- PMO Digital;
- Auditor Institucional;
- SGD-002.

FastAPI y n8n se mantienen desacoplados por adaptadores efectivos de Capa 2 y
pueden someterse a health checks operativos posteriores sin bloquear las pruebas
unitarias de esta capa.

## Cierre

El cierre exige simultÃ¡neamente:

- health gates aprobados;
- orquestaciÃ³n completa;
- adaptadores efectivos;
- ledger verificable;
- gobierno de retries y compensaciÃ³n.

Una vez aprobado, SPT-023.6 queda `INSTITUTIONALLY CLOSED` y habilita
**SPT-023.7 â€” AuditorÃ­a Inteligente**.
