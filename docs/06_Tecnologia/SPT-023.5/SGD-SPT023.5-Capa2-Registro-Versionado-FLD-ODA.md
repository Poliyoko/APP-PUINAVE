# SPT-023.5 â€” Constructor FLD / ODA â€” Capa 2

## Objetivo

Implementar la persistencia institucional, versionado, validaciÃ³n de referencias
y consulta de las Fichas LÃ©xicas Digitales (FLD) y Objetos Digitales de
Aprendizaje (ODA) construidos por SPT-023.5 Capa 1.

## Capacidades

- registro maestro local FLD/ODA;
- versiones contiguas por identificador lÃ©xico;
- conservaciÃ³n de todas las versiones;
- hash SHA-256 determinÃ­stico por versiÃ³n;
- validaciÃ³n cruzada FLD -> ODA;
- validaciÃ³n del manifiesto multimedia;
- validaciÃ³n de exactamente cinco recursos;
- consulta de Ãºltima versiÃ³n;
- consulta por versiÃ³n especÃ­fica;
- detecciÃ³n de manipulaciÃ³n del registro;
- persistencia atÃ³mica JSON.

## Integridad

El ODA debe referenciar el hash exacto de la FLD almacenada y ambos objetos deben
referenciar el mismo manifiesto multimedia de SPT-023.4.

La validaciÃ³n fÃ­sica de archivos multimedia puede activarse con
`require_multimedia_files=True` cuando se ejecute sobre recursos reales.

## Siguiente desarrollo

SPT-023.5 Capa 3 deberÃ¡ implementar gobernanza de publicaciÃ³n de FLD/ODA,
manifiesto de completitud, integraciÃ³n con el registro institucional y cierre
del paquete SPT-023.5.
