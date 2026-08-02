# Arquitectura Maestra SGODA-PUINAVE

## 1. Propósito

Definir la arquitectura integral del ecosistema para preservar, gestionar, enseñar y ampliar digitalmente la lengua Puinave.

## 2. Vista integral

```text
Repositorio Léxico Base en Excel
        │
        ▼
RLB Canónico — SPT-001B
        │
        ▼
Motor ODA — SPT-002
        │
        ▼
Repositorio Multimedia RMR — ADR-010
        │
        ▼
Orquestador Multimedia — SPT-003A
        │
        ▼
Adaptadores IA y Multimedia — SPT-003B
        │
        ├── Imágenes IA
        ├── TTS español
        ├── TTS inglés
        ├── Grabaciones Puinave
        ├── n8n
        └── Almacenamiento RMR
        │
        ▼
API FastAPI / PostgreSQL
        │
        ▼
Portal web y aplicación Flutter
```

## 3. Capas arquitectónicas

### 3.1 Gobierno y PMO Digital

- SGD-114: evidencias, repositorio y trazabilidad.
- SGD-115: documentación maestra.
- SPB-007: publicación institucional.
- Auditor del Repositorio.

### 3.2 Datos lingüísticos

- Repositorio Léxico Base.
- Esquema extensible y versionado.
- Repositorio canónico.
- Trazabilidad hasta el Excel oficial.

### 3.3 Objetos Digitales de Aprendizaje

- ODA por entrada léxica.
- Slots de imagen y audio.
- Metadatos pedagógicos, culturales y étnicos.

### 3.4 Multimedia e IA

- RMR escalable.
- Cola transaccional.
- Adaptadores de proveedores.
- Revisión humana y cultural.
- Eventos compatibles con n8n.

### 3.5 Aplicaciones

- Backend FastAPI.
- PostgreSQL.
- Portal web.
- Cliente Flutter.
- Dashboard PMO Digital.

## 4. Arquitectura basada en eventos

Los componentes publican eventos institucionales para evitar acoplamiento directo y permitir automatización mediante n8n.

Eventos principales:

- `RepositoryImported`
- `MultimediaJobsPlanned`
- `MultimediaJobCompleted`
- `MultimediaJobFailed`
- `InstitutionalRepositoryAudited`

## 5. Escalabilidad

- Repositorio multimedia probado para 120.000 recursos.
- Cola multimedia probada para 120.000 trabajos.
- Procesamiento desacoplado por lotes.
- Proveedores intercambiables.

## 6. Seguridad y soberanía cultural

- Credenciales solo mediante variables de entorno.
- Revisión humana obligatoria.
- Validación cultural y étnica.
- Preservación de evidencias.
- No modificación destructiva del Excel oficial.

## 7. Componentes inventariados

El registro automático identifica **23** componentes institucionales.

## 8. Evolución prevista

- SPT-003C: operación piloto con proveedor real.
- API funcional.
- Persistencia PostgreSQL.
- Portal web.
- Aplicación Flutter.
- PMO Digital event-driven.

