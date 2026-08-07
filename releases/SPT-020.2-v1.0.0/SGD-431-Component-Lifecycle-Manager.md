# SGD-431 - Component Lifecycle Manager

| Field | Value |
|---|---|
| Component | SPT-020.2 |
| Version | 1.0.0 |
| Parent | SPT-020 |
| Repository source of truth | YES |
| External service required | NO |
| n8n | Not installed |
| Paid services | Not required |

## Lifecycle

REGISTERED -> INSTALLED -> ACTIVE -> SUSPENDED -> ACTIVE -> RETIRED

SPT-020.2 manages registration, dependency validation, controlled state
transitions, institutional hooks, event history and lifecycle health snapshots.