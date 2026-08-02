# SPB-007 — Política Institucional de Publicación del Repositorio

Toda publicación institucional debe:

- respetar `.gitattributes`;
- excluir archivos temporales mediante `.gitignore`;
- ejecutar pruebas;
- generar staging verificable;
- usar un mensaje de commit institucional;
- configurar upstream si no existe;
- publicar únicamente en el remoto autorizado;
- generar tag cuando corresponda;
- comprobar worktree limpio;
- ejecutar auditoría estricta;
- conservar evidencias en el repositorio.

La publicación remota no se ejecuta dentro de pruebas automatizadas.