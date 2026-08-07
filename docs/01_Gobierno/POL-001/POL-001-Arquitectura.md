# POL-001 — Arquitectura

POL-001 implementa un registro tecnológico versionado y un motor reproducible
que inspecciona dependencias Python, npm, imágenes Compose y workflows n8n.

Las tecnologías desconocidas no se aprueban automáticamente: quedan en estado
`review_required`. Las excepciones solo se aceptan mediante ADR con estado
Aprobado y una línea `Tecnología: <nombre>`.