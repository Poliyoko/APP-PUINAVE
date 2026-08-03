# SPT-015 — Modelo adaptativo

El motor calcula dominio ponderado por dificultad:

- dominio inferior a 0.55: dificultad 1;
- dominio desde 0.55: dificultad 2;
- dominio desde 0.85: dificultad 3.

La selección usa únicamente preguntas validadas.