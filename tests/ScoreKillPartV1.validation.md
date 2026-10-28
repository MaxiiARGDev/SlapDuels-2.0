# Score/KillPart Integration V1

Fecha: 2026-10-17. Implementación en repositorio y Roblox Studio Edit.
Shop V2 y Death Feedback/Zero-Death funcionan según validación comunicada por el
desarrollador; no se repitieron esas pruebas. Esta corrección espera validación manual.

## 1. Causa y alcance de la evidencia

RedWin/BlueWin y KillPart son sensores independientes. Tras el gol, el flujo existente
mantiene el Character y espera PointFeedback + PointResetDelay antes del reposicionamiento.
En el mapa ServerStorage.Maps.Levels se observó RedWin Y4.5 / BlueWin Y4.101 y KillPart
Y−25, tamaño334×5×248. El Character puede atravesar ambos sensores en el mismo tránsito.

Ya existía una guarda session.PointInProgress/PointScorer. Por tanto, NO sería correcto
afirmar que no había protección ni que se reprodujo exactamente su bypass:
sin Play ni trazas del evento fallido, el orden físico concreto informado por el
desarrollador queda sin demostrar. La brecha comprobada es que esa guarda temporal
no registraba una decisión común por Character/generación entre puntuación y eliminación.
Score sólo rechazaba ArenaRespawnPending; no registraba una eliminación confirmada
si una ruta no había dejado retiro pendiente. Tampoco distinguía Character de reemplazo.

Se añadió una coordinación autoritativa previa a efectos secundarios para que el
mismo tránsito no confirme ambos resultados. No se oculta el mensaje en el HUD.
Se revisaron ScoreService, RoundService, EliminationService, DeathEffectService,
MatchInstanceService, SpawnService, PointFeedbackService, ArenaRespawn y sensores,
debounces, reinicio y celebración del quinto gol, atribución y pago de Kills.

## 2. Archivos y Studio

MODIFICADOS:
- src/server/Services/ScoreService.luau
- src/server/Services/EliminationService.luau

NUEVO:
- src/server/Services/Respawn/CompetitiveTransit.luau

PRUEBAS / EVIDENCIA:
- tests/ScoreKillPartV1.spec.luau: fixtures preparados, NOT RUN.
- tests/ScoreKillPartV1.edit-evidence.json: observaciones Edit y hashes protegidos.
- tests/ScoreKillPartV1.validation.md: este informe.
- tests/assets/backups/ScoreKillPartV1.sources.before.json: Sources previos.

Instalados y verificados por MCP:
ServerScriptService.Services.ScoreService,
ServerScriptService.Services.EliminationService y
ServerScriptService.Services.Respawn.CompetitiveTransit.
Cada módulo tiene una instancia en esa ruta. Antes de reemplazar, las fuentes existentes
de Studio coincidieron con los archivos iniciales; se exigió Source exacto anterior.
Luego se verificaron Sources nuevos contra los archivos. Se preservaron ediciones previas.
No se crearon ni modificaron recursos físicos de mapas/HUDs; no se guardó/cerró el lugar.

## 3. Contrato de protección

CompetitiveTransit es un registro privado de EliminationService, sin timers, economía,
física, DataStores ni remotes. Clave: SessionId → UserId original (incluidos negativos
de Studio, sin math.abs). Cada registro conserva:
Session exacta, Player exacto, UserId, Character exacto, ArenaPhysicsGeneration,
Kind=Goal/Elimination y EventId. Para Goal, EventId es el PointId existente
SessionId_Equipo_RedScore_BlueScore proyectado para ese punto.

ScoreService conserva validaciones de sesión/equipo/zona, debounces y presencia;
añade Character vivo y contacto actual de su parte con el sensor. Tras validar,
exige TryProtectGoal y registra el tránsito antes de incrementar/pagar/notificar.
No cede entre reserva, bloqueo de scoring e incremento.
Si falta el dueño de coordinación se rechaza el punto de forma segura.

## 4. Duración y limpieza

Sin cooldown de inmunidad ni task.delay propio. Una protección Goal sigue ligada
al mismo Character durante la secuencia de punto. El reposicionamiento existente
incrementa ArenaPhysicsGeneration sobre ese MISMO Character: se conserva el registro
de gol mientras session.PointInProgress=true para cubrir esa transferencia y el countdown.
No se aplica a un Character diferente, aunque tenga el mismo UserId o generación numérica.
La generación de origen queda registrada; la extensión requiere identidad de sesión,
jugador y Character, además del estado autoritativo del punto.

ResumeScoring libera las protecciones Goal de esa sesión al reanudar Playing tras
el reposicionamiento/countdown existentes. Un registro Elimination no se libera
como Goal; sólo vale para su generación y se invalida con una vida/generación nueva.
CharacterAdded/CharacterRemoving/Destroying, cambio de MatchId y PlayerRemoving
limpian registros correspondientes. UnbindMatch los elimina al terminar/cancelar;
sus listeners también se desconectan. No se toca otra sesión.

StopScoring puede limpiar campos temporales del gol al finalizar; el registro se
limpia con UnbindMatch y las barreras Closing/GameplayFrozen/IsSessionActive ya
impiden procesar competición durante Ending.

## 5. Coordinación ScoreService/EliminationService

EliminationService consulta el registro ANTES de debounce, atacante, counters,
snapshot, Kill/Death/ranking, Coins, Bindable PlayerEliminated y recuperación.
Si ya existe Goal para ese tránsito, retorna sin emitir DefaultFall, BasicKill,
Frost/Void, notificación o un segundo respawn. Tampoco consume el debounce0.5s
por contactos protegidos. No se cambia la atribución ni se fabrica una eliminación
para luego intentar deshacerla.

Si no existe un resultado previo, una eliminación válida reserva Elimination antes
de callbacks de atribución/feedback/retiro. Las validaciones de conexión, sesión,
participante, sensor de la arena, Character, contacto actual y debounce se conservan.
Otro jugador no protegido mantiene su eliminación según las reglas de fase existentes.
No se desactiva KillPart globalmente.

## 6. Eventos fuera de orden

Política determinista: gana la PRIMERA confirmación autoritativa válida, no una supuesta
prioridad física de los nombres ni el orden histórico de un Touched encolado.

- Gol primero: Score aumenta una vez; KillPart/VoidBoundary/sondeo posteriores del
  mismo tránsito se descartan sin consecuencias competitivas.
- Eliminación primero: la reserva bloquea el gol posterior de esa vida. No se revierte
  Kill/pago/feedback ni se concede un gol retroactivo.
- Contacto antiguo tras teleport: la detección actual del sensor rechaza partes
  alejadas; se comprueba además que pertenezcan al Character vigente.
- Character/generación nueva y nueva salida válida: no heredan inmunidad competitiva.

Esta política NO promete recuperar un gol cuyo Touched aún no se validó cuando
KillPart confirmó primero una eliminación. Resolver una prioridad distinta exigiría
otra especificación; no se añadió una ventana arbitraria de espera física.

## 7. Character del anotador después del gol

No se destruye, mata ni reemplaza; no se añade LoadCharacter, otro respawn, invisibilidad
o anclaje nuevo. Puede continuar cayendo visualmente durante el feedback existente,
pero el tránsito confirmado no genera eliminación. Después lo reposiciona exclusivamente
SpawnMatchPlayers del reinicio ya validado.

Se evaluó reutilizar el retiro KillPart: BeginKillPartRespawn exige Playing SIN
PointInProgress y programa recuperación con temporizador de eliminación. Usarlo para
un gol mezclaría dos dueños del ciclo. Se conserva el flujo de punto, como pide la
prioridad de no alterar Zero-Death ni la celebración final.
Si un controller de PointFeedback cediera demasiado tiempo y el Character alcanzara
FallenPartsDestroyHeight antes del reset, eso requiere evidencia manual; no se crea
otro flujo físico preventivo ni se declara ese escenario probado.

## 8. Reinicio de punto

RoundService no se modifica: conserva PointResetDelay, SpawnMatchPlayers con resultado
completo, LockSessionPlayers, PointRestartCountdown y regreso a Playing/ResumeScoring.
No cambia el temporizador de respawn ni sus500ms configurados.

La ruta defensiva ScoreService:_schedulePointReset ahora sólo reabre scoring tras
SpawnMatchPlayers.Success y llama ResumeScoring, limpiando también PointScorer y su
protección. Antes sólo soltaba el lock local. En el flujo normal RoundService tiene
TriggerPointRestart; ese fallback no es un nuevo scheduler.
Si falta SpawnService o falla el batch en ese fallback excepcional, no reabre scoring
sin colocar jugadores; la recuperación de esa dependencia exige investigar su error.

## 9. Quinto punto y EndCinematic

No hay modificación de RoundService ni EndCinematic. Antes del quinto punto ya existe
la protección del anotador; DeclareSessionWinner/BeginSessionResults conserva su
barrera inmediata GameplayFrozen/Closing/Ending y UnbindMatch antes de efectos que cedan.
Se preservan celebración, feedback final visual, ranking capturado, Wins/Losses,
resultado y retorno individual al lobby. No se hace reset de punto tras WinningScore.

## 10. Death Feedback y economía

Caídas y Kills reales de jugadores no protegidos siguen las rutas originales:
DefaultFall sin atacante; cosmético equipado de la víctima para Kill acreditada;
misma notificación, +50 atacante y recuperación Zero-Death.

La llamada de premio de gol usa ahora el transactionId opcional ya existente:
Goal:<PointId>. Mantiene reason MatchPoint y Config.Match.PointReward (50).
No se modifica PlayerService, AddCoins, AwardConfirmedKill, compras ni otro método económico.
El debounce de scoring y la reserva impiden volver a ejecutar el punto; el ledger
económico existente también evita pagar dos veces su mismo PointId.
No hay +50 Kill por el contacto protegido. Recompensas, ranking y victoria se
verifican funcionalmente sólo con las pruebas del desarrollador.

Hashes iniciales/finales iguales de PlayerService, ShopService, SpawnService,
DeathEffectService, Config, Frost.rbxm, Void.rbxm y ShopHUD.rbxm:8/8.
No se tocó Shop Integration V2, mapas, HUDs, palmadas, colisiones de lobby, respawn,
persistencia/proveedores, Universe ID, modos o concurrencia.
Studio se observó IsStudio=true/IsRunning=false. InMemory/WritesToCloud=false
se conserva por configuración inspeccionada; no se inició un servidor para fabricar Output.

## 11–12. Build, diff y matriz

rojo build default.project.json --output <TEMP>/SlapDuels-ScoreKillPartV1.rbxlx: PASS.
git -c core.safecrlf=false diff --check: PASS.
Build verifica ensamblado, no tipado Luau ni corrección funcional.
La suite aislada NO se ejecutó: módulos/tablas/Character desechables, sin Init,
perfil real, sensores en Workspace ni escrituras cloud. No se inició Play/Run/Start Server.

| Caso | Verificación preparada / evidencia | Resultado funcional |
|---|---|---|
| A1 gol→KillPart sin Death | Fixture atraviesa ruta de supresión antes de counters | NOT RUN |
| A2 sin caída notificada | Sin Bindable de eliminación en rama protegida | NOT RUN |
| A3 sin Death Effect | No se crea snapshot ni se emite PlayerEliminated | NOT RUN |
| A4 sin Kill/pago extra | Fixture prohíbe llegar a atribución/recompensas | NOT RUN |
| A5 +50 gol | Fixture score/reward y clave de transacción | NOT RUN |
| A6 otro participante | Registro independiente por UserId | NOT RUN |
| A7 otra sesión | Fixture de otra SessionId, sin habilitar concurrencia | NOT RUN |
| A8 limpieza | ReleaseGoals/ResumeScoring y transferencia durante countdown | NOT RUN |
| A9 Character nuevo | Fixture reemplazo y generación diferente | NOT RUN |
| A10 doble Touched | Fixture repetición de _handleZoneScoring | NOT RUN |
| A11 quinto punto | Fixture ruta terminal una vez; cinemática real manual | NOT RUN |
| A12 celebración sin eliminación | Barreras de Ending sin cambios | NOT RUN |
| A13 caída real DefaultFall | Ruta no protegida conservada | NOT RUN |
| A14 Kill real cosmético | Resolución de víctima sin cambios | NOT RUN |
| A15 Zero-Death | Spawn/ArenaRespawn sin cambios | NOT RUN |
| A16 lobby sólido | Config/Spawn y geometría sin cambios | NOT RUN |
| A17 sin duplicaciones | Fixture5 puntos=250 y counters protegidos vacíos | NOT RUN |
| A18 build | Comando ejecutado | PASS |
| A19 diff check | Comando ejecutado | PASS |

Las inspecciones de código o Sources Edit no se presentan como PASS de jugabilidad.

## 13. Prueba manual exacta — sólo desarrollador

Usá un servidor nuevo de TU prueba para cargar las fuentes instaladas. Antes de entrar,
confirmá en Output: PersistenceEnvironment=Studio, PersistenceProvider=InMemory,
WritesToCloud=false. Detener si difiere; no habilitar cloud ni cambiar Universe ID.

1. Iniciá vos un1v1 con dos clientes reales; matchmaking, voto y salida normales.
2. Anotá Coins, marcador, Kills y Deaths de ambos; Player1 entra en la zona de su
   equipo (Red→RedWin / Blue→BlueWin). No fabricar el punto por comandos.
3. Tras confirmarse el gol, dejá que el Character continúe su tránsito hacia KillPart.
   No debe aparecer “Player1 se cayó”. Capturá el gol y la ventana hasta reposicionamiento.
4. Player1 recibe exactamente +50 por punto; ningún atacante recibe un +50 Kill
   causado por esa caída. Marcador sube una vez; Kills/Deaths no cambian por ella.
5. Sin DefaultFall/BasicKill/Frost/Void ni animación de recompensa Kill por ese contacto.
   PointFeedback del gol sí debe continuar. Revisá Output de servidor y ambos clientes.
6. Reset en spawns, countdown y movimiento normales. En la nueva fase jugable,
   provocá una caída real del mismo jugador: debe haber dejado de estar protegido.
7. Repetí hasta5 puntos. Verificá premio único por gol, aviso al4 y ausencia de
   notificaciones de caída del anotador en cada secuencia. Usá ambos equipos.
8. En el quinto, celebración final y EndCinematic normales; sin respawn adicional,
   falso feed o Death del anotador. Win/Loss y ranking conservan sus reglas.
9. En otra partida, provocá una caída sin gol y sin atacante reciente (esperá la
   ventana configurada de LastHit). Debe usar DefaultFall y0 Coins por Kill.
10. Provocá una Kill real por palmada en Playing: +1 Kill, Death competitiva conforme
    a reglas existentes, +50 atacante una vez y respawn configurable sin salto residual.
11. Repetí con víctima equipada BasicKill/Frost/Void usando la tienda validada;
    el efecto debe ser de la víctima. Otro participante no protegido que caiga
    durante una secuencia se procesa según las reglas de fase, sin inmunidad global.
12. Completá retorno al lobby: suelo sólido, locomoción y equipamiento normales;
    sin caída/respawn en bucle. Repetí partida para detectar protecciones residuales.

Adicionales cuando sea posible: abandonar tras gol, reemplazo de Character y cancelación.
La simultaneidad precisa y otra sesión se cubren con fixtures aislados preparados;
NO habilitar concurrencia/modalidades para probarlos.
Si KillPart se confirma ANTES del gol, esperar eliminación válida y ningún punto
retroactivo, conforme a la política definida.

Registrar por caso PASS/FAIL/BLOCKED/NOT RUN, secuencia de acciones, marcador,
Coins/Kills/Deaths antes/después, clip y Output con SessionId/PointId cuando esté disponible.
Config.Respawn.Debug=false no se cambió. Si ya está habilitado por tu entorno, el nuevo
trace [ScoreKillPart] ContactSuppressed informa SessionId, UserId, Kind, EventId,
generación y fuente; no se requiere habilitarlo para la prueba ni modificar configuración.

## 14. Riesgos y cierre

El bypass exacto de la protección booleana anterior no se reprodujo bajo las
restricciones; el arreglo coordina decisiones y vidas, pero la aceptación depende
de observar el caso reportado. La política elimina el doble resultado, no garantiza
prioridad de gol si la eliminación se confirmó primero.

No se midieron caída visual prolongada, rendimiento ni comportamiento del quinto
punto en ejecución. No se ejecutaron suites ni analizador Luau. Se preservó la
física existente y los contratos de recompensa; no se promete persistencia durable
entre servidores con InMemory.

No Play/Run/Start Server, control de jugadores, partidas, commits, push, publicación,
guardado/cierre del lugar ni escrituras cloud. Respaldo integral previo conservado.
Trabajo detenido después de esta corrección, a la espera de validación humana.
