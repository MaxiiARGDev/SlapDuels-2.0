# Perfil — rediseño visual V1.3

Instalado en **Studio Edit** y observado en una preview estática obtenida mediante MCP `screen_capture` (`ProfileVisualV13_Edit`). No se inició Play, Run, Start Server ni Team Test. La prueba del usuario que estaba en curso no fue detenida por el agente; se esperó su confirmación de vuelta a Edit.

## Causa del oscurecimiento

El recurso anterior tenía un UIGradient oscuro directamente bajo MainFrame, de clase CanvasGroup. Ese modificador afecta el resultado renderizado del grupo completo, incluidos texto, ViewportFrames y botones, como documenta [Roblox para CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup).

Se desactivó `MainFrame.BackgroundGradient`, se fijó GroupColor3 en blanco y se trasladó el arte a `MainFrame.Surface`, un Frame ordinario independiente. La inspección final confirma que no queda ningún UIGradient directo activo en el CanvasGroup. La preview Edit posterior mostró textos blancos legibles y botones de colores sin el filtro negro.

## Diseño aplicado

- Fondo carbón/azul con degradado propio, franjas diagonales discretas, línea superior bicolor y borde exterior suave.
- Cabecera con nombre y @Username separados, categoría, badge de perfil y marco cyan para el avatar.
- Badge oculto en anchos menores de 560 píxeles para evitar que interfiera con el cierre.
- Tarjetas independientes de Rachas, Victorias y Kills, con gradientes cálidos, bordes, acentos superiores y números blancos.
- Iconos de fuego, trofeo y calavera hechos con Frames/UICorner/UIStroke: son componentes físicos editables, no imágenes externas.
- Subtítulos explicativos, incluido `3 VICTORIAS = 1 RACHA`, sin cambios a la regla autoritativa.
- Panel de Slap equipado con iluminación más clara, título y pie; eliminación visual de la repetición de rareza cuando ya está incluida en el nombre.
- Sección de colección con título, cantidad real de artículos al cargar y texto de apoyo.
- Botones de artículos, desafío, invitación e intercambio con iconos, superficies degradadas, brillo fino, bordes y feedback de hover.
- Etiqueta de cada acción en una capa de texto independiente para conservar contraste sobre su superficie de color. La etiqueta de artículos sigue el cambio a “Volver al perfil”.
- Límites de tamaño de texto para impedir títulos y botones desproporcionados.
- Tarjetas de inventario con mayor espacio de preview y etiquetas reordenadas. El identificador interno UnitId permanece en el contrato, pero su etiqueta visual se oculta únicamente en la colección del perfil, sin cambiar TradeHUD.

Se mantienen un solo PlayerProfileHUD, los mismos controles funcionales, el avatar y los previews existentes. Las restricciones SelfProfile/OtherPlayerProfile y de grupos/sesiones no cambiaron.

## Archivos y alcance

Archivos de producto modificados:

- `src/ui/PlayerProfileHUD.project.json`.
- `src/client/Controllers/SocialController.luau`: presentación de nombre/username, badge responsive, textos, etiqueta del botón de artículos y hover.

Herramientas/evidencias nuevas:

- `tests/tools/profile_visual_v13.py`: generador del diseño actual del perfil. Los generadores V1.2 son históricos; ejecutar uno de ellos volvería a aplicar su diseño anterior.
- `tests/tools/validate_profile_visual_v13.py`.
- `tests/ProfileVisualV13.checks.json`, `.studio-edit.json`, `.files.json` y logs/builds correspondientes.

Comparación SHA-256 contra el inicio de la tarea: solo cambiaron esos dos archivos de producto. No se modificó ningún servicio autoritativo, regla de rachas, grupo, desafío, inventario, matchmaking, economía ni persistencia. Tampoco se modificaron mapas o EndCinematic.

Respaldo: `tests/assets/backups/ProfileVisualV13/`, con las fuentes anteriores afectadas, el modelo nativo del perfil, hashes iniciales y manifiesto de integridad.

## Verificación

| Comprobación | Resultado |
|---|---|
| Compilación del controlador cambiado | PASS |
| Regresión social V1.0 y V1.1 | PASS: 121 + 104 aserciones aisladas |
| Regresión de perfil social/grupos/rachas | PASS: 111 aserciones aisladas |
| Total ejecutado en esta tarea | **336 aserciones aisladas** |
| Rojo default y studio-safe | PASS |
| git diff --check | PASS |
| Contrato de UI e iconos nativos | PASS estructural |
| Fuente local, Source y GetEditorSource | Coincidentes tras UpdateSourceAsync con guardas |
| Inspección física | 258 descendientes en PlayerProfileHUD; componentes esperados presentes |
| CanvasGroup sin tinte oscuro | PASS en propiedades y observación de preview Edit |
| Avatar/Slap reales, clics y responsive móvil durante una partida | NOT RUN; validación del desarrollador |

Hashes nativos sin cambios: PlayerHUD, SocialPlayHUD, ShopHUD, PremiumShopHUD, TradeHUD, TradeRequestHUD, MatchHUD, MatchmakingHUD y EndCinematicHUD.

El resolvedor en Edit sigue dando Studio/InMemory/WritesToCloud=false; TradeCommitEnabled continúa false. No se hicieron escrituras cloud, commits, push ni publicaciones.

## Preview y límites

La preview estática de Edit mostró el diseño completo con datos de ejemplo de identidad; no cargó un personaje ni un Slap de una partida y mostró todos los botones para inspeccionar su arte. No representa una prueba del modo propio: en ejecución sus restricciones siguen ocultando las acciones ajenas y ampliando Ver artículos.

Tras capturar se restauraron Enabled, textos temporales y selección previa. La inspección final confirmó PlayerProfileHUD desactivado nuevamente. No se guardó forzadamente ni se cerró el lugar abierto.

## Validación manual

1. Iniciar vos la prueba y abrir MI PERFIL: comprobar nombre, @Username, avatar, estadísticas y Slap equipado con contraste correcto.
2. Entrar a Ver artículos, desplazarse, cambiar páginas y volver al perfil; confirmar que el botón actualiza su etiqueta y no aparecen identificadores internos en las tarjetas.
3. En un perfil ajeno, comprobar el diseño de las acciones permitidas; Desafío debe seguir ocultándose cuando cualquiera pertenece a un grupo.
4. Revisar PC y emulación móvil: cierre accesible, nombres largos, cifras grandes, márgenes y tamaños de texto. La fidelidad visual móvil aún no fue observada en un cliente real.
5. Si persiste un problema visual, enviar una captura nueva y el tamaño de pantalla. No se requieren credenciales ni datos privados del perfil.
