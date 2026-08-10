# SPT-023.5 â€” Constructor FLD / ODA â€” Capa 1

## Objetivo

Iniciar SPT-023.5 construyendo de forma determinÃ­stica la Ficha LÃ©xica Digital
(FLD) y el Objeto Digital de Aprendizaje (ODA) a partir del contrato
`READY_FOR_FLD_ODA` producido por SPT-023.4.

## Entrada

La capa exige:

- identificador lÃ©xico estable;
- palabra Puinave;
- categorÃ­a institucional;
- traducciones disponibles;
- manifiesto multimedia SHA-256;
- exactamente cinco recursos multimedia aprobados:
  imagen, audio Puinave, audio espaÃ±ol, audio inglÃ©s y audio italiano.

## Ficha LÃ©xica Digital

La FLD consolida identidad lÃ©xica, traducciones, categorÃ­a, referencias
multimedia, trazabilidad del manifiesto y metadatos institucionales.

## Objeto Digital de Aprendizaje

El ODA se construye exclusivamente desde una FLD vÃ¡lida y conserva su hash como
referencia de origen. Incluye el tÃ©rmino, traducciones, categorÃ­a y los cinco
recursos multimedia.

## Integridad

FLD y ODA generan SHA-256 determinÃ­sticos sobre representaciÃ³n JSON canÃ³nica.

## Siguiente desarrollo

SPT-023.5 Capa 2 deberÃ¡ implementar persistencia/versionado institucional de FLD
y ODA, registro maestro de objetos, validaciÃ³n de referencias y consulta por
identificador lÃ©xico.
