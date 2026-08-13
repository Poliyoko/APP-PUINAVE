# SPT-025 â€” AuditorÃ­a de Continuidad del Repositorio (SPT-025.1 a SPT-025.7)

LÃ­nea base autoritativa auditada: `1d6756e2335f5a130290c2e8ca6169f660007f9b`.

## Objetivo
Comprobar directamente contra el Ã¡rbol Git de la lÃ­nea base que SPT-025.1 a SPT-025.7, sus ejecutables oficiales, cÃ³digo, pruebas, configuraciÃ³n, documentaciÃ³n, evidencias, manifests y PREPARE estÃ©n realmente versionados.

## MÃ©todo
La auditorÃ­a usa `git cat-file -e <commit>:<ruta>` y `git show <commit>:<ruta>` para verificar el contenido del commit autoritativo, no solamente la presencia de archivos en el directorio de trabajo.

## CondiciÃ³n de aprobaciÃ³n
Los siete componentes deben:
1. tener 100 % de las rutas crÃ­ticas declaradas;
2. tener su assessment institucional en el commit;
3. conservar el estado/gate esperado;
4. producir una matriz SHA-256 verificable;
5. mantener intactos todos los archivos tracked que existÃ­an al iniciar la auditorÃ­a;
6. terminar publicados mediante commit/push y `LOCAL_HEAD=REMOTE_HEAD`.

Esta auditorÃ­a no reabre ni modifica SPT-025.1â€“SPT-025.7.
