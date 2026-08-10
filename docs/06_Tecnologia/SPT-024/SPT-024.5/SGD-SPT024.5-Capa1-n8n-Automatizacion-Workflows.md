# SPT-024.5 — Seguridad de n8n, Automatizaciones y Workflows — CIERRE R1

## Objetivo

Incorporar controles de seguridad sobre n8n, automatizaciones y workflows sin
reabrir ni modificar SPT-023 ni SPT-024.1–SPT-024.4.

## Controles

- credenciales únicamente por referencias seguras;
- prohibición de secretos en texto plano dentro de workflows;
- webhooks con autenticación;
- bloqueo de patrones peligrosos de Execute Command;
- fingerprint SHA-256 de workflows;
- trazabilidad institucional;
- workflows no confiables deshabilitados hasta validación;
- runtime local, gratuito o de código abierto aprobado;
- ningún workflow es ejecutado durante el Security Gate.

## Alcance

El gate inspecciona definiciones JSON de n8n/automatización. No inicia n8n, no
dispara webhooks, no ejecuta comandos y no imprime valores secretos.
