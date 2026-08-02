# Migración desde SGD-114 hacia SGD-114C

La política heredada se conserva para trazabilidad.

SGD-114C no elimina ni reescribe automáticamente
`config/governance/sgd-114-policy.json`.

La migración consiste en utilizar `policy_cli` como evaluador normalizado y
mantener SGD-114 como referencia histórica y política compatible.