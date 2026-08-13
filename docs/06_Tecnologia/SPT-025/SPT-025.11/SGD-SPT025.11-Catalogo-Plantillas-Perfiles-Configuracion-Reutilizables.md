# SPT-025.11 â€” CatÃ¡logo Institucional de Plantillas de Instancia y Perfiles de ConfiguraciÃ³n Reutilizables

Baseline autoritativa: `12d228f423d553f12eebccfee506926975c392d1`.

SPT-025.11 consume obligatoriamente `artifacts/development/SPT-025.10-v1.0.0/spt02511-prepare.json`.

## Objetivo

Crear un catÃ¡logo institucional, reutilizable y neutral respecto de la lengua para definir plantillas de plataforma SGODA y perfiles de configuraciÃ³n sin desplegar plataformas reales.

La arquitectura permanece:

`SGODA Core â†’ Motor de Instancias â†’ una lengua nativa configurable â†’ plataforma SGODA independiente â†’ 0..N idiomas auxiliares configurables`.

Los idiomas auxiliares no estÃ¡n fijados en cÃ³digo. EspaÃ±ol, inglÃ©s, italiano, portuguÃ©s u otros pueden configurarse por instancia.

## Nombres y perfiles de ejemplo

Cualquier lengua o comunidad incluida en pruebas o evidencias es exclusivamente ilustrativa. No constituye una instancia real ni un destino de despliegue. Las referencias histÃ³ricas a Kurripaco permanecen Ãºnicamente como evidencia tÃ©cnica de capas previas.

## CatÃ¡logo

El catÃ¡logo gobierna:
- plantillas versionadas;
- perfiles versionados;
- compatibilidad plantilla/perfil;
- lengua nativa exactamente una por plataforma;
- 0..N idiomas auxiliares;
- recursos configurables, incluida Biblia opcional;
- identidad y branding configurables;
- SHA-256;
- referencia compartida a SGODA Core;
- no despliegue automÃ¡tico.

Todos los artefactos de SPT-025.11 deben quedar versionados y sincronizados en el repositorio oficial.
