# SPT-023.2 - Validacion y Analisis Semantico

## Estado

Implementacion incremental - Capa 1.

## Objetivo

Integrar la salida de SPT-023.1 con las capacidades lexicas y
semanticas existentes de SPT-007A y SPT-007B, sin reconstruir ni
sustituir dichos componentes.

## Principios

- Reutilizar antes de crear.
- No modificar SPT-007A.
- No modificar SPT-007B.
- No modificar SPT-023.1.
- No inventar significados ni relaciones.
- Procesar semanticamente solo elementos NEW.
- Derivar a revision institucional los elementos sin coincidencia.
- Permitir avance automatico a SPT-023.3 solo cuando exista evidencia
  semantica recuperada por el motor institucional.
- Conservar la entrada original.
- Mantener trazabilidad de source, batch_hash y lexical_hash.

## Flujo

SPT-023.1
  -> SPT-023.2 validate_detector_word
  -> SemanticLexicalService (SPT-007B)
  -> MATCHED | REVIEW_REQUIRED | INVALID | SKIPPED
  -> SPT-023.3 cuando downstream_allowed=true

## Politica de no invencion

SPT-023.2 no genera traducciones, significados, categorias ni
relaciones semanticas nuevas. Consume exclusivamente resultados
producidos por SemanticLexicalService.

Cuando el motor no encuentra evidencia, el estado es
REVIEW_REQUIRED y downstream_allowed=false.

## Alcance de Capa 1

Incluye:

- modelo de resultado institucional;
- validador del contrato SPT-023.1 -> SPT-023.2;
- adaptador de SemanticLexicalService;
- procesamiento individual y por lote;
- pruebas unitarias/integracion aislada;
- regresion obligatoria de SPT-007A, SPT-007B y SPT-023.1.

No incluye:

- API FastAPI SPT-023.2;
- workflow n8n;
- persistencia runtime;
- publicacion Git;
- release;
- cierre institucional.

Esos elementos requieren capas posteriores y quality gates propios.