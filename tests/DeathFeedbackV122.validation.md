# Death Feedback V1.2.2 — correcciones implementadas, aceptación humana pendiente

Fecha: 2026-10-16. Agente: sólo inspección/autoría Edit, build y diff. No Play,
Run, Start Server, personajes ni pruebas funcionales. Los resultados de dos series
de cinco Kills descritos por el desarrollador son evidencia humana de V1.2.1,
NO resultados de esta versión. Ningún escenario de V1.2.2 se declara PASS funcional.

## 1. Colisiones del lobby: evidencia y corrección

MCP Edit mostró un único grupo registrado, Default, con Default↔Default=false.
No se encontró código que registrara grupos o cambiara su matriz. Los personajes
y el suelo usaban Default. Esto constituye una causa estática suficiente para
atravesar el suelo aunque las partes tengan CanCollide=true. No se puede probar
con Edit en qué instante la matriz tomó ese valor durante las pruebas anteriores.

El suelo físico debajo de Lobby.SpawnLocation incluye:

- Workspace.props-v1.Model.Plat1_Base, Plat1_Neon y Plat1_Top:
  Anchored=true, CanCollide=true, CollisionGroup=Default.
- Workspace.PLAZA.plaza-circular-v1.Model1.MeshPart:
  Anchored=true, CanCollide=true, CollisionGroup=Default.
- Workspace.Lobby.SpawnLocation: Anchored=true, CanCollide=false, Default,
  centro (-55.22151,16.57931,202.22760), tamaño (12,1,12). Es un marcador sobre
  la plataforma, no el suelo; no se le habilitó colisión ni se movió.

Se creó SlapDuelsCharacters, con Characters↔Default=true y Characters↔Characters=false.
Default↔Default conserva false, sin cambiar otros pares ni la geometría. El grupo
está instalado en Edit y SpawnService lo garantiza también al inicializar un
servidor construido con Rojo. CharacterAdded asigna todas las partes del jugador
al grupo, incluyendo accesorios y partes añadidas; los colliders R6 lo heredan.
Así se conserva la exclusión entre jugadores sin excluirlos del mundo.

CharacterPhysics captura CanCollide/CanTouch/CanQuery por parte del Character normal,
antes de mutaciones competitivas. Restore utiliza esa misma identidad de Character:
no habilita colisión indiscriminadamente. El root conserva su contrato distinto
del torso/cabeza; el rig R6 de referencia en Edit tiene root=false, torso/head=true
y extremidades=false. No se utilizó ese rig para imponer valores a todos los avatares.

## 2. Intermitencia: defecto de rutas demostrado, correlación runtime pendiente

EliminationService tenía tres entradas: KillPart.Touched, VoidBoundary.Touched y
VoidBoundaryPolling. Sólo la primera capturaba ImpactCFrame y usaba la retirada
temporizada. DeathEffectService trataba las otras Kills como RewardOnly: enviaba
el recibo de Coins al atacante, sin efecto audiovisual de impacto. Esto explica
estáticamente una Kill acreditada con +50 y sin BasicKill.

Falta Output correlacionado para demostrar que las Kills 3/4 concretas tomaron la
ruta void. No se afirma una causalidad única de todos los efectos omitidos.

Ahora toda eliminación de sensor captura un snapshot antes de retirar al Character:
SessionId, EliminationId, IDs/nombres, efecto equipado resuelto, tipo, generación y
CFrame de impacto. KillPart conserva su impacto sobre el sensor. Void usa su propio
boundary validado y la posición de contacto/root al confirmar, sin inventar un
contacto con KillPart. El snapshot se congela y viaja con la decisión final y el
importe realmente acreditado. DeathEffectService no necesita el Character anterior
para resolver el modelo. Las rutas actuales con snapshot reproducen BasicKill o
DefaultFall; RewardOnly queda sólo para compatibilidad de recibos antiguos sin impacto.

El cliente ya no destruye efectos independientes por CharacterAdded ni porque se
desconecte un tercero ajeno. Sigue limpiando por cambio/cierre de sesión y conservando
el filtro de identidad/versión/edad. No se modificaron modelos, HUD, sonidos o diseño.

## 3–4. Salto y diferencias entre vidas

La ruta void anterior llamaba ResetCharacterInArena sin Pending: GettingUp,
clearance normal y recuperación distinta a KillPart. Por tanto podía saltarse las
protecciones físicas de V1.2.1. Ahora las tres entradas durante Playing usan la
misma retirada inmediata, generación, quiet reset y KillPartDelayMs=500.

Se mantiene la corrección R6 de golpes repetidos de V1.2.1. Al restaurar se repone
el contrato físico normal, evitando convertir un snapshot tomado en Physics en
la configuración permanente. El guard cliente reconoce la transición a Lobby y
la generación vigente; recupera estado local una vez, sin quitar golpes nuevos
legítimos ni bloquear salto permanente. No se agregó fuerza compensatoria ni delay.

No existe en el código una regla especial que falle en la tercera Kill. El orden
observado puede depender del sensor ganador, polling y simulación/replicación.
La causa física exacta de cada impulso observado sigue pendiente de trazas runtime.

## 5. Archivos de esta tarea

1. src/server/Services/Respawn/CharacterPhysics.luau (nuevo): grupo, captura y
   restauración por Character, limpieza de listener y diagnóstico físico.
2. src/server/Services/SpawnService.luau: integración física, cancelación al retorno,
   teleport del root exacto, validación tras yields y distinción explícita de lobby.
3. src/server/Services/Respawn/ArenaRespawn.luau: restauración del contrato físico,
   fase de retirada/retorno y RoundState diagnóstico.
4. src/server/Services/RagdollService.luau: collider hereda grupo de su parte.
5. src/server/Services/EliminationService.luau: snapshot previo y unificación de
   retiro para KillPart/void/polling, sin cambiar premio ni atribución.
6. src/shared/Types.luau: FeedbackSnapshot opcional en EliminationRecord.
7. src/server/Services/DeathEffectService.luau: consume snapshot de todas las rutas,
   recibos privados y trazas de envío/rechazo por eliminación.
8. src/client/Controllers/DeathFeedbackController.luau: trazas de recepción/rechazo,
   reproducción y deduplicación; limpieza ligada a sesión en lugar de Character.
9. src/character/ArenaRespawnGuard.client.luau: recuperación local por generación
   y fase Lobby, conservando protección de entradas antiguas y golpes nuevos.

Se agregan tests/DeathFeedbackV122.spec.luau (PREPARADO, NO EJECUTADO), este informe
y DeathFeedbackV122.edit-evidence.json. Los hashes de fuentes antes/después acotan
el cambio a esos nueve archivos. Config, economía, persistencia, RoundService,
MatchInstanceService, MatchController, SlapService, CombatService y EndCinematic no
se modificaron. El diff de Git contra HEAD incluye todo el trabajo previo del usuario.

## 6–10. Ciclo, cancelación, deduplicación y retorno individual

Se conserva Zero-Death y el mismo Character vivo. No Health=0 ni LoadCharacter en
combate. Se mantiene la restauración nativa de lobby ya existente si no hay Character
recuperable; ahora puede usarse explícitamente al volver, aunque la sesión siga Ending.

Al retornar un jugador: cancelar/consumir Pending, invalidar ArenaPhysicsGeneration,
establecer fase Lobby, restaurar contrato y locomoción, teletransportar una vez y
limpiar su identidad de match. El teleport vuelve a validar Player/Character,
generación y MatchId después de sus esperas. No reposiciona un Character reemplazado
accidentalmente. El retorno ya no considera éxito simplemente porque falte Character.

Antes el teleport podía deshabilitar Dead nuevamente por ver la sesión todavía en
Ending, después de haberlo habilitado para lobby. Ahora distingue el destino lobby
y restaura el estado estándar al terminar. No se mata al jugador para arreglarlo.

EndCinematic continúa llamando ReturnPlayersToLobby({player}) desde
_returnResultsPlayer y liberando únicamente su root protegido. No se alteraron
cámaras FloatingFollow, escena, payload cinematográfico ni retorno del otro cliente.
Los timers competitivos se cancelan antes de esa transferencia; los checks de
generación y Character de V1.2.1 permanecen.

EliminationId sigue incluyendo sesión, UserId y contador; no se deduplica por UserId
de manera permanente. La recompensa usa el EliminationId existente y su transacción
autoritativa. El feedback mantiene su propio visto por sesión/EliminationId. No se
creó una segunda eliminación para conseguir efectos. El snapshot precede la retirada
por seguridad de Touched; estadísticas/premio y evento final conservan su orden.

## 11. Diagnóstico optativo

Config.Respawn.Debug sigue false. Para diagnosticar, activalo en Edit ANTES de iniciar
tu servidor/los clientes y reiniciá tu prueba. No cambies Sandboxed ni permisos.
Los scripts de Character siguen leyendo el atributo del servidor; no requieren Config.

Copiar Output de servidor y ambos clientes, agrupando por SessionId/EliminationId:

- EliminationConfirmed: usuario, generación, RoundState, motivo, atacante y efecto.
- RetiredAfterRagdoll / RetiredWithoutRagdoll, ServerRestored, ArenaPositioned:
  estado, Jump, velocidades, tipo, generación y estado de sesión.
- FeedbackSent: destinatario, efecto, RewardOnly e importe confirmado.
- FeedbackReceived / FeedbackRejectedContract / FeedbackDuplicate / EffectStarted
  o EffectNotStarted: recepción y filtros del cliente, versión y cutoff.
- StaleStateEvent / StaleDeferredLaunch / StaleRagdollRecovery y Cancelled:
  operaciones antiguas rechazadas/canceladas; una tarea cancelada puede no ejecutarse
  y no imprimir una línea stale.
- LobbyReturned: torso/root, CanCollide, grupos, par con grupo de spawn, velocidad,
  estado y fase de sesión. Se toma antes de liberar el root protegido de resultados;
  Anchored=true en ese punto de Ending no prueba un anclaje permanente.

No hay logs por frame. EffectStarted indica creación del scope, no prueba visual
de partículas visibles. Velocidad cero instantánea tampoco prueba estabilidad después.
Al terminar, volver a Debug=false. Delay permanece 500.

## 12–13. Verificaciones realizadas

- Studio MCP: Edit, IsStudio=true, IsRunning=false.
- Matriz Edit: SlapDuelsCharacters↔Default=true; Characters↔Characters=false;
  Default↔Default=false conservado.
- Comparación de propiedades de BaseParts de Workspace y EndGames-Scenario antes
  y después de autoría de grupos: idénticas en CFrame, tamaño, CanCollide, Anchored y
  CollisionGroup. No se modificó geometría, KillPart, piso, escenario ni cámaras.
- Sources Edit: marcadores V1.2.2 presentes. Hay dos ModuleScripts homónimos
  DeathEffectService y dos DeathFeedbackController, con Sources idénticos actualizados.
  Se preservaron; bootstrap indexa por nombre e inicia una entrada por nombre,
  no ambos. No se usaron como explicación del fallo sin evidencia de ejecución doble.
- Config no cambió: demora500, Debugfalse, +50 Kill, +50 punto, modalidades y
  concurrencia existentes. Persistencia tampoco cambió. Rama Studio sigue
  seleccionando InMemory/WritesToCloud=false por inspección; no se ejecutó Bootstrap.
- rojo build default.project.json: PASS, artefacto temporal fuera del repo.
- git -c core.safecrlf=false diff --check: PASS.
- Suite aislada nueva y suites previas: PREPARADAS/NO EJECUTADAS. Build no es un
  analizador Luau ni una prueba de física. Ninguna partida ejecutada por el agente.

## 14. Guía manual exacta y matriz A–M

Reiniciá TU prueba local con dos clientes para cargar todos los cambios. Antes del
match confirmá Output de servidor: PersistenceEnvironment=Studio,
PersistenceProvider=InMemory, WritesToCloud=false. Si difiere, detené la prueba.
Verificá desde el servidor que torso/root de ambos jugadores usan
SlapDuelsCharacters y que el suelo conserva Default. No cambies propiedades en Play
para ocultar un fallo. Entrá mediante Red/Blue, votá y esperá Go.

| Caso | Acciones y evidencia a registrar | Esperado | Estado agente |
|---|---|---|---|
| A | Cinco Kills por palmada del mismo atacante, sin anotar goles. Filmá víctima y Output; numerá cada EliminationId. | Cinco efectos, cinco retornos estables. | NOT RUN |
| B | En una sesión nueva, diez Kills consecutivas; alterná víctima/atacante y probá un doble golpe válido dentro del cooldown permitido. | Sin degradación ni recursos R6 antiguos. Si doble golpe no es reproducible, anotarlo NOT RUN. | NOT RUN |
| C | Usá víctimas sin otro DeathEffect equipado o con BasicKill legítimamente equipado. Observá cada Kill de A/B. | BasicKill en todas; con otro cosmético, se respeta el equipado. | NOT RUN |
| D | Sin recibir golpes durante más de LastHitLifetime (10 s), caminá fuera hacia el sensor. | DefaultFall; ninguna Kill ni Coins por Kill. | NOT RUN |
| E | Anotá Coins antes y después de cada Kill. Sin goles en medio: cinco Kills=+250; diez Kills=+500 para quien las acredita todas. | +50 exactamente una vez por Kill, monedas hacia CoinTarget. Víctima/lobby no reciben premio ajeno. | NOT RUN |
| F | Víctima sin pulsar salto: mirá primer retorno y los 2 s posteriores en cada Kill. | Sin salto, giro o impulso automático, incluso después de la tercera y décima. | NOT RUN |
| G | Tras regresar, caminá y pulsá salto una vez. Repetí con salto retenido antes de caer; al volver, soltá y pulsá nuevamente. | Entrada antigua no salta automáticamente; nueva pulsación funciona. | NOT RUN |
| H CRÍTICO | Terminá normalmente llegando a cinco puntos; dejá completar EndCinematic y regresá ambos. | +50 por gol conservado; cada uno aparece en lobby, sin muerte/ciclo. | NOT RUN |
| I CRÍTICO | Cada cliente camina por la plataforma del spawn y suelo circundante y salta varias veces. | No atraviesa suelo; personajes no se empujan entre sí. | NOT RUN |
| J CRÍTICO | Esperá al menos 10 s en lobby sin entrar a otra partida; luego caminá otra vez. | Ningún timer lo devuelve a arena ni provoca caída/respawn viejo. | NOT RUN |
| K | Después de H–J entrá a una segunda partida, hacé al menos dos Kills y un gol y completá su retorno. | Matchmaking, efectos, premio, física y limpieza repetibles. | NOT RUN |
| L | En EndCinematic, un cliente vuelve con su botón mientras el otro permanece mirando. Después vuelve el segundo. | El primero puede recorrer lobby; el segundo conserva FloatingFollow/escena hasta su propio retorno. | NOT RUN |
| M | Si falla alguno, activá Debug en Edit, reiniciá TU prueba y repetí el mismo escenario hasta obtener fallo. | Guardar trazas servidor/ambos clientes desde golpe hasta retorno y 10 s de lobby. | NOT RUN |

También registrar Workspace.ActiveMatches y recursos de sesión después de que ambos
hayan salido. Una sesión puede conservar escena mientras quede un espectador: no es
una fuga por sí sola. No fabricar Kills, Health=0 ni premios con Command Bar.

Por cada eliminación anotá número, EliminationId, Reason, Coins antes/después, efecto,
tiempo aproximado, estabilidad, estado y errores. Si falta FeedbackSent, mirar rechazo
servidor; si llegó pero no empezó efecto, mirar filtro cliente/asset; si ambos dicen
iniciado pero no se ve, copiar también warnings de partículas/streaming/cámara.

## 15. Riesgos y límites

No se ha probado el comportamiento con clientes reales en esta versión. Quedan
pendientes R6/R15 reales, teclas/touch/gamepad, latencia, diez Kills y retorno individual.
La corrección de grupos es concreta; no demuestra por sí sola que no haya otro
callback físico defectuoso. La correlación de las Kills 3/4 con VoidBoundary y el
origen exacto de cada salto requieren logs del desarrollador. Los snapshots físicos
se capturan al crear el Character normal, no son una reparación de cuerpos ya
corruptos en un servidor viejo: reiniciar la prueba es obligatorio.

No se tocó fuerza, economía, HUD, efectos nuevos, tienda, EndCinematic, mapas,
concurrencia, publicación, commits, push ni persistencia cloud. Detenerse aquí hasta
validación humana, sin declarar resueltos los tres síntomas sólo por estática/logs.
