# SPT-024.2-R1 — Remediación y Certificación de Secretos

## Propósito

SPT-024.2-R1 continúa el intento bloqueado de SPT-024.2 sin reconstruir
SPT-024.1 ni SPT-024.2. Utiliza la línea base y los artefactos ya generados para
realizar diagnóstico seguro, clasificación contextual y remediación automática
únicamente de bajo riesgo.

## Reglas de seguridad

- Nunca registrar valores de secretos.
- Persistir únicamente ruta, línea, detector, fingerprint y disposición.
- No rotar credenciales automáticamente.
- No eliminar secretos del historial Git automáticamente.
- No modificar servicios que consumen credenciales sin identificar previamente
  la dependencia.
- Corregir automáticamente solo controles de higiene seguros, comenzando por
  `.gitignore`.

## Disposiciones

`CERTIFIED_FALSE_POSITIVE`: evidencia suficiente para descartar riesgo.

`REVIEW_REQUIRED`: la evidencia no permite decidir automáticamente. Bloquea la
publicación.

`CONFIRMED_RISK`: probable credencial o clave en contexto de ejecución/config.
Bloquea la publicación y exige sustitución/rotación controlada.

## Criterio de cierre

R1 solo puede publicar SPT-024.2 cuando:

- no existan `CONFIRMED_RISK`;
- no queden candidatos `REVIEW_REQUIRED`;
- el control `.gitignore` esté corregido;
- SPT-023 y SPT-024.1 permanezcan íntegros;
- las pruebas y la suite institucional sean satisfactorias.

Si queda riesgo real, R1 genera un reporte seguro y termina en HOLD sin commit ni
push. Ese HOLD es un resultado de seguridad válido, no un fallo del maestro.
