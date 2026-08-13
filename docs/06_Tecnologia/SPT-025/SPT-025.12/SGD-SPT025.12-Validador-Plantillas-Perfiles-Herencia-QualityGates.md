# SPT-025.12 â€” Validador Institucional de Plantillas y Perfiles, Compatibilidad, Herencia y Quality Gates de ConfiguraciÃ³n

Baseline autoritativa: `60fb409bdaa21ee5953d93b4a8ae7ecbed14d27f`.

SPT-025.12 consume obligatoriamente `artifacts/development/SPT-025.11-v1.0.0/spt02512-prepare.json` y preserva SPT-025.1â€“SPT-025.11.

## Objetivo

Validar institucionalmente las plantillas y perfiles reutilizables definidos en SPT-025.11, incluyendo contratos, compatibilidad, herencia controlada, integridad SHA-256 y quality gates de configuraciÃ³n.

## Reglas arquitectÃ³nicas

- SGODA Core permanece compartido y no se duplica.
- Cada plataforma tiene exactamente una lengua nativa principal configurable.
- Cada plataforma admite 0..N idiomas auxiliares configurables.
- NingÃºn idioma auxiliar queda fijado en cÃ³digo.
- La herencia de perfiles puede extender configuraciÃ³n, pero no puede cambiar la lengua nativa de la plataforma.
- Recursos culturales, Biblia, identidad y branding siguen siendo configurables por instancia.
- Los nombres de ejemplo son Ãºnicamente evidencia tÃ©cnica y no representan una plataforma real.
- Kurripaco no se registra ni despliega como instancia real.
- No hay despliegue automÃ¡tico ni modificaciÃ³n de producciÃ³n.

Todos los entregables, cÃ³digo, pruebas, polÃ­ticas, matrices, evidencias y PREPARE deben quedar versionados y sincronizados en el repositorio oficial.
