# SPT-024.3-R1 — Seguridad de FastAPI, APIs y Servicios

## Solución institucional

SPT-024.3-R1 corrige el alcance del auditor y añade una capa ASGI de seguridad
desacoplada para proteger APIs sin modificar los módulos cerrados de SPT-023.

La auditoría productiva queda limitada a raíces operativas bajo `src/sgoda` y
excluye pruebas, releases históricos, documentación, artifacts y templates del
Builder. Esto evita que fixtures inseguros creados deliberadamente para probar
el detector sean interpretados como configuración productiva.

## Gateway desacoplado

La capa `ApiSecurityGatewayMiddleware` provee:

- autenticación Bearer para rutas sensibles;
- protección explícita de `/audit/repository`;
- cabeceras HTTP de seguridad;
- CORS por allowlist;
- trusted hosts;
- control de tamaño de solicitudes;
- rate limiting;
- comparación de token con `hmac.compare_digest`;
- fail-closed si `SGODA_API_GUARD_TOKEN` no está configurado;
- cero persistencia o logging de valores secretos.

La credencial debe inyectarse por variable de entorno o mecanismo seguro
aprobado por SPT-024.2; nunca se almacena en Git.

## Resultado esperado

El Security Gate solo pasa si no existen configuraciones operativas con
`debug=True`, CORS wildcard, secretos en texto plano o rutas sensibles sin
protección nativa o por gateway.
