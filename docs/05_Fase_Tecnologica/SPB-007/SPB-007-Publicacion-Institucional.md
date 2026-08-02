# SPB-007 — Publicación Institucional Automatizada del Repositorio

## Objetivo

Resolver de forma reproducible los problemas de finales de línea,
staging, commit, upstream, push, tag y verificación final del repositorio.

## Seguridad operativa

Las pruebas nunca hacen push ni requieren acceso remoto. Utilizan
repositorios temporales locales.

El instalador no publica automáticamente salvo que se utilice
`-PublishNow`. La operación recomendada es:

1. Instalar y ejecutar las pruebas.
2. Revisar `git status -sb`.
3. Ejecutar el publicador con `-Publish`.
4. Ejecutar la auditoría estricta SGD-114 v2.

## Solución al error CRLF/LF

SPB-007 crea `.gitattributes` y usa comandos Git con configuración
temporal y local al comando:

```text
git -c core.safecrlf=false add --renormalize .
git -c core.safecrlf=false add --all
```

No modifica la configuración global de Git.

## Upstream

Cuando la rama no tiene upstream, el publicador ejecuta:

```text
git push --set-upstream origin <rama>
```

Cuando ya existe upstream, ejecuta el push normal.

## Evidencias

- auditoría previa;
- resultado de publicación;
- manifiesto SGD-114 v2;
- evento PMO;
- dashboard;
- quality gate.