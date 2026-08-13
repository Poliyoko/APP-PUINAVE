# SPT-025.10 â€” Registro Maestro de Instancias, Versionado de Paquetes, Trazabilidad y Gobierno de Ciclo de Vida

Baseline autoritativa: `c3c83833c82e8d4310c38cde660b8d4c45be2e86`.

## Objetivo
Crear el registro institucional genÃ©rico de plataformas lingÃ¼Ã­sticas SGODA, gobernar las versiones de sus paquetes, mantener trazabilidad SHA-256 y controlar su ciclo de vida sin desplegar nuevas plataformas.

## Arquitectura
`SGODA Core â†’ Motor de Instancias â†’ una lengua nativa configurable â†’ plataforma SGODA independiente â†’ 0..N idiomas auxiliares configurables`.

Los idiomas auxiliares no estÃ¡n fijados en cÃ³digo. EspaÃ±ol, inglÃ©s, italiano y portuguÃ©s son ejemplos vÃ¡lidos de configuraciÃ³n, no una lista cerrada.

## Regla sobre nombres de ejemplo
Cualquier nombre de lengua o comunidad utilizado durante pruebas, previews o evidencias es exclusivamente ilustrativo. No constituye una instancia real, una comunidad seleccionada ni un destino de despliegue. En particular, las referencias histÃ³ricas de ensayo a Kurripaco en SPT-025.7â€“SPT-025.9 siguen siendo evidencia tÃ©cnica no desplegada.

## Gobierno
El registro controla identidad de instancia, lengua nativa, idiomas auxiliares, versiÃ³n del paquete, SHA-256, estado de ciclo de vida, trazabilidad y referencia compartida a SGODA Core.

SPT-025.10 no despliega plataformas, no modifica producciÃ³n, no duplica SGODA Core y no modifica SGODA-PUINAVE.

Todos los resultados, pruebas, polÃ­ticas, documentaciÃ³n, registros, manifests y evidencias deben quedar publicados en el repositorio oficial.
