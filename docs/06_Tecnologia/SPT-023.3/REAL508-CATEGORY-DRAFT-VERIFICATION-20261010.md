# REAL508: verificación del archivo de propuestas semánticas

Fecha local: 2026-10-10. Baseline de ejecución: 980200ce5fd1cc6adf33ce84274b8d928bb518d4. No se crea un motor, ni se modifican código, taxonomía o datos lingüísticos originales. Se conserva la validación previa de 25 registros.

El usuario pidió asignar categorías. Se preparó para revisión un Excel separado con propuestas por ID basadas en glosas españolas y categorías existentes. Las asignaciones son sugerencias de IA, no salidas ASSIGNED certificadas de SPT-023.3. No se alteraron sus gates ni se crearon aprobaciones humanas. La publicación de las 508 propuestas individuales fue rechazada por revisión automática porque no tienen validación lingüística. Esta entrega pública contiene solo conteos y resultados de verificación técnica, sin textos léxicos ni propuestas individuales. El Excel quedó disponible para el usuario.

| Categoría existente | Conteo de propuestas |
|---|---:|
| Familia | 27 |
| Animales | 66 |
| Alimentos | 29 |
| Acciones | 78 |
| Colores | 26 |
| Transporte | 4 |
| Cuerpo humano | 38 |
| Salud | 30 |
| Naturaleza | 40 |
| Agricultura | 9 |
| Comunicación | 45 |
| Materiales | 21 |
| Por validar | 95 |
| Total | 508 |

413 registros tienen propuesta en categoría existente; 95 requieren una categoría específica aún no cubierta. Sus temas descriptivos no crean categorías institucionales. Hay 124 registros de revisión prioritaria. Todos los 508 siguen pendientes de validación lingüística; cero categorías nuevas y cero categorías certificadas. La gramática Puinave no se deduce del español. EN/PT/IT no se certifican.

Controles completados: 508 IDs únicos consecutivos; 2545 valores originales preservados exactamente en la copia; hash de la fuente sin cambios; conteos suman 508; cero errores de fórmulas; inspección visual de las tres hojas; campos de revisión no aceptan revisión completa sin revisor y categoría revisada. Se quitaron los valores temporales usados para verificar las fórmulas. El Excel no escribe en FastAPI, PostgreSQL ni Flutter. La publicación de este resumen no certifica las propuestas ni declara PASS global o cierre REAL508 R2.
