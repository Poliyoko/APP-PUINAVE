# SPT-023.4 â€” Generador Multimedia â€” Capa 1

## Objetivo

Iniciar SPT-023.4 mediante una capa de planificaciÃ³n e integraciÃ³n que reutiliza
los componentes multimedia ya existentes en SGODA-PUINAVE en lugar de duplicar
sus responsabilidades.

## ReutilizaciÃ³n institucional

- SPT-003A: planificaciÃ³n y cola de trabajos multimedia.
- SPT-003B: contratos de proveedor, almacenamiento local, eventos y RMR.
- SPT-006: pipeline de enriquecimiento multimedia.
- SPT-006A: traducciÃ³n/TTS local, gratuito y gobernado para es-CO, en-US e it-IT.
- ADR-010: Registro Multimedia Reutilizable (RMR).

## Recursos obligatorios por palabra

1. imagen ilustrativa;
2. audio Puinave;
3. audio espaÃ±ol;
4. audio inglÃ©s;
5. audio italiano.

## PolÃ­tica

La Capa 1 no ejecuta APIs externas ni servicios de pago.

El audio Puinave se mantiene como grabaciÃ³n humana nativa y requiere validaciÃ³n.
Los audios espaÃ±ol, inglÃ©s e italiano se enrutan al motor local y gratuito
SPT-006A. La imagen se enruta al stack SPT-003A/SPT-003B y queda preparada para
un proveedor local de imagen en la siguiente capa.

Los recursos existentes con estado aprobado/vÃ¡lido se reutilizan y no se
regeneran.

## Siguiente desarrollo

SPT-023.4 Capa 2 deberÃ¡ implementar la ejecuciÃ³n local gobernada de imagen y TTS,
persistencia efectiva en ADR-010/RMR y validaciÃ³n de los archivos generados.
