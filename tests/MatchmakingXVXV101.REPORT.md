# Matchmaking XvX V1.0.1 — cancelación prematch sin teletransporte

Fecha: 2026-10-20. **Corrección implementada y sincronizada en Edit; validación funcional manual pendiente.** No se inició Play, Run, Team Test ni Start Server; no se controlaron personajes, publicaron cambios, hicieron commits/push ni escrituras cloud.

## Causa raíz demostrada

Durante `MatchCountdown` (los cinco segundos iniciales, antes del traslado), `_runSession` detectaba la salida de un pad y llamaba a `_cancelMatchPreparation("PlayerLeftQueuePad", sessionId)`. Esa función entraba en `CloseSession`, el mismo coordinador utilizado para cerrar una partida real.

En la versión anterior, `RoundService.CloseSession` ejecutaba el paso **RestoreAndReturn** sin distinguir si alguien había ido a la arena: obtenía todos los participantes y llamaba a **SpawnService.ReturnPlayersToLobby**. Esta última función termina en `TeleportCharacterToSpawn(player, lobbySpawn)`. Ese es el teletransporte incorrecto. No lo provoca TeleportService de Roblox ni un SpawnLocation que se active por salir del pad.

Fuentes responsables: `src/server/Services/RoundService.luau`, funciones `_cancelMatchPreparation`, `CloseSession` y paso RestoreAndReturn; `src/server/Services/SpawnService.luau`, `ReturnPlayersToLobby`. Se mantuvo la detección de volúmenes de MatchmakingService y su gracia de 0,8 s; no se reescribió con Touched/TouchEnded.

## Separación de estados y frontera física

`CloseSession` continúa siendo el punto de entrada común, pero ahora despacha la preparación **sin traslado efectivo** hacia `_closePrematch`. El camino de una partida activa permanece separado.

La preparación puede estar en Waiting, MatchReady, MatchCountdown, MapSelection o MapLoading. Se contempla también un StartCountdown sin traslado como caso defensivo. Para usar la rama prematch no debe haber traslado registrado, GameplayRound ni Results.

`SpawnService.TeleportCharacterToSpawn` registra **ArenaTransferred** y **TransferredPlayers[player]** inmediatamente después del PivotTo efectivo hacia un spawn de arena. Nunca marca un retorno al lobby como transferencia de entrada. La frontera no es simplemente que haya terminado el contador o se haya abierto la votación: es que haya ocurrido el traslado.

Si falta SpawnService durante MapLoading, ahora se cancela de forma segura en lugar de continuar hacia Playing sin posicionamiento.

### Cancelación normal, antes de mover a alguien

`_closePrematch`:

1. Comprueba la identidad de la sesión registrada y que no hubo traslado.
2. Marca Closing/Cancelled y PreparationCancelled, cancela la tarea identificada y limpia votos/tiempo restante.
3. Si ya había un mapa clonado sin jugadores trasladados, destruye únicamente esa instancia/slot. Un fallo de destrucción conserva el registro para reintento, como protección de recursos.
4. Emite **Waiting con PrematchCancelled=true**, identidad SessionId/StateVersion y CountdownToken. No emite MatchResult, victoria/derrota, ReturningToLobby ni EndCinematic.
5. Retira la identidad de preparación de los jugadores y libera **los registros de RoundService**, sin borrar los ocupantes de la cola.
6. Solicita refrescar el snapshot de esa zona y vuelve a la disponibilidad normal.

No llama a ReturnPlayersToLobby, teleport, LoadCharacter, recuperación de ragdoll, limpieza de combate, entrega de premios o reseteo de controles. Por tanto, esta rama no cambia la posición de quien se quedó ni la de quien salió.

### Fallo de traslado parcial

Si ya se movió uno o más jugadores, se utiliza el cierre/recuperación existente. Mientras no haya comenzado GameplayRound, **RestoreAndReturn selecciona solo TransferredPlayers**. Los participantes que todavía estaban sobre sus pads no se incluyen en el lote de retorno.

Ese retorno es una recuperación de un traslado que sí ocurrió; no es la cancelación normal del countdown. El harness comprueba un caso de cuatro participantes donde solo uno fue marcado como trasladado y solo ese jugador vuelve mediante el adaptador de retorno. La recuperación física real requiere validación humana.

Durante Playing y PointRestartCountdown se conservan las reglas de abandono, resultado, cierre y retorno existentes. El reinicio de tres segundos después de un gol no se trata como la preparación inicial de cinco segundos.

## Identidad del countdown y callbacks tardíos

Cada intento obtiene el SessionId GUID nuevo de AdmitSession. Esa identidad es el token único de preparación y también viaja como CountdownToken en el payload. No se reutiliza un contador entre sesiones ni se reanuda el tiempo anterior.

Al cancelar se invalida la sesión, se cancela SessionThread y se libera su registro. Las continuaciones de `_runSession` verifican ese SessionId/estado registrado después de las esperas; una llamada vieja para el ID retirado no puede iniciar ni cancelar su reemplazo. La capacidad sigue limitada a una sesión.

MatchController conserva una lista de SessionIds retirados y rechaza sus mensajes antes de intentar volver a vincular el HUD, incluso si todavía tiene un atributo MatchId antiguo por replicación. La cancelación detiene su animación y oculta countdown/votación sin presentar fin de partida. La música se ajusta al estado real de cola; no se invoca la cinemática.

## Entrada/salida y jugadores que permanecen

MatchmakingService sigue usando GetPartBoundsInBox, FIFO, deduplicación de partes/avatares, cupos por equipo y gracia de **0,8 segundos**. Una ausencia breve que entra dentro de esa tolerancia no se interpreta como una nueva salida confirmada ni fuerza reinicios por jitter.

Después de actualizar CurrentRed/CurrentBlue, solicita a `CancelPreparationIfOccupancyLost` verificar la preparación de **esa ZoneId**. Si un integrante del roster dejó de estar, cancela el inicio pendiente sin esperar a que termine otro segundo del contador. No interviene sobre una partida ya trasladada ni sobre otra zona.

`ReleasePreparation` no vacía CurrentRed, CurrentBlue, PadOccupants ni el orden de llegada de los presentes. Solo invalida una reserva si su token coincide con el de la preparación que se cierra; un token viejo no puede borrar una reserva nueva. Marca un refresco del QueueSnapshot para que los ocupantes vean el cupo faltante incluso cuando el estado numérico no haya cambiado desde el último envío.

Cuando se completa otra vez el equipo, el recorrido existente crea una nueva reserva/sesión y un **countdown nuevo desde cinco**. En 2v2 quedan dos Red y un Blue esperando cuando sale el cuarto; el reemplazo ocupa la plaza correspondiente sin mover a los tres restantes.

Además, `ArePlayersInZone(..., requirePhysical=true)` reutiliza el mismo detector de volúmenes para una consulta actual de todos los integrantes antes de cargar/transferir la arena. No se acepta como única prueba una ocupación retenida por gracia ni un snapshot antiguo. Los spawns siguen prevalidándose mediante el resolver y lote de V1.0.

## Archivos modificados

Código de producción, únicamente:

- `src/server/Services/RoundService.luau`: despacho prematch, cancelación por ocupación, token, validación física pretraslado y retorno selectivo en fallo parcial.
- `src/server/Services/MatchmakingService.luau`: aviso de salida confirmada, liberación limitada a la reserva propia, refresco de snapshot y consulta física final opcional.
- `src/server/Services/SpawnService.luau`: registro de quién fue trasladado efectivamente; sin mover ni editar SpawnParts.
- `src/client/Controllers/MatchController.luau`: cancelación visual y rechazo de mensajes de sesiones retiradas.

Pruebas: nueva `tests/MatchmakingXVXV101.extension.luau`; ampliación del runner/fixture V1.0 para scheduler, volúmenes y tipos UI simulados. La expectativa antigua de que cancelar preparación retornaba a dos jugadores se reemplazó por la expectativa correcta de **cero retornos por prematch**; la comprobación de retorno de una partida activa se conserva.

Copias previas y manifiesto de fuentes/recursos: `tests/assets/backups/MatchmakingXVXV101`. No se borró ningún respaldo anterior.

Sin cambios: Config y flags de modos, resolución BlueTeam/RedTeam.SpawnN, los ocho SpawnParts, mapa/snapshot, selección de mapas, economía, habilidades, combate, Slap Crates, Premium Shop y EndCinematic. Tampoco se rediseñó ni reemplazó ningún HUD físico.

## Verificación y matriz solicitada

**56 aserciones nuevas** y 49 de V1.0: **105** en el harness de matchmaking. Se ejecutan módulos reales sobre tablas, un scheduler de coroutines con reloj determinista y un adaptador de consulta espacial. No son pruebas de jugadores reales.

Regresiones existentes: SlapVictimProtection 150; AbilityMultiplayerFixV1.regression 164; EconomyBalanceV1 30; EconomyBalanceV1.shop 86; PremiumShopV11 93. **Total de esta ejecución: 628 aserciones aisladas aprobadas.**

| # | Prueba | Evidencia ejecutada |
|---:|---|---|
| 1 | Ambos ingresan y empieza 1v1 | PASS aislado: `_updateQueue` → StartTeamMatch → coroutine real |
| 2 | Sale uno durante countdown | PASS: consulta espacial simulada deja de devolverlo, se agota la gracia |
| 3 | Cancelación | PASS: sesión cerrada y registro liberado |
| 4 | Cero teletransportes | PASS: adaptador de retorno sin llamadas; tampoco resultados, premios ni cleanup competitivo |
| 5 | Permanece el restante | PASS: CurrentRed y ocupación conservadas |
| 6 | Cupos actualizados | PASS: QueueSnapshot con participante faltante |
| 7 | Nuevo participante | PASS: detección y reserva de reemplazo |
| 8 | Nuevo contador desde cinco | PASS: evento 5 con otro SessionId |
| 9 | Countdown viejo no inicia | PASS: reejecutar su continuación no toca al sucesor |
| 10 | Salida en último segundo | PASS: no alcanza votación/transferencia en el escenario confirmado |
| 11 | Dos salidas cercanas | PASS: ambos lados vacíos sin teleport ni bloqueo |
| 12 | Sale/regresa | PASS: salida confirmada reinicia; ausencia menor a 0,8 s conserva tolerancia original |
| 13 | Cancelaciones repetidas | PASS: tres ciclos por tamaño de equipo |
| 14 | Timers antiguos | PASS: tareas anteriores retiradas del scheduler y coroutine cancelada |
| 15 | Reservas | PASS: capacidad libre y token viejo no borra una reserva más nueva |
| 16 | Sale uno de cuatro | PASS aislado con 2v2 |
| 17 | Permanecen tres | PASS: conteos y equipos 2+1 sin retorno |
| 18 | Reemplazo completa cuatro | PASS: nuevo jugador ocupa el cupo faltante |
| 19 | Nuevo countdown completo | PASS: cinco segundos completos hasta MapSelection para cuatro destinatarios |
| 20 | Equipos correctos | PASS: Red preservado y reemplazo en Blue |
| 21 | Abandono durante Playing | PASS regresión V1.0: continúa si queda un integrante por equipo |
| 22 | Retorno de partida real | PASS aislado del CloseSession activo con adaptador de retorno, no partida multicliente |
| 23 | Sin EndCinematic por cola | PASS: ninguna llamada de resultado/cinemática en cancelación prematch |
| 24 | Sin recompensas por cola | PASS: función de premios nunca invocada; economía existente conserva idempotencia |
| 25 | Selección de arena | Código/recursos de selección sin cambios; flujo completo llega a MapSelection al completar contador |
| 26 | Spawns intactos | PASS de integridad del mapa/snapshot y resolver V1.0; no escrituras a los ocho marcadores |
| 27 | 1v1 | PASS aislado; validación de jugabilidad pendiente |
| 28 | 2v2 | PASS aislado; validación de cuatro clientes pendiente |
| 29 | 3v3 deshabilitado | PASS configuración sin cambios |
| 30 | 4v4 deshabilitado | PASS configuración sin cambios |

Adicionales: fallo de traslado parcial retorna solo al trasladado; cierre de votación antes de arena no mueve a nadie; consulta física final rechaza presencia retenida sin contacto actual; el controlador real de HUD no acepta un evento viejo ni oculta la cuenta nueva.

Compilación Luau de **162 scripts** y specs: PASS. Ambos builds Rojo actuales: PASS. `git diff --check`: PASS, con advertencias de conversión LF/CRLF preexistentes. No se regeneraron ni alteraron configuraciones Rojo para esta corrección.

Evidencia: `MatchmakingXVXV101.results.txt`, logs de compilación/build/regresión, `MatchmakingXVXV101.checks.json` y `MatchmakingXVXV101.studio-edit.json`.

## Studio Edit e integridad

Los cuatro scripts se sincronizaron puntualmente mediante ScriptEditorService, con preflight de SHA-256 contra la versión anterior y comprobación de que no hubiera drafts distintos en el editor. Se verificaron fuentes finales contra el repositorio.

Serializaciones nativas antes/después idénticas:

- ServerStorage.Maps.Levels: `a1da792e7d79b65b85f78fb2919aa4f35da996d504698b6e97f00c1bcd0aceb2`.
- StarterGui.MatchmakingHUD: `ec941de59e6676587ca28e652d500bd7a8fa96dcc343a3ce1eed1518e6f50ea1`.
- StarterGui.MatchHUD: `0bd648c4a16fa25ce4c554c9c2736a30756f9cae390e4d96d059ace2d0453cae`.

Observado: **Studio / InMemory / WritesToCloud=false**, Edit y ActiveMatches=0. La zona 2v2 conserva sus siete atributos. 1v1/2v2 siguen habilitados, 3v3/4v4 deshabilitados y concurrencia=1.

## Pruebas manuales exactas — desarrollador

1. Iniciar vos un runtime nuevo con dos clientes; confirmar primero Studio/InMemory/WritesToCloud=false en Output.
2. Entrar Red/Blue en 1v1. Cuando marque 4 o 3, sacar a Blue fuera del volumen del pad durante más de la gracia de 0,8 s. El countdown debe desaparecer; **ninguno debe cambiar de posición por teleport/respawn**. Red debe continuar esperando y Blue quedar fuera.
3. Entrar con Blue u otro jugador. Debe empezar un contador completo nuevo 5→1, sin reanudar el anterior. Repetir varias veces, incluyendo una salida cerca de 1, salida de ambos y regreso rápido. Una ausencia breve dentro de la tolerancia no debe generar cancelaciones falsas.
4. Completar el nuevo countdown sin salir, votar y verificar que el inicio real sigue funcionando: Spawn1 por equipo, Slap, movimiento, gol/reinicio, Kill y retorno al lobby al terminar la partida.
5. Repetir con cuatro clientes en 2v2. Sacar al segundo Blue: deben quedar 2 Red + 1 Blue esperando, todos en su posición. Reemplazar el cuarto y comprobar contador nuevo, equipos, Spawn1/Spawn2 y una sola sesión.
6. Durante una partida ya en arena, probar abandono parcial y finalización real: deben conservarse los comportamientos de V1.0 y el retorno posterior al lobby. No debe confundirse este retorno legítimo con la cancelación prematch.
7. Revisar un cliente ajeno/otra cola: no debe sufrir desplazamiento, resultado ni cambios del countdown que no le pertenece. Verificar los cupos y que no quede una cuenta anterior superpuesta a la nueva.

Capturar Output servidor/cliente, modalidad, instante del contador, tiempo aproximado fuera del pad y si hubo salto de posición o nuevo Character. Para fallos parciales durante carga de arena, indicar quién llegó a trasladarse antes del error: ese caso tiene recuperación selectiva.

**No hay PASS funcional real todavía.** Queda pendiente tu validación manual de ambos tamaños de equipo y los efectos de replicación/renderizado. La implementación se detiene aquí.
