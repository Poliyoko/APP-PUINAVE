# REAL508: siete categorías y 95 asignaciones educativas aprobadas

Baseline remoto: 99401a2d50bb93820e90c645e79bca17bf4c5a38. Aprobación explícita del usuario: «Estoy de acuerdo con la propuesta de las categorias para los 95 registros pendientes», seguida de «de acuerdo al motor asignar las categorias y actualizar en el repositorio y en la plataforma». Fecha local: 2026-10-10.

Se reutilizó Spt0233Layer3GovernanceService.review_proposal para registrar siete categorías con aprobación humana y cadena SHA256. No se creó otro motor. Las asignaciones educativas por ID materializan la distribución revisada por el usuario; no son salidas automáticas ASSIGNED de C2. Los gates de SPT-023.2 y SPT-023.3 no se modificaron y no se declara certificación lingüística ni cierre REAL508 R2.

| Componente | Ruta exacta | Evidencia y estado |
|---|---|---|
| Gobierno existente C3 | src/sgoda/integration/spt0233/layer3.py | Reutilizado sin modificación: siete review_proposal aprobados |
| Registro existente C3 | config/real508/category-registry.json | 20 entradas: 12 categorías anteriores, siete nuevas y other; SHA validado |
| Cadena de aprobación | config/real508/category-ledger.jsonl | Siete eventos; verify() = true |
| Taxonomía REAL508 | config/real508/taxonomy.json | Extensión separada; configuración DEMO25 intacta |
| Asignaciones aprobadas | config/real508/category-assignments.json | 95 IDs, huellas de texto por fila; sin copiar palabras o glosas; gramática no certificada |
| Lectura no destructiva | src/sgoda/operational_platform/category_assignments.py | Verifica registro/ledger y huella exacta PU/ES/pronunciación antes de aplicar categoría |
| Contrato FastAPI→Flutter | src/sgoda/operational_platform/flutter_contracts.py | category, categoryLabel, categoryStatus y categoryLinguisticCertified disponibles por contrato existente |
| Pruebas de integración | tests/integration/test_real508_approved_categories.py | Aprobación, preservación, bloqueo por diferencia, alcance de 95 y registro C3 comprobados |
| Evidencia HTTP | artifacts/real-508/category-approval/verification.json | 508 respuestas HTTP en TestClient; 95 categorías aprobadas; 413 propuestas pendientes |
| PostgreSQL en vivo | scripts/real508/Start-SGODAReal508.ps1 | Instalación Windows/WSL local del usuario; inaccesible desde esta sesión. Sin DML ni modificación del RLB |
| Cliente Flutter | apps/sgoda_puinave_demo/lib/main.dart | Integración preparada localmente, pendiente de flutter analyze/test/build; no publicada porque falta SDK |

Conteos aprobados: Referencia personal y posesión 14; Relaciones sociales e identidad 14; Cantidad y números 12; Tiempo 14; Dimensión, posición y textura 14; Cultura espiritual 2; Cualidades, emociones y conducta 25. Total 95.

Fuente usada para huellas: Repositorio lexico base 508(3).xlsx, hoja1. El archivo original no se modifica ni se publica. La fuente actual contiene actualización del usuario en 000502; si PostgreSQL conserva otra glosa/pronunciación, esa fila devolverá SOURCE_MISMATCH y no recibirá esta asignación hasta reconciliación explícita con REAL508 R2. No se actualiza texto certificado automáticamente.

Validación: 35 pruebas seleccionadas pasaron, incluidos gobierno C3 y contratos PostgreSQL/FastAPI; adicionalmente se comprobaron los 508 registros de la fuente actual a través del endpoint lexical en TestClient, con preservación exacta y 95 categorías. Esto no es una prueba de conexión PostgreSQL real ni un despliegue en el equipo del usuario. Las 413 sugerencias anteriores quedan fuera de esta publicación porque esta aprobación se refiere a los 95 pendientes.

Pendientes demostrados: validar y publicar el cliente Flutter preparado; sincronizar el checkout Windows autorizado con este commit; reiniciar el backend local mediante su procedimiento operacional; reconstruir Flutter y comprobar GET /lexical/000001 y /lexical/000502 en la instalación real. No se declara actualización en vivo sin esas evidencias.
