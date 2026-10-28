# Slap Duels 2.0 — Ciclo de vida del personaje

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Contrato vigente: Zero-Death / Persistent Character

Desde StartCountdown hasta ReturningToLobby, se conserva exactamente la misma instancia de Character. Las caídas se resuelven por sensores no letales y reposicionamiento; no por muerte y respawn.

- Players.CharacterAutoLoads permanece en true a nivel global para el lobby; no se alterna durante partidas.
- LoadCharacter() está prohibido durante toda la MatchSession, incluido Ending. En lobby solo se permite recuperar un personaje realmente destruido.
- Al entrar en arena se deshabilita HumanoidStateType.Dead; se restaura después de trasladar al personaje de forma segura al lobby. No se usa salud infinita como sustituto.
- Humanoid.Died es diagnóstico pasivo: no otorga kills, no modifica score y no dispara respawns.
- No se usan StartMatchRespawnTracking ni listeners de CharacterAdded para rescatar personajes del lobby durante el match.

## Identidad y aislamiento

RoundService asigna los atributos MatchId y MatchTeam (Red o Blue) al llegar a MatchReady. SpawnService resuelve el TeamSpawn dentro de MatchInstanceService:GetInstance(matchId). Las cancelaciones, salidas y el retorno al lobby limpian ambos atributos. Ningún evento de otra arena puede afectar la sesión.

## Primitivas de restauración

### RagdollService:ResetRagdollImmediate(character): boolean

Es síncrono e idempotente. Cancela timers activos, reactiva las articulaciones correspondientes al rig (AnimationConstraint en R15 o Motor6D/RootJoint en R6), elimina soldaduras y colisionadores temporales, restablece PlatformStand/AutoRotate/GettingUp y anula velocidades lineales y angulares de todas las partes. Notifica al cliente para apagar RagdollStatesHandler. No modifica Health ni reemplaza el Character.

### SpawnService:ResetCharacterInArena(player): boolean

Resuelve RedSpawn/BlueSpawn por MatchId y MatchTeam, ejecuta el reset inmediato de ragdoll y mueve el modelo existente con PivotTo. Usa elevación de seguridad según HipHeight y grosor del spawn; limpia velocidades antes y después. No destruye ni recarga el modelo. Los bloqueos de locomoción del countdown deben mantenerse o reaplicarse al reposicionar.

## Sensores y recuperación de caídas

KillPart, VoidBoundaryPart.Touched y VoidBoundaryPolling convergen en EliminationService. Las reglas de atribución y deduplicación están en [Eliminación](ELIMINATION.md).

- Cada arena contiene VoidBoundaryPart en Workspace.ActiveMatches.Match_<Id>.
- Config.Arena.VoidBoundarySize: Vector3.new(500, 4, 500); VoidBoundaryOffset: (0, -50, 0) respecto de Origin.
- Propiedades: Anchored=true, CanCollide=false, CanTouch=true, CanQuery=false, Transparency=1.
- El polling de sesiones activas usa Config.Arena.VoidBoundaryPollInterval=0.2 s. Detecta HRP.Position.Y <= boundary.Position.Y + boundary.Size.Y/2 para cubrir tunneling.
- El sensor pertenece al contenedor de su sesión; se destruye junto con la arena.

## Protección del anotador y reinicio

ScoreService y RoundService mantienen por sesión PointInProgress, PointScorer, PointScorerTeam, PointScoreTimestamp y PointNumber. Mientras se presenta el punto, una caída del anotador no concede kill ni se procesa como eliminación rival. El nombre histórico PointScoreDeath describe esa protección; no implica muerte física en el diseño vigente.

En un punto intermedio, los sensores no reposicionan prematuramente al anotador durante la cinemática. RoundService dirige el retorno de ambos equipos, el countdown de 3 segundos y la reanudación. ResumeScoring limpia el estado temporal de punto al volver a Playing. La protección no autoriza dejar al personaje caer hasta FallenPartsDestroyHeight: la secuencia debe asegurar su recuperación a tiempo.

| Estado | Comportamiento físico | Kills |
|---|---|---|
| StartCountdown | Recuperar caídas y mantener bloqueo de movimiento | 0 |
| Playing | Resolver caída o eliminación; proteger al anotador durante PointInProgress | Solo atacante válido según EliminationService |
| PointRestartCountdown | Reposicionar y mantener locomoción bloqueada hasta GO | 0 |
| Ending | Estabilizar inmediatamente y mantener sensores de contención | 0 |
| ReturningToLobby | Trasladar el mismo Character al lobby y limpiar la sesión | 0 |

## Punto final y retorno seguro

1. El punto final lleva directamente a Ending, sin countdown de reinicio. RoundService ejecuta ResetCharacterInArena para todos los contendientes: neutraliza el blast, el ragdoll y las velocidades, y estabiliza en TeamSpawns. Esto es reposicionamiento del mismo Character, no respawn.
2. KillPart, VoidBoundary y polling permanecen activos durante Ending (4 segundos de referencia). Una caída recupera al jugador sin conceder kills, cambiar el resultado ni reiniciar puntos. Esta recuperación tiene prioridad sobre la protección cinematográfica del anotador.
3. En ReturningToLobby, ReturnPlayersToLobby traslada los avatares existentes, cancela timers y restaura locomoción y velocidades.
4. Una vez seguros en el lobby, restaura Dead=true y limpia MatchId/MatchTeam. UnbindMatch y CombatService:ClearMatch se ejecutan en esta fase, antes de destruir la arena.
5. UnbindMatch desconecta sensores, retira la sesión, limpia debounces y detiene el polling cuando ya no quedan sesiones activas. Cancelación y desconexión también deben liberar sus recursos.

Referencias: [Flujo](MATCH_FLOW.md), [Scoring](SCORING.md), [Eliminación](ELIMINATION.md).
