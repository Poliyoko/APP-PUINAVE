# SPT-025.15 â€” Gobierno de PublicaciÃ³n de Paquetes Declarativos, PromociÃ³n Controlada y Registro de Materializaciones

Baseline autoritativa: `bb7d818664e46bf7be4bc0036872bc6197fc2a2a`.

Consume obligatoriamente `artifacts/development/SPT-025.14-v1.0.0/spt02515-prepare.json` y preserva Ã­ntegramente SPT-025.1â€“SPT-025.14.

## Objetivo

Gobernar la publicaciÃ³n de paquetes declarativos ya validados, controlar sus transiciones de promociÃ³n y mantener un registro institucional de materializaciones sin desplegar todavÃ­a una plataforma real.

## Reglas

- solamente paquetes declarativos;
- promociÃ³n controlada DRAFT â†’ VALIDATED â†’ APPROVED â†’ PUBLISHED â†’ RETIRED;
- SHA-256 obligatorio;
- registro de materializaciones;
- una lengua nativa principal por plataforma;
- 0..N idiomas auxiliares configurables;
- ningÃºn idioma auxiliar hard-coded;
- SGODA Core compartido y no duplicado;
- nombres de ejemplo son evidencia tÃ©cnica;
- Kurripaco no es una instancia real;
- no auto-deployment;
- no modificaciÃ³n de producciÃ³n;
- todos los resultados, pruebas y evidencias deben quedar en el repositorio oficial.
