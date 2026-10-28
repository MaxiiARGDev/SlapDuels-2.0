# Montaje de espalda Chancla

La Hand de Chancla tiene dimensiones aproximadas X=1.63, Y=0.10, Z=3.91: su eje largo es Z. Classic utiliza Y como eje largo. Alinear directamente ambas Hand al mismo attachment del Torso producía una Chancla horizontal.

Se agregó un Attachment SlapBackAttachment con CFrame.Angles(math.pi/2,0,0) y posición local cero en:

- ServerStorage.Slaps.Slap_Chancla.Hand.
- ServerStorage.SlapVariations.Chancla.[Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood, Galaxy].Hand.

Son 13 attachments, uno por Tool. El servicio existente ya admite ese punto de montaje: no se modificó código. No se cambió Handle, Tool.Grip, configuración de combate, tamaño, geometría, colores ni VFX/SFX. Tampoco se modificó Torso.slap_here ni los modelos Classic/PingPong. La orientación conserva la inclinación artística actual del attachment del jugador, pero alinea el eje largo de Chancla con el eje vertical de ese attachment.

## Persistencia en Edit y repositorio

Instalado en Edit. Se actualizaron los binarios completos src/assets/SlapBaseToolsV3.rbxm y src/assets/SlapVariationToolsV3.rbxm, ya referenciados por ambos proyectos. La exportación final se obtuvo por fragmentos con un SHA-256 común por recurso, para evitar el truncamiento de respuestas MCP mayores a 100 KB.

Respaldo: tests/assets/backups/ChanclaBackMountV1/. Incluye los binarios locales anteriores y las exportaciones nativas previas. El respaldo nativo de variaciones se reconstruyó desde una copia sin los doce attachments recién añadidos, porque la primera respuesta MCP quedó truncada; la copia se serializó completa y se verificó su hash por fragmentos. No se retiraron attachments de los originales para generar el respaldo.

## Validación

- 94 aserciones aisladas en Edit sobre modelo base y 12 variaciones: montaje único e idéntico, eje largo vertical, cara plana paralela a la espalda, alineación y originales intactos.
- 439 comprobaciones de regresión de BackSlapV1 sobre 36 variaciones: PASS.
- Preview temporal de Chancla Gold en el R6 inspeccionada desde atrás mediante captura MCP: queda vertical e inclinada sobre la espalda.
- Ambos Rojo builds PASS. Inspección XML confirma 13 SlapBackAttachment en cada build.
- git diff --check PASS.
- Previews y módulos temporales retirados.

No se inició Play ni Run. El desarrollador debe comenzar una nueva prueba y equipar Chancla Basic/Gold y otra variación para comprobar el resultado sobre su avatar real. El agarre durante combate queda sin cambios.
