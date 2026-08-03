# SPT-018 v1.0.0 — Manual operativo

## Health check

```powershell
python -m sgoda.pedagogical_ai.cli `
  --knowledge-storage artifacts/knowledge_center/records.json `
  --operation health `
  --output-json artifacts/pmo/SPT-018-v1.0.0/health.json
```

## Demostración AMDA

```powershell
python -m sgoda.pedagogical_ai.cli `
  --knowledge-storage artifacts/knowledge_center/records.json `
  --operation demo `
  --output-json artifacts/pmo/SPT-018-v1.0.0/amda-pedagogical-demonstration.json
```