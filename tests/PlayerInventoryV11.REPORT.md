# Player Inventory V1.1 — acceso al perfil propio

Implementado y sincronizado en Studio **Edit**. Pendiente de validación visual y multicliente del desarrollador. No se ejecutó Play, Run, Team Test ni Start Server; tampoco transferencias, compras reales, publicaciones, commits, push o escrituras cloud.

## 1. Archivos modificados

Comparación contra el estado local al comenzar V1.1, sin atribuir a esta tarea los cambios de versiones anteriores:

- `src/client/Controllers/SocialController.luau`: ruta propia, presentación, botón, actualización y coordinación de ventanas.
- `src/server/Services/SocialService.luau`: lectura propia autenticada, modo del DTO e invalidación de vistas.
- `src/shared/SocialConfig.luau`: intervalo de actualización propia de dos segundos.
- `default.project.json` y `studio-safe.project.json`: entradas aditivas de botón y remoto. Las entradas previas se conservaron semánticamente.
- Nuevo `src/ui/ProfileButton.project.json`.
- Nuevos `tests/PlayerInventoryV11.spec.luau`, `tests/tools/run_social_v11.py`, `tests/tools/validate_social_v11.py`, este informe y sus evidencias/logs.

Los 230 archivos existentes de `src` se compararon con sus SHA-256 iniciales: únicamente cambiaron los tres scripts indicados. No se modificaron PlayerService, persistencia, inventarios autoritativos, MatchmakingService, RoundService, combate, Trading/TradeEngine, Shop ni Premium Shop.

Respaldo previo de los scripts, ambos proyectos y PlayerHUD nativo: `tests/assets/backups/PlayerInventoryV11/`. Incluye estado Git inicial, manifiesto de fuentes y `backup-sha256.json`. No se forzó guardar, cerrar ni sobrescribir el archivo del lugar abierto.

## 2. Ubicación de ProfileButton

`StarterGui.PlayerHUD.ProfileButton`, TextButton visible con texto **MI PERFIL**, `Active=true`, `Selectable=true`, esquina redondeada y borde cyan. Posición inicial `(0.007, 0.18)`, tamaño `142 × 40`, debajo de la tarjeta de identidad. Se replica en `Players.<jugador>.PlayerGui.PlayerHUD.ProfileButton`.

Es un recurso físico instalado en Edit y representado en ambos proyectos Rojo. Existe exactamente un botón y un `ReplicatedStorage.Remotes.Social.SelfProfile` de clase RemoteFunction. No se crearon objetos de prueba temporales en Workspace.

## 3. Integración con PlayerHUD

Se agregó únicamente el botón; ProfileCard, PremiumShopButton y CombatSlots conservan exactamente sus hashes nativos anteriores. SocialController enlaza Activated, MouseEnter y MouseLeave una vez, guarda las conexiones y las desconecta al destruirse. Init y Start tienen guardas contra doble enlace.

No se encontró un administrador central de ventanas en el flujo inspeccionado. SocialController observa las ventanas existentes y se abstiene de abrir el perfil si ShopHUD, PremiumShopHUD, SettingsGUI, CrateOpeningHUD, solicitud de trade o TradeHUD ocupan la presentación. Si se abre otra ventana después, cierra el perfil sin modificar el estado o los controladores de esas ventanas. No interfiere con QueueFrame.

## 4. SelfProfile y OtherPlayerProfile

| Modo | Origen | Identidad autoritativa | Trade |
|---|---|---|---|
| SelfProfile | ProfileButton | Player autenticado de OnServerInvoke, sin parámetro target | Visible/Active/Selectable/AutoButtonColor en false |
| OtherPlayerProfile | ProximityPrompt existente | UserId validado, disponibilidad y distancia ≤10 | Conservado; callback requiere modo ajeno y UserId diferente |

El servidor asigna ProfileMode; el cliente comprueba su coherencia con UserId antes de representar. No se acepta un booleano cliente para permisos. El endpoint Inspect original sigue rechazando autoinspección por proximidad. Los prompts y Targeting no fueron modificados.

## 5. Seguridad del perfil propio y sesiones

SelfProfile acepta solamente la página, valida número entero finito entre 1 y 10000, aplica el mismo límite de frecuencia que Inspect/Action y obtiene la identidad del llamante. Comprueba Player conectado, correspondencia con Players:GetPlayerByUserId, perfil cargado, personaje vivo y ausencia de sesión en RoundService. No expone Coins, datos internos, diarios, tokens ni estructuras de persistencia: retorna la misma proyección pública existente.

Lobby, zonas sociales y espera en cola sin sesión admitida están permitidos. Al asignarse una sesión autoritativa, incluyendo su preparación/countdown, se bloquea la apertura. MatchId cierra inmediatamente la vista local; el servidor también invalida su registro mediante ProfileUnavailable, con revisión cada 0.25 s. Se conserva así la política restrictiva V1.0 sin modificar matchmaking.

La validación de auto-trade permanece en TradeEngine. Ocultar la UI no es la barrera de seguridad del servidor.

## 6. Reutilización y actualización de inventario

Se reutilizan PublicInventory.Profile/Build y los registros existentes de Inventory.Owned.Slaps, SlapUnits y Equipped.Slaps. Las páginas tienen 24 entradas; Previous/Next permiten recorrer el inventario completo. Una página propia fuera del tamaño actual se ajusta a la última existente.

DataUpdated funciona exclusivamente como invalidación: sus datos no se copian a la vista. Mientras el perfil propio está abierto se solicita otra proyección al servidor tras la invalidación y, como respaldo, cada dos segundos. Una comparación del contenido evita reconstruir tarjetas que no cambiaron. Equipamiento o propiedad nuevos se reflejan en la siguiente consulta autorizada. Esto es consistencia eventual acotada por el intervalo y la comunicación, no una transacción de edición.

Abrir/cerrar no modifica inventario, Coins, estadísticas o equipamiento. No hay ventas, eliminaciones, regalos ni transferencias nuevas.

## 7. Reutilización de renders 3D

Se conserva PlayerProfileHUD.MainFrame.Avatar y Social/ViewportPool para avatar con ropa/accesorios, encuadre y rotación existentes; no hay otro HUD, inventario paralelo ni controlador 3D. Se usan las mismas tarjetas/variaciones/aura de V1.0 y su presupuesto de 12 previews (dos reservados para avatares), con activación por visibilidad y limpieza al cerrar.

Las actualizaciones propias sin cambio de inventario no reinician previews; actualizar equipamiento tampoco recrea el avatar. Se conserva la limitación anterior: la representación visual usa el tratamiento existente del viewport/UI; no se afirma haber validado partículas nativas dentro de ViewportFrame ni apariencia visual en esta ejecución.

## 8. Compatibilidad con Trading

No se cambió TradeEngine, TradePolicy, transacciones ni recuperación. Se mantuvo `TradeCommitEnabled=false` y la denegación del backend real. El flujo ajeno conserva invitación y negociación; el propio oculta y desactiva Trade y su callback rechaza un destino propio. Las regresiones V1.0 siguen pasando. No se realizaron transferencias reales.

## 9. Sonidos y animaciones

Se reutilizan SocialController.Sound y las animaciones Tween existentes: hover del botón, click, apertura/cierre del HUD y selección de tarjeta. No se encontró un módulo UIEffects central para este flujo; no se duplicó un sistema de efectos.

Los nueve Sound de PlayerProfileHUD.Audio permanecen con SoundId vacío (Open, Close, Click, Hover, Accept, Confirm, Cancel, Error, TradeCompleted). Son placeholders pendientes de IDs del desarrollador; por ello **no se promete audio audible**. No se inventaron IDs. La lógica omite reproducir placeholders vacíos.

## 10. Pruebas aisladas y matriz

`tests/PlayerInventoryV11.results.txt`: 121 aserciones V1.0 + **104 aserciones nuevas V1.1**. Se ejecutan métodos reales de SocialService/SocialController con jugadores, GUI, scheduler y remotos simulados; no un servidor de Studio.

| Comprobación solicitada | Evidencia automatizada / estática | Validación real pendiente |
|---|---|---|
| 1–3. Botón, LocalPlayer y UserId | PASS: Activated llama endpoint propio sin target/mode y recibe su identidad | Pulsación real PC/móvil |
| 4–6. Username, DisplayName, estadísticas | PASS: DTO y asignación de textos del controlador real | Legibilidad y tamaño de pantalla |
| 7–8. Inventario y variaciones | PASS: mapper real, propiedad, equipamiento, refresco y páginas | Recorrer todas las páginas reales |
| 9. Previews 3D | PASS estructural: mismo pool y llamadas al renderer; presupuesto y jerarquía preservados | Avatar, encuadre, rotación, aura/Highlight y rendimiento visual |
| 10. Trade oculto/desactivado | PASS: cuatro propiedades y modo propio del controlador | Ausencia visual/interacción real |
| 11. Auto-trade | PASS: rechazo del handler/engine real con fixtures | Intento manual si se desea |
| 12–13. Otros perfiles y Trade | PASS: ruta original, modo ajeno y controles reactivados | Dos clientes reales |
| 14. Inmutabilidad | PASS: datos antes/después idénticos; no mutadores agregados | Observar mismo inventario al cerrar |
| 15–16. Limpieza y reapertura | PASS: releases, conexiones rastreadas, Init/Start idempotentes, respuesta/fade tardíos | Observación de recursos en cliente real |
| 17. Sesión bloquea/cierra | PASS: RoundService simulado, evento MatchId, ProfileUnavailable y CharacterRemoving | Inicio real de partida |
| 18. Matchmaking | PASS: 359 aserciones de regresión, fuente intacta | Permanecer en cola y entrar a partida |
| 19. Trading V1.0 | PASS: 121 aserciones anteriores, commit siempre deshabilitado | Negociación con dos clientes, sin transferencia |
| 20. Shops | PASS: fuentes/recursos y hashes nativos conservados; pruebas de ventanas y regresiones | Abrir/cerrar Shop y Premium desde sus accesos |

Regresiones adicionales: matchmaking **359**, protección de víctima **150**, habilidades **164**, economía **30 + 86**, Premium Shop **93**, cajas **1375**. Total: **2482 aserciones** (incluye 121 +104 sociales). No equivalen a aprobación visual, móvil o multijugador real.

## 11. Compilación

PASS: `luau-compile --null` sobre **172 scripts fuente y dos specs**; cero errores de sintaxis. No se presenta como un análisis completo de tipos de Roblox.

## 12. Builds Rojo

PASS: `rojo build default.project.json` y `rojo build studio-safe.project.json`. Artefactos y logs `tests/PlayerInventoryV11.*project.json.rbxlx/.log`. Se preservaron las entradas previas de ambos proyectos. No se importaron ni sincronizaron lugares completos.

## 13. Git diff e integridad

PASS: `git diff --check`. `tests/PlayerInventoryV11.checks.json` contiene compilación, salidas de suites/builds y comparación de integridad. Solo tres fuentes preexistentes cambiaron respecto del baseline V1.1; las entradas previas Rojo se conservaron. No se ejecutaron operaciones destructivas de Git, commit ni push.

## 14. Sincronización e inspección Studio Edit

Instancia: `672a802c-b070-4ff0-9c2f-1b563d30e6a1`, SlapDuels 2.0 [EVENTOS DE HALLOWEEN], PlaceId `107328891970677`, GameId `10769217377`.

Antes de escribir se compararon SHA-256 normalizados de Source y ScriptEditorService:GetEditorSource contra el respaldo. Los tres scripts coincidían y no había borradores distintos. UpdateSourceAsync repitió la guarda en su callback y después se verificaron ambos hashes contra la fuente local.

Se creó ProfileButton en PlayerHUD y SelfProfile en Remotes.Social. Inspección posterior: exactamente uno de cada uno, clases correctas, botón visible/activo, jerarquía PlayerProfileHUD completa. PlayerProfileHUD, ShopHUD, PremiumShopHUD, MatchHUD, MatchmakingHUD y EndCinematicHUD conservan sus hashes nativos. También se conservan todos los hijos previos de PlayerHUD.

El resolvedor en Edit confirmó `Environment=Studio`, `ProviderName=InMemory`, `WritesToCloud=false`; TradeCommitEnabled continúa false. Es verificación del resolvedor en Edit, **no evidencia de un servidor Play iniciado**. No se inicializó Bootstrap ni se accedió a perfiles cloud.

Evidencias: `tests/PlayerInventoryV11.studio-edit.json`, `.sync-manifest.json`, `.checks.json`. La instalación existe en el DataModel Edit de la sesión; se preservó el lugar abierto sin forzar un guardado a disco.

## 15. Guía de validación manual del desarrollador

1. En Explorer Edit, comprobar `StarterGui.PlayerHUD.ProfileButton` y `ReplicatedStorage.Remotes.Social.SelfProfile`. Guardar el lugar localmente cuando corresponda, preservando tus cambios artísticos.
2. Iniciar vos la prueba con dos clientes. Antes de interactuar, revisar Output del servidor: Studio, InMemory y WritesToCloud=false; Trading real deshabilitado. Si no coincide, detener la validación.
3. En lobby, pulsar MI PERFIL. Confirmar nombre/username, estadísticas conocidas, texto de nivel/EXP pendiente, avatar completo con accesorios y sus Slaps/variaciones/equipamiento. Trade no debe verse ni recibir input. Recorrer páginas y scroll.
4. Seleccionar tarjetas y cerrar/reabrir varias veces. Revisar que no queden cámaras/WorldModels del pool al cerrar ni se dupliquen handlers. Los sonidos seguirán mudos hasta asignar SoundIds reales a los placeholders.
5. Usar el flujo de equipamiento/propiedad existente en el entorno InMemory y volver a consultar; con el perfil abierto debe reflejarse en aproximadamente dos segundos más la comunicación. No fabricar transferencias reales ni cambiar persistencia para esta prueba.
6. Con el segundo cliente, inspeccionar al otro jugador mediante su prompt existente, comprobar perfil ajeno y botón Trade. Invitar/negociar solo si se desea validar V1.0; el commit debe seguir rechazado.
7. Abrir Mi Perfil mientras se espera en cola sin sesión admitida: debe permitirse y no alterar la reserva. Completar la cola; al asignarse la sesión debe cerrarse el perfil y permanecer bloqueado durante preparación/partida. Reabrir tras regresar al lobby.
8. Abrir/cerrar Shop, Premium Shop y Settings desde sus flujos habituales: no deben coexistir sus ventanas con el perfil. Una apertura de caja tampoco debe admitir el perfil.
9. Repetir con emulación móvil/PC y distintos tamaños: botón accesible, Close visible, identidad/estadísticas legibles, scroll y avatar encuadrados. Ajustes artísticos posteriores requieren evaluar el resultado visual, aún no observado aquí.
10. Si falla, enviar captura, Output, modo Self/Other, estado de sesión/cola, página, tamaño de pantalla y secuencia exacta. Si hay error remoto, incluir su Reason; no incluir perfiles privados ni credenciales.

**Estado final:** implementación y verificación estática/Edit completas; aceptación visual y multicliente pendiente del desarrollador. Se detiene esta fase para esa validación.
