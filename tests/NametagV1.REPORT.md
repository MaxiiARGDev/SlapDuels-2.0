# Nametag V1

## Implementado

Se reemplazó la lógica del script Workspace.NametagService y su plantilla editable Workspace.NametagService.Nametag. Se conserva un solo script responsable de crear tags; no se agregó otro servicio paralelo a Bootstrap.

La composición sigue la referencia: nivel grande arriba, copa dorada con contador a la izquierda, DisplayName blanco, @Name celeste debajo e icono lila al lado derecho. La plantilla es un BillboardGui transparente de 220 × 94, con distancia máxima 75 studs y desplazamiento vertical 2.3 desde la cabeza. No se dibuja a través de paredes. Copa e iconos son componentes nativos editables, sin imágenes externas dependientes de permisos o moderación.

- Level: 0 fijo, sin implementar EXP ni alterar perfiles.
- Trophy.Wins: victorias reales desde leaderstats.Wins; escucha cambios y reemplazos del contenedor/valor.
- Identity.DisplayName: nombre visible real del Player.
- Identity.Username: @ seguido de Player.Name real.
- Platform.PC/Mobile/Console: un solo icono visible según el informe cosmético del cliente.

El nombre nativo del Humanoid se oculta para evitar duplicados, manteniendo sus reglas de salud. El tag se reinstala si la aplicación de apariencia reemplaza Head, y se limpia al quitar Character o salir. Las conexiones de Character y estadísticas se desconectan al reemplazar sus recursos.

## Plataforma: límite de la detección

Se utiliza UserInputService.PreferredInput: KeyboardAndMouse → PC, Touch → móvil, Gamepad → icono de consola/mando. Representa el control preferido detectado, no una identificación garantizada del hardware: un PC con mando puede mostrar el mando y un móvil con teclado puede mostrar PC. Se documenta expresamente esa limitación, en lugar de afirmar que se detecta el sistema operativo.

El cliente solo puede informar PC/Mobile/Console para sí mismo. El servidor valida la lista y limita los informes a uno cada dos segundos. El valor no concede permisos, premios ni estadísticas. Nombre, victorias y nivel no se aceptan desde el cliente. Mientras no llega un informe válido, el icono queda oculto.

Referencia oficial: https://create.roblox.com/docs/reference/engine/classes/UserInputService y https://create.roblox.com/docs/input

## Archivos y respaldo

- src/world/NametagService.server.luau: lógica del script existente.
- src/shared/NametagPresentation.luau: contrato cosmético y presentación.
- src/client/NametagPlatform.client.luau: informe del control preferido.
- src/assets/NametagV1/Nametag.rbxm: plantilla exportada desde Edit.
- default.project.json y studio-safe.project.json: mapeos de script, plantilla y módulos.
- tests/tools/nametag_v1_edit.luau: construcción reproducible del diseño.
- tests/NametagV1.edit.spec.luau: comprobaciones aisladas.
- tests/assets/backups/NametagV1/: script y recurso previos, más ambos proyectos previos.

Si se ajusta la plantilla físicamente en Studio, se debe actualizar la exportación binaria para que una futura sincronización Rojo conserve esos ajustes.

## Verificación

- 41 aserciones aisladas en Edit: lista de plataformas, entradas inválidas, controles, wins, textos, Unicode, selección exclusiva de icono, plataforma desconocida, nivel 0, límites y plantilla original intacta.
- Compilación Luau: 197 scripts PASS.
- Ambos builds Rojo: PASS.
- Inspección de ambos builds: un NametagService, plantilla completa y reporter cliente PASS.
- git diff --check: PASS.
- Vista temporal en Edit revisada mediante captura MCP; se corrigió el tamaño de texto y se retiró el objeto temporal.
- Inspección final: script habilitado, plantilla de 65 descendientes, sin previews ni módulos de auditoría residuales.
- Respawn, victorias durante partida y plataformas con clientes reales: NOT RUN.

No se inició Play/Run/Start Server ni se controlaron jugadores. No hubo escrituras de DataStore, commits, push ni publicaciones. No se cerró ni guardó el lugar por encima de los cambios del desarrollador.

## Prueba del desarrollador

1. Iniciar una prueba nueva y confirmar Studio/InMemory/WritesToCloud=false.
2. Verificar sobre la cabeza nivel 0, copa con Wins reales, DisplayName, @usuario y un solo icono.
3. Completar una victoria y comprobar actualización de la copa sin respawn.
4. Respawnear: debe quedar un único BillboardGui y no aparecer el nombre nativo duplicado.
5. Probar dos clientes: cada uno debe ver el control informado por el otro. En móvil/emulador y mando, comprobar el cambio de icono tras aproximadamente dos segundos.
6. Comprobar nombres largos, paredes, distancia y la posición sobre accesorios altos. Informar captura y resolución si necesita ajuste artístico.
