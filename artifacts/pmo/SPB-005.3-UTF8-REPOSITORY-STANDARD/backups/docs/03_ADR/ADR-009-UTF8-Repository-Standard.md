# ADR-009 â€” EstÃ¡ndar UTF-8 del Repositorio

- **Estado:** Aceptado
- **DecisiÃ³n:** Usar UTF-8 como codificaciÃ³n obligatoria para todos los archivos textuales.
- **Ãmbito:** cÃ³digo, scripts, documentaciÃ³n, datos, configuraciÃ³n y artefactos.
- **MotivaciÃ³n:** evitar pÃ©rdida o corrupciÃ³n de caracteres en lengua Puinave, espaÃ±ol e inglÃ©s, y asegurar interoperabilidad entre Windows, Linux, GitHub, Python y PowerShell.
- **Consecuencias positivas:** consistencia, portabilidad, trazabilidad y reducciÃ³n de mojibake.
- **Riesgos:** archivos histÃ³ricos pueden contener corrupciÃ³n previa; su reparaciÃ³n debe conservar copia de seguridad y evidencia.
- **Controles:** `.editorconfig`, `.gitattributes`, auditor automÃ¡tico, normalizador y pruebas.