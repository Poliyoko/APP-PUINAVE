# SPT-023.4 â€” Generador Multimedia â€” Capa 2

## Objetivo

Implementar la ejecuciÃ³n local gobernada de los planes producidos por
SPT-023.4 Capa 1 y persistir los resultados en el Registro Multimedia
Reutilizable (ADR-010/RMR).

## Capacidades

- ejecuciÃ³n de proveedor local de imagen mediante comando configurable;
- ejecuciÃ³n de TTS local para espaÃ±ol, inglÃ©s e italiano;
- incorporaciÃ³n de grabaciÃ³n humana nativa Puinave;
- validaciÃ³n binaria de imÃ¡genes PNG/JPEG;
- validaciÃ³n estructural de audio WAV;
- SHA-256 de cada recurso;
- persistencia atÃ³mica en RMR;
- reutilizaciÃ³n de recursos ya aprobados;
- bloqueo cuando falta proveedor local o entrada humana requerida;
- prohibiciÃ³n explÃ­cita de APIs de pago y dependencia de red.

## Seguridad

La capa no contiene URLs, tokens, credenciales ni SDKs remotos. Los proveedores
son comandos locales declarados por configuraciÃ³n institucional.

Las pruebas usan proveedores locales sintÃ©ticos Ãºnicamente para validar el
contrato de ejecuciÃ³n y persistencia; no sustituyen la grabaciÃ³n Puinave ni
constituyen contenido multimedia institucional final.

## Siguiente desarrollo

SPT-023.4 Capa 3 deberÃ¡ cerrar la gobernanza de calidad multimedia, aprobaciÃ³n
humana, manifestaciÃ³n de completitud por palabra y preparaciÃ³n del contrato de
salida hacia SPT-023.5 Constructor FLD/ODA.
