# SGD-MOBILE25 — Cierre Institucional

## Estado

**MOBILE-25 = CLOSED_VERIFIED**

## Alcance

Validación física Android de SGODA-PUINAVE, reproducción de audio
REAL-25 y funcionamiento de recursos externos.

## Motor de enlaces

Se identificó que Android utilizaba la implementación stub de
`openExternalUrl`, que devolvía `false`.

La reparación incorpora una implementación nativa genérica mediante
`url_launcher` y `LaunchMode.externalApplication`.

El motor universal no contiene URLs específicas de Puinave.

## Puinave SM / Puinave Bible

El recurso continúa presentado dentro de SGODA como **Puinave SM**.

Su destino se administra desde la configuración de la instancia
Puinave y actualmente conduce a la ficha oficial configurada de
**Puinave Bible**:

https://play.google.com/store/apps/details?id=org.fcbh.puismv.n2.n

Paquete Android:

`org.fcbh.puismv.n2.n`

El recurso permanece:

- habilitado;
- visible;
- configurable por instancia;
- desacoplado del motor universal de enlaces.

## Validación física

- Audio REAL-25: PHYSICAL PASS / FROZEN.
- Navegador externo Android: PHYSICAL PASS / FROZEN.
- Biblia Puinave Web: PHYSICAL PASS.
- Puinave SM -> Puinave Bible: PHYSICAL PASS.
- Puinave Bible detectada instalada en dispositivo: PASS.
- Apertura física de Puinave Bible: PASS confirmada por usuario.
- Flutter analyze: PASS.
- Android build: PASS.
- SGODA APK install: PASS.
- SGODA launch: PASS.

APK SGODA SHA-256:

`2CC1A1B3498FDB22DF70C82C66844D101609EC1CA86B24DE1059D9A604CDBBCF`

## Preservación histórica

Los artefactos de cierre DEMO-25 existentes no fueron reescritos.
Conservan la evidencia correspondiente a la configuración válida en
el momento de aquel cierre.

## Resultado

`MOBILE-25=CLOSED_VERIFIED`

No quedan errores MOBILE-25 autorizados para heredarse a REAL-N.
