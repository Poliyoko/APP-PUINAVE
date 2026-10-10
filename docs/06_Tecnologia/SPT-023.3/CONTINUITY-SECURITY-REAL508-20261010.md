# Continuidad incremental SPT-023.3 y REAL508 R2

Base remota: `9db35919c22ce0516f5a6217d37687d296c41c70`. El avance desde
`770d21eae0462cad56f90507c4924021078e8623` añadió exclusivamente
`docs/06_Tecnologia/SPT-023.3/AUDIT-CONTINUITY-REAL508-20261010.md`.
No se reabren cierres históricos ni se reconstruye REAL508 R2.

## Cambios y evidencia

| Archivo | Cambio validado |
|---|---|
| `src/sgoda/integration/spt0233/layer2.py` | Las decisiones explícitas bloqueantes prevalecen sobre flags contradictorios. El fallback exige booleano verdadero. Los lotes inválidos se rechazan sin descartar registros silenciosamente. |
| `src/sgoda/integration/spt0233/review_api.py` | Router FastAPI opcional reutiliza gobernanza C3; deriva reviewer del principal autenticado por el servidor. No acepta reviewer en JSON ni confía en cabeceras de identidad. |
| `src/sgoda/integration/spt0233/real508_preparation.py` | Cola derivada con IDs, hash efectivo de fuente, huella del catálogo y gates bloqueados. Reutiliza el clasificador existente. CLI de solo lectura con salida nueva. |
| `scripts/Invoke-SPT0233-Real508Preparation.ps1` | Entrada PowerShell oficial para la CLI, preservando PYTHONPATH previo. |
| `tests/integration/test_spt0233_continuity_security.py` | Regresiones de bloqueo, pérdida de registros, suplantación, permisos, identidad del ledger e integridad de preparación. |
| `artifacts/audit/category-continuity-20261010/results.json` | Ejecución sobre los 508 registros R2, huellas y bloqueos concretos. |
| `artifacts/audit/category-continuity-20261010/tests.xml` | Evidencia JUnit de la selección de categorías. |

## Integración de identidad

No existe proveedor de autenticación operativo verificado en la API actual;
SPT-024.9 y SPT-024.15 contienen evaluadores de perfiles, no verificación de
credenciales HTTP. Por eso no se monta una ruta productiva abierta ni se
implementa otro proveedor de identidad.

El host debe instalar `AuthenticationMiddleware` de Starlette con un backend
que verifique credenciales, emita una identidad estable calificada por issuer
y los scopes `authenticated`, `human`, `category:review`. Luego puede montar
`create_review_router(Spt0233Layer3GovernanceService(...))` mediante
`app.include_router`. Sin middleware, identidad o permiso, no hay escritura.
El backend de los tests es exclusivamente una fixture y no es un proveedor
productivo. Si se usan cookies, el host debe añadir protección CSRF antes de
montar la ruta. No se verificaron OIDC, MFA ni integración con directorios.

La ruta exige un worker y una instancia de router por par registry/ledger.
El lock serializa peticiones en ese proceso; la persistencia histórica JSON
no garantiza transacciones entre procesos. PostgreSQL y su autorización
productiva siguen pendientes. No se altera la API operativa compartida con
REAL508, Flutter ni los stores históricos de C3.

## Preparación REAL508

Se procesaron 508 IDs únicos, conservando bytes de la vista controlada R2.
Resultado: 508 NOT_ELIGIBLE, cero categorías certificadas. La taxonomía demo
existente se proyecta en memoria de `label_es` a `name`, preservando IDs,
habilitación, orden y versión; no se inventan keywords ni significados.
Se requieren salidas SPT-023.2 válidas antes de asignar categorías reales;
esta entrega prepara la cola sin simular decisiones READY_FOR_CATEGORY.
Cambios de fuente efectiva invalidan la huella del lote y del registro.
EN/PT/IT permanecen sin certificación ni autorización de publicación.

Reproducción: `Invoke-SPT0233-Real508Preparation.ps1 -SourceView <vista-R2>
-Taxonomy <taxonomy.json> -Output <archivo-nuevo.json>`. No sobrescribe inputs
ni salidas preexistentes. No escribe Excel, PostgreSQL ni recursos multimedia.

## Pruebas y límites

Selección: tres archivos históricos `test_spt0233_category_engine.py`,
`test_spt0233_category_engine_layer2.py`, `test_spt0233_category_governance_layer3.py`
y nuevo `test_spt0233_continuity_security.py`: 58 passed, 0 failed.
Una advertencia de deprecación Starlette/httpx, sin alterar dependencias.
PowerShell no está disponible aquí: wrapper preparado, ejecución Windows
pendiente. La CLI Python se ejecuta separadamente sobre R2.
No se declara PASS global: faltan Excel certificado y ocho pruebas asociadas.

## REAL508 R2 y publicación

El commit local `e6d4bcefb24e9c65879aea36fea17b2887bc4103` permanece intacto en
el checkout original. El paquete `SGODA-REAL508-R2-AUDIT-CONTINUITY.zip`
conserva SHA-256 `b61b78ffc8bcb4b3da070e559d13f38f8747681a2e1438f76c92458d6da4e8e6`.
La rama remota avanzó solo con documentación, sin solaparse con sus 19 archivos.
Su publicación exacta requiere transporte Git autenticado o importación de
objetos con metadatos completos; ninguna capacidad está disponible aquí.
No se repitió push fallido ni se creó un commit sustituto de REAL508.

Los cambios de categorías se preparan en checkout separado basado en el SHA
remoto actual. Se publican mediante objetos Git API con actualización no
forzada y expected_sha; el SHA devuelto debe comprobarse tras publicar.
Esta documentación describe límites de validación, no cierre productivo.

Reconciliación adicional antes de publicación: `925bf2d158adf659953b5274b9725bcd468e0589` añadió evidencias `artifacts/audit/category-engine-20261010/{integrity.json,pytest.txt,tree.txt}` y actualizó la auditoría previa. Sin solapamiento con esta entrega. Se conserva como padre de publicación. El primer objeto commit `e5c9e4b12c9ef4f60ed705d0eac0837614e995db` no se publicó en la rama; no se fuerza su actualización.
