# Player Inventory & Trading V1.0

Fecha: 2026-10-20. **Perfil, inventario visual y negociación implementados en Studio Edit para revisión manual. Transferencia real y recuperación durable BLOQUEADAS.** No se ejecutó Play, Run, Team Test, Start Server, compras, transferencias, publicaciones, commits ni push.

## 1–5. Inventario, estadísticas, propiedad, duplicados y política

Auditoría previa: `PlayerInventoryTradingV10.audit.md`.

Se reutiliza exclusivamente `PlayerService._data[player].Inventory`: `Owned.Slaps[SlapId:VariationId]`, `Equipped.Slaps`, `SlapUnits[UnitId]` y el journal existente `CrateOperations`. No se creó otro inventario, wallet ni mecanismo de concesión. Las unidades individuales de cajas ya tienen UnitId, OwnerUserId, RewardId, SlapId, VariationId y procedencia; las propiedades legacy/default no se convierten artificialmente en copias transferibles.

Los duplicados existentes aparecen separados por UnitId. La política de duplicados de cada caja sigue intacta. Equipamiento sigue siendo cosmético por RewardId, por lo que varias copias de un mismo cosmético pueden mostrar su estado equipado; no se afirma que el equipamiento actual elija una copia individual.

Wins/Losses/Kills provienen del perfil vigente; Kills se presenta como TotalKills. No se guardó un segundo contador. Nivel/Experience/ExperienceRequired permanecen sin valor: `Available=false` y texto «Nivel y EXP pendientes». No se concedió experiencia ni se inventó una fórmula o nivel ganado.

`Trading.TradePolicy` autoriza explícitamente Classic y las once variaciones distintas de Basic, siempre que exista una unidad real, propiedad vigente y procedencia de caja ordinaria comprobada en una operación Completed que contenga esa unidad. Se rechazan Classic:Basic, legacy sin unidad, Slaps no autorizados, unidades bloqueadas, Premium, temporales/de prueba, ediciones limitadas y procedencia desconocida. **Origin=Crate no basta**: se verifica también la caja contra el catálogo no Premium y su journal. No se comercializan Coins, cajas, habilidades ni Kill Effects.

Una reserva de oferta es metadata local de negociación, no una reserva persistente ni un cambio de inventario. Mientras el commit está desactivado, equipar/cancelar/confirmar no transfiere ni retira el Slap. Transferir la última copia equipada y recalcular entitlements son responsabilidades pendientes del backend durable; no se implementó un fallback de equipamiento que pudiera dispararse por una simulación.

## 6–13. HUD, selección, previews, efectos y audio

Recursos persistentes nuevos en Edit y sus proyectos Rojo:

| Objeto físico | Archivo | Componentes |
|---|---|---|
| `StarterGui.PlayerProfileHUD` | `src/ui/PlayerProfileHUD.project.json` | MainFrame, Avatar ViewportFrame, identidad, estadísticas, progresión pendiente, Collection con scrolling/grid, paginación, Trade/Close, CardTemplate y Audio. 42 descendientes. |
| `StarterGui.TradeRequestHUD` | `src/ui/TradeRequestHUD.project.json` | MainFrame, Avatar, Requester, Countdown, Accept/Decline/Close, Status y Audio. 25 descendientes. |
| `StarterGui.TradeHUD` | `src/ui/TradeHUD.project.json` | Columnas Mine/Theirs, identidades y avatares, ofertas, inventario propio paginado, estados de aceptación, botones Accept/Confirm/Cancel, Status, CardTemplate y Audio. 57 descendientes. |

Los tres comienzan Enabled=false, tienen ResetOnSpawn=false, límites de tamaño y dimensiones relativas. Las cartas muestran nombre, variación, rareza/color del catálogo, propiedad/equipamiento, elegibilidad y **UnitId completo** para distinguir copias. Las propiedades base muestran que no tienen unidad comerciable.

La detección local hace raycast a intervalos de 0,12 s. Ignora al propio jugador y exige un Character válido a diez studs o menos. Se usa el mouse en PC y el centro de pantalla en touch/gamepad. Se crea un Highlight local sobre el Character seleccionado y un ProximityPrompt local sobre su root: «Ver perfil», hold 0,5 s, distancia 10, tecla E, gamepad X y ClickablePrompt para touch. Se retiran al cambiar de objetivo, abrir paneles o entrar en sesión. No se replica una selección cosmética a otros jugadores.

La solicitud inicial envía únicamente TargetUserId; la paginación agrega el número de página. El servidor vuelve a validar conexión, perfil Loaded, estado autoritativo de RoundService, identidad distinta y distancia, con rate limit. Un atributo local MatchId es solo una ayuda de presentación, nunca permiso de servidor. El objetivo debe estar presente en el servidor; no hay inspección de cuentas remotas arbitrarias.

Avatar: clon visual local del Character actual, conservando ropa/accesorios, eliminando Scripts/Tools/Sounds, normalizando orientación hacia la cámara y colocándolo en WorldModel dentro del ViewportFrame. Se restaura inmediatamente Archivable del Character fuente. Cámara independiente que ajusta distancia por bounding box y aspecto; giro suave. No se insertan avatares de UI en Workspace ni se mueve el personaje real.

Slaps: se reutiliza `SlapVariationPreviews.<SlapId>.<VariationId>` y fallback `CrateRewardPreviews.<SlapId>`, con Catalog y `SlapCrates.Appearance` sobre los recursos de `SlapVariationEffects`. Rotación local, encuadre por extensión, iluminación moderada y acento/aura UI del color registrado. Las partículas clonadas se desactivan en los ViewportFrames: **no se declara que los efectos de partículas de Workspace se reproduzcan allí**. La presentación de aura de estas cartas es UI; revisar visualmente las doce variaciones antes de aprobar su equivalencia artística.

Presupuesto: máximo doce previews activos, reservando espacio para avatares y activando renders de cartas solo cuando intersectan su ScrollingFrame. Página de 24 artículos; al salir de vista/cerrar se destruyen WorldModel y Camera, se retira CurrentCamera y se desconectan resize/destroy listeners. Hay un único bucle local de render para el pool. El controller no bloquea movimiento ni toma ownership de la cámara de juego. [Referencia de ciclo de vida WorldModel](https://create.roblox.com/docs/reference/engine/classes/WorldModel).

Audio: cada HUD tiene nueve Sound objects (Open, Close, Click, Hover, Accept, Confirm, Cancel, Error, TradeCompleted), volumen 0,25 y SoundId vacío. Se inspeccionaron SoundService y SettingsController; el último regula música, no un mixer de SFX sociales. No se reutilizaron música/countdowns competitivos como sonidos de interfaz ni se inventaron IDs. **El desarrollador debe asignar los audios**. El controller omite sonidos vacíos y evita superponer sus propios sonidos. TradeCompleted no suena para una simulación cancelada.

Se implementaron apertura/cierre por Tween con token que impide que un cierre antiguo oculte una reapertura, hover de botones, acento de selección y transición de color de aceptaciones. La suavidad, legibilidad, tacto y encuadre solo pueden aprobarse visualmente mediante la prueba manual.

## 14–18. Servidor, estados, confirmación, remotes e integración

Arquitectura:

```text
ReplicatedStorage.Shared.SocialConfig
ReplicatedStorage.Remotes.Social.{Inspect,Action,Updated}
ServerScriptService.Services.SocialService
ServerScriptService.Services.Trading
  PublicInventory / TradePolicy / TradeEngine
  TradeTransactionService / TradeRecoveryService
StarterPlayer.StarterPlayerScripts.Controllers.SocialController
StarterPlayer.StarterPlayerScripts.Social.{Targeting,ViewportPool}
```

Bootstrap registra SocialService después de los servicios existentes. ClientBootstrap ya descubre los controllers, por lo que no se modificó. Validaciones distribuidas entre SocialService, TradePolicy y el motor; no se duplicó otro servicio de inventario.

`Inspect` devuelve un DTO público paginado: identidad pública, tres estadísticas, estado de progresión y artículos. No retorna Coins, perfil completo, tokens, recibos, IDs de compra, journal, leases o configuración privada. UnitId sí se expone como identidad de artículo autorizada por el contrato. `Action` valida remitente real, tipo/tamaño de argumentos, revisión, pertenencia y estado. `Inventory` solo permite consultar el inventario propio dentro de un trade autorizado, con el mismo mapper público. `Updated` envía ofertas exclusivamente a ambos miembros; los IDs originales negativos de Studio se conservan y las claves de DTO son strings para evitar ambigüedades de serialización.

Flujo implementado:

```text
Requested → Negotiating → SafetyCountdown → FinalConfirmation
                    ↘ Cancelled               ↓
                               Cancelled / TradeCommitDisabled
```

Solicitudes: 15 s, una pendiente por jugador, cooldown de 15 s del solicitante y rate limit de 0,25 s. No se acepta en nombre del otro. La distancia se comprueba al invitar y al aceptar la invitación. Expiración/desconexión/rechazo liberan estado. Respawn cancela la negociación **sin reiniciar el cooldown de invitaciones**.

Ofertas: máximo seis unidades por lado, IDs exactos, sin duplicados, reservadas al trade y con política/propiedad revalidadas. Cambiar una oferta incrementa Revision, invalida ambas aceptaciones y confirmaciones. Tras ambas aceptaciones se bloquean las modificaciones y comienza el countdown de cinco segundos. Al vencer, cada persona debe pulsar Confirmar; no hay confirmación automática. Se rechazan clicks de revisión anterior. Los paquetes llevan Sequence para que el controller descarte estados atrasados del mismo trade.

Dos confirmaciones válidas llegan al gate de transacción, que devuelve TradeCommitDisabled: la negociación termina como **Cancelled con explicación de prueba, no Completed**. No se entra en Committing ni se fabrican recibos, journal durable o transferencias. Reenviar Confirm no vuelve a llamar al gate.

SocialService consulta `RoundService:GetSessionForPlayer` en el servidor. Una preparación ya registrada también bloquea el acceso; se cancela la negociación si alguno entra a sesión, pierde Character, deja de estar Ready o se desconecta. La comprobación se realiza en las acciones y en el tick de mantenimiento. No se modificaron reglas, sesiones, countdown ni políticas de abandono de 1v1/2v2/3v3/4v4.

## 19–21. Persistencia, garantías, límites y flags

**La durabilidad de trading NO está implementada.** La auditoría confirmó que el puente de ciclo de perfiles requerido por Premium Shop V1.1 sigue faltando. El motor por perfil no convierte dos perfiles en una transacción atómica. Un SavePlayer legacy podría sobrescribir datos de otro dueño; no sería seguro añadir un journal aparte sin integrar también todos los guardados/mutadores y cargas.

`TradeTransactionService.Commit` no tiene adaptador ni acceso a DataStore y siempre bloquea. `TradeRecoveryService.Status()` declara `DurableRecoveryAvailable=false`, y Reconcile devuelve DurableRecoveryUnavailable. Son barreras explícitas, **no un sistema de recuperación que simula éxito**. Cambiar solo un flag no abre transferencias en producción ni Studio.

El diseño pendiente está en `PlayerInventoryTradingV10.durable-protocol.md`: intención inmutable, journal de decisión, dos preparaciones persistidas, fencing de todas las mutaciones/cargas/guardados, aplicación idempotente por perfil, cuarentena hasta ambas aplicaciones y recuperación offline entre servidores. Incluye los fallos y migraciones que faltan demostrar. No se creó un DataStore ni se modificó el Universe ID.

Flags finales: ProfileInspectionEnabled=true; TradeInvitationsEnabled=true; TradeCommitEnabled=false. Máximo seis Slaps por lado, invitación 15 s y seguridad 5 s. No se acreditan intercambios reales en InMemory.

## 22–23. Archivos creados/modificados y respaldo

Diez fuentes nuevas:

- `src/shared/SocialConfig.luau`.
- `src/server/Services/SocialService.luau`.
- `src/server/Services/Trading/PublicInventory.luau`, `TradePolicy.luau`, `TradeEngine.luau`, `TradeTransactionService.luau`, `TradeRecoveryService.luau`.
- `src/client/Controllers/SocialController.luau`.
- `src/client/Social/Targeting.luau`, `ViewportPool.luau`.

Tres proyectos UI nuevos: PlayerProfileHUD, TradeRequestHUD, TradeHUD. Tests/spec, audit, protocolo, manifests, resultados y herramientas bajo `tests/PlayerInventoryTradingV10*` y `tests/tools/{social_ui_v10,run_social_v10,validate_social_v10}.py`.

Únicos archivos preexistentes modificados: `src/server/Bootstrap.server.luau` (registro de SocialService), `default.project.json` y `studio-safe.project.json` (adiciones de scripts/HUD/remotes). La comparación semántica verifica que **todas las entradas previas de ambos proyectos se conservaron**. No se cambió el generador SAFE existente.

Respaldo: `tests/assets/backups/PlayerInventoryTradingV10`: fuentes previas, configuraciones, estado Git y SHA-256. Se preservaron los respaldos anteriores. No se hizo stash, reset, restore, clean, checkout, commit ni push.

## 24–27. Compilación, pruebas y builds

| Suite / comprobación | Resultado |
|---|---|
| PlayerInventoryTradingV10 | **121 aserciones PASS aislado** sobre módulos reales y adapters descartables. |
| Matchmaking XvX V1.2 | 359 PASS aislado. |
| SlapVictimProtection | 150 PASS aislado. |
| AbilityMultiplayerFixV1.regression | 164 PASS aislado. |
| EconomyBalanceV1 | 30 PASS aislado. |
| EconomyBalanceV1.shop | 86 PASS aislado. |
| PremiumShopV11 | 93 PASS aislado. |
| CrateBatchV24 | 1375 PASS aislado, incluyendo apertura/inventario/journals de cajas. |
| Total | **2378 aserciones aisladas**. No son 2378 pruebas de jugadores ni garantías durables. |
| Compilación Luau | 172 fuentes + spec social, sin errores. Último ajuste del controller recompilado. No análisis exhaustivo de tipos ni prueba de render. |
| Ambos builds Rojo | PASS con las tres UI y las fuentes finales. |
| git diff --check | PASS; advertencias de conversión LF/CRLF no son errores de whitespace. |
| Integridad | Solo los tres archivos preexistentes autorizados cambiaron; demás fuentes, inventarios, gameplay y assets locales previos intactos. |

Reproducción local, sin Studio:

```powershell
& 'C:\Users\rataatrevida\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/validate_social_v10.py
```

### Matriz de los 60 casos solicitados

PASS siempre significa el alcance aislado expresamente indicado; ninguna fila concede aprobación funcional multicliente.

| # | Caso | Estado y evidencia / límite |
|---:|---|---|
| 1 | Selección local | PASS helper de elegibilidad/rango; raycast, prompt y Highlight visual NOT RUN. |
| 2 | Autoinspección | PASS helper local y handler real de servidor. |
| 3 | Distancia | PASS handler/engine: 10, mayor a 10 y NaN. |
| 4 | Durante partida | PASS sesión autoritativa aunque el atributo local no tenga MatchId. |
| 5 | Objetivo desconectado | PASS handler/helper. |
| 6 | Respuesta sin privados | PASS DTO real: no wallet/token/meta/journal. |
| 7 | Stats existentes | PASS Wins/Losses/Kills proyectados. |
| 8 | Sin EXP aprobada | PASS Available=false y ausencia de nivel/EXP inventados. |
| 9 | Vista de Slaps | PASS proyección real/default/duplicados/páginas; render NOT RUN. |
| 10 | Limpieza Viewports | PASS Remove idempotente con WorldModel/Camera/listener adapters; fuga gráfica real NOT RUN. |
| 11 | Invitación válida | PASS motor y handler reales. |
| 12 | Invitación propia | PASS rechazo. |
| 13 | Invitación duplicada | PASS busy/pareja. |
| 14 | Expiración | PASS deadline 15 s. |
| 15 | Rechazo | PASS libera estado. |
| 16 | Jugador ocupado | PASS rechazo por Busy. |
| 17 | Jugador en partida | PASS elegibilidad autoritativa. |
| 18 | Rate limit | PASS handler real y cooldown; respawn no lo reinicia. |
| 19 | Desconexión | PASS cancelación/liberación. |
| 20 | Aceptación incorrecta | PASS tercero y solicitante rechazados. |
| 21 | Oferta válida | PASS unidad con provenance real de catálogo/journal fixture. |
| 22 | Inexistente | PASS rechazo. |
| 23 | No poseído | PASS rechazo de otra persona/owner. |
| 24 | Bloqueado | PASS locks, Premium, temporal, test. |
| 25 | Duplicado en oferta | PASS rechazo. |
| 26 | Máximo seis | PASS seis permitidos y séptimo rechazado. |
| 27 | Cambio de oferta | PASS Add/Remove incrementan revisión. |
| 28 | Invalidación de aceptaciones | PASS ambos y confirmaciones reiniciados. |
| 29 | Countdown | PASS 4,999 s bloquea; a 5 s pasa sin confirmar automáticamente. |
| 30 | Confirmación prematura | PASS rechazo. |
| 31 | Revisión antigua | PASS rechazo. |
| 32 | Dos confirmaciones | PASS llegada al gate desactivado; ninguna transferencia. |
| 33 | Cancelación | PASS antes de commit y cierre idempotente. |
| 34 | Desconexión negociando | PASS cancelación sin cambios de inventario. |
| 35 | Trade duplicado | PASS Busy y TradeId únicos. |
| 36 | Reenvíos | PASS confirmación/cancelación/revisión viejas no repiten commit. |
| 37 | Concurrencia | PASS reservas y secuenciación del motor sin yields; multiserver BLOCKED. |
| 38 | Transferir equipado | BLOCKED commit durable; PASS separado de que la simulación no altera Inventory ni Equipped. |
| 39 | Variación | PASS catálogo/procedencia/RewardId coherentes. |
| 40 | Otra reserva | PASS conflicto rechazado. |
| 41 | Registro durable | BLOCKED: no journal durable instalado. |
| 42 | Idempotencia durable | BLOCKED; solo reenvíos locales negociadores probados. |
| 43 | Fallo al guardar A | BLOCKED backend de perfiles. |
| 44 | Fallo al guardar B | BLOCKED backend de perfiles. |
| 45 | Cierre durante commit | BLOCKED; no se permite entrar a Committing. |
| 46 | Recuperación pendiente | BLOCKED; Reconcile declara unavailable. |
| 47 | Reconciliación durable | BLOCKED; contrato documentado, sin implementación. |
| 48 | Duplicación entre perfiles | BLOCKED prueba durable; gate evita cualquier transferencia actual. |
| 49 | Guardado obsoleto | BLOCKED integración de fencing para todos los mutadores. |
| 50 | Transferencia completada | BLOCKED; nunca se simula Completed como transferencia real. |
| 51 | Conflictos entre servidores | BLOCKED lease/bridge/recuperación offline. |
| 52 | Commit InMemory | PASS hard gate, incluso intentando habilitar un flag o pasar backend falso. |
| 53 | Sin escrituras cloud Studio | PASS inspección de resolver Edit y gate sin adapter; ningún servidor iniciado. |
| 54 | Inventario intacto | PASS snapshots no mutados y regresión cajas. |
| 55 | Crates intactas | PASS 1375 aserciones existentes. |
| 56 | Equipamiento intacto | PASS fuentes/estado conservados y regresión Slap; juego real NOT RUN. |
| 57 | Matchmaking | PASS 359 aserciones y fuentes sin cambios. |
| 58 | XvX | PASS aislado 1/2/3/4 por lado; multicliente NOT RUN. |
| 59 | Economía | PASS 116 aserciones de economía/shop y fuentes conservadas. |
| 60 | Premium Shop | PASS 93 aserciones; ventas y backend real siguen desactivados. |

## 28. Sincronización segura con Edit

Instancia 672a802c-b070-4ff0-9c2f-1b563d30e6a1, PlaceId 107328891970677, GameId 10769217377. Se verificó IsStudio=true e IsRunning=false antes de cada operación. No se inició ningún modo de simulación.

Se instalaron únicamente los nuevos HUD/remotes/carpetas y once fuentes (diez nuevas y Bootstrap). Antes de actualizar se comparó Source con hash esperado y GetEditorSource; cualquier draft concurrente habría abortado la escritura. Después se comprobó el SHA-256 en Source y editor. No se importó un build completo ni se ejecutó un full sync.

Hashes nativos de ShopHUD, PremiumShopHUD, MatchHUD, MatchmakingHUD y EndCinematicHUD son idénticos a la inspección inicial. No se modificaron mapas, spawns, ScenarioFinal ni configuraciones de modalidades. Los cambios de lugar del propietario permanecen en su sesión sin cerrarla, guardarla sobre otro archivo ni publicarla.

El resolver real evaluado en Edit devuelve Studio / InMemory / WritesToCloud=false. Diagnósticos de esa selección: cero GetAsync, UpdateAsync, committed writes y keys. No es una observación de Bootstrap en un servidor iniciado. Workspace.ActiveMatches tenía cero hijos.

Evidencias: `.checks.json`, `.studio-edit.json`, `.sync-manifest.json`, `.results.txt`, logs/resultados de suites/builds y respaldo. Los nuevos HUD están en el DataModel Edit y en archivos del repositorio; guardar el lugar localmente corresponde al flujo habitual del propietario, sin publicación automática.

## 29. Guía manual

1. Iniciá vos dos clientes locales. Confirmá primero Output `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false` y log SocialService `TradeCommitEnabled=false`. Si no coincide, detené la prueba.
2. Fuera de toda sesión, acercate a diez studs o menos, apuntá a otro jugador y mantené E 0,5 s. En touch/gamepad usá el centro de cámara y el prompt táctil/X. Verificá Highlight solo en ese cliente; probá distancia, autoobjetivo, pared, Character nuevo y desconexión.
3. Revisá avatar de cuerpo completo de frente, vestimenta/accesorios, Wins/Losses/Kills y progresión pendiente. Comprobá colección real, unidades separadas, equipado, nombres/variaciones, UnitIds y distinción no comerciable. Desplazá/paginá y cerrá/reabrí; revisar encuadre, rendimiento, escalado y limpieza.
4. Para ofertas se necesitan unidades ordinarias obtenidas por el sistema de cajas existente en el servidor de prueba. Classic:Basic inicial y entitlements legacy sin UnitId no sirven. No concedas unidades inventadas desde cliente ni uses producción para preparar la prueba.
5. Solicitá trade; en el otro cliente aceptá/rechazá y probá expirar los quince segundos, solicitud repetida y tercero ajeno. Ningún tercero debe ver ofertas ni recibir eventos de ese trade.
6. Añadí/retirá unidades, revisá UnitIds, oferta propia/ajena y límite de seis. Aceptá solo en A, cambiá una oferta y comprobá que ambas aceptaciones se borren. Luego acepten ambos y esperen cinco segundos. Las modificaciones se bloquean en ese paso.
7. Revisen artículos/variaciones/identidades y pulsen cada uno Confirmar. Resultado esperado: aviso de prueba sin transferencia; nunca éxito durable. **Inventario, Coins y equipado de ambos deben permanecer exactamente iguales.** No habrá intercambio real en esta versión.
8. Probá cancelar, respawn, desconexión e inicio de matchmaking durante negociación. Debe cancelarse/liberar estado sin interferir con el countdown competitivo. Respawn no debe permitir saltar el cooldown de invitaciones.
9. Repetí la negociación y una partida de cada modalidad disponible; validar crates, equipamiento, recompensas, Shops, respawn individual y retorno. No se concede PASS a estas comprobaciones por la inspección de código.
10. Para audio, asigná SoundIds aprobados a `StarterGui.<HUD>.Audio.<nombre>`; los placeholders están vacíos a propósito. Verificá volumen y ausencia de superposición. Capturá Output completo, video de perfiles/trade y Explorer de recursos/WorldModels al cerrar si aparece un fallo.

## 30. Pendientes antes de intercambios reales

Completar y autorizar el puente durable de perfiles para **todo** el ciclo de vida, journals/decisión, fencing, reservas persistentes, recuperación offline/multiserver, manejo de stock limitado, duplicados/capacidad al recibir y fallback de última copia equipada. Demostrar fallos A/B/shutdown/replays/stale saves con conservación de UnitIds. Aprobar universo aislado, migración de servidores legacy y pruebas reales expresamente autorizadas. Mantener ventas Premium, commit Trading y escrituras cloud fuera de esta entrega.

Además quedan pendientes la validación visual/multicliente del propietario y los SoundIds/artística final de las auras. No se declara terminado ni seguro un trading de producción. Se detiene la implementación en este punto para esa validación.
