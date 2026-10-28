# Movement Speed V1.0

Implementado y sincronizado en Studio **Edit**. Validación de jugabilidad **NOT RUN**, reservada al desarrollador. No se inició Play, Run, Team Test ni Start Server; no se controlaron personajes, publicaron cambios, hicieron commits/push ni escrituras cloud.

## Auditoría y causa

- Studio conectado: `SlapDuels 2.0 [EVENTOS DE HALLOWEEN]`, PlaceId `107328891970677`, Universe `10769217377`.
- `StarterPlayer.CharacterWalkSpeed = 16`, pero `StarterPlayer.StarterCharacter.Humanoid.WalkSpeed = 32`: el personaje personalizado explica la velocidad inicial observada. Ambas propiedades físicas permanecen intactas.
- SpawnService guardaba la velocidad encontrada en `BaseWalkSpeed` y la restauraba después de los bloqueos; no resolvía una base distinta según sesión. Podía guardar y restaurar el 32 del lobby dentro de la partida.
- DevilSpeed capturaba la velocidad al activar, aceleraba y restauraba ese valor capturado. Era necesario integrarlo con la base vigente al limpiar.
- RoundService, MatchmakingService y las reservas separan preparación cancelable, selección de mapa y transferencia física. `MatchId` existe antes de terminar el countdown: por eso **tener MatchId por sí solo no significa velocidad de partida**.
- ArenaRespawn conserva el Character y controla `PlatformStand`/`ArenaRespawnPending`; no asigna WalkSpeed. CharacterPhysics y CompetitiveTransit tampoco lo asignan.
- RagdollService usa PlatformStand y cancela habilidades antes del derribo. EndCinematic usa los bloqueos de SpawnService y ancla la raíz. Se conserva esa propiedad del control.

### Escritores de WalkSpeed

| Antes | Función | Después |
|---|---|---|
| SpawnService | Cero durante bloqueo; restauración del valor guardado | Conserva el cero explícito; delega velocidad efectiva en MovementSpeed |
| DevilSpeedAbility | Aceleración y restauración directa | Aceleración idéntica; modificador con dueño y limpieza central |
| TrainingService | Cero al maniquí NPC | Intacto, fuera del movimiento de jugadores |
| StarterCharacter.Humanoid | Propiedad inicial 32 | Intacta |

Las referencias de AbilityService, AbilityController y SlapController leen velocidad/bloqueos para validar acciones. Las menciones de RoundService son comentarios del bloqueo. Los Animate de NPC encontrados en Workspace no incorporan autoridad sobre el Humanoid del jugador. No se agregó ningún Remote ni anticheat.

## Arquitectura

Se amplió **SpawnService**, dueño existente del movimiento y de los callbacks de personajes. No hay otro servicio Start, bucle de velocidad ni escritura adicional cada frame.

`Services.Respawn.MovementSpeed` compone:

1. Base autoritativa en `Humanoid.BaseWalkSpeed`, obtenida de la sesión actual y su identidad vigente.
2. Modificador temporal privado del servidor, asociado al Humanoid y al registro propietario de la habilidad.
3. Velocidad efectiva, aplicada solo si no existe bloqueo, PlatformStand, muerte o retiro de arena.

`Config.Character.LobbyWalkSpeed = 32`, `MatchWalkSpeed = 16`. `DefaultWalkSpeed` permanece como alias del valor de partida para compatibilidad. No se modificó ninguna otra configuración.

| Estado | Base | Efectiva |
|---|---:|---|
| Lobby, Waiting, MatchReady, MatchCountdown | 32 | 32 si no hay bloqueo |
| Cancelación de preparación y limpieza de identidad | 32 | 32 si no hay bloqueo |
| MapSelection / MapLoading | 16 | 16 si no hay bloqueo |
| StartCountdown / PointRestartCountdown | 16 | 0 mientras SpawnService mantiene el bloqueo |
| Playing | 16 | Base más modificador válido |
| Ending / ReturningToLobby antes del retorno individual | 16 | La cinemática conserva su bloqueo |
| Retorno individual y limpieza de MatchId | 32 | 32 después de liberarse el control |

El criterio es común para 1v1, 2v2, 3v3 y 4v4; no usa posición ni cantidad de jugadores. MatchmakingService no fue modificado. RoundService notifica a SpawnService después de registrar el nuevo estado.

### Personajes y respawns

Se reutilizan las conexiones existentes de CharacterAdded/Removing y PlayerAdded/Removing. Se espera Humanoid hasta 10 s y se vuelve a consultar la sesión **después** de la espera; se comprueba conexión, Character actual y Parent. Un callback de otra vida no escribe sobre el nuevo Character. Si Humanoid no llega dentro del límite, se abandona ese callback; requiere revisar Output y el rig si ocurre en una prueba manual.

Cada Character tiene solo dos listeners propios: cambios de PlatformStand y ArenaRespawnPending. Se desconectan al sustituirlo o salir. Start repetido no duplica suscripciones. Los reinicios de arena vuelven a resolver la velocidad al completar el reposicionamiento.

Los Characters nuevos durante los countdowns de arena o Ending conservan el bloqueo mediante SpawnService. Las velocidades base pueden actualizarse mientras la efectiva sigue en cero.

### Bloqueos y modificadores

DevilSpeed conserva exactamente: multiplicador **2,4**, máximo **48**, aceleración **100/s**, duración **5 s**, cooldown **14 s**. Con base competitiva 16, su objetivo sigue siendo **38,4**. Se reutiliza su Step existente; no hay otro Heartbeat.

La limpieza retira solo el modificador de su propio registro; un callback antiguo no elimina el de otra activación. Restaura la base del estado actual y conserva un cero ajeno. Las cancelaciones existentes de AbilityService por vida, sesión, ronda y ragdoll siguen intactas.

`MovementSpeedUnlockPending` registra una liberación explícita solicitada por SpawnService que aún está impedida por ragdoll/retiro. Se completa al liberarse esos estados, y un nuevo bloqueo la invalida. Una actualización ordinaria de base nunca libera un cero de dueño desconocido.

## Cambios

Producción:

- `src/shared/Config.luau`: bases y alias de compatibilidad.
- `src/server/Services/Respawn/MovementSpeed.luau`: nuevo helper de composición.
- `src/server/Services/SpawnService.luau`: ciclo de personajes, integración de bloqueos, arena y lobby.
- `src/server/Services/RoundService.luau`: aviso de transición de estado.
- `src/server/Abilities/DevilSpeedAbility.luau`: modificador y limpieza central.
- `studio-safe.project.json`: mapeo explícito del helper. El proyecto normal ya incluye su carpeta.

Pruebas: nueva suite/runner/validador MovementSpeedV10; fixture y runner de MatchmakingXVXV12 para resolver el nuevo módulo; fixture/runner de habilidades para la nueva dependencia de DevilSpeed. Evidencias y builds bajo `tests/MovementSpeedV10.*`.

Copias previas de los cuatro módulos modificados y el proyecto SAFE: `tests/assets/backups/MovementSpeedV10/`. No reemplazan ni alteran el respaldo integral anterior.

## Resultados

| Verificación | Resultado y alcance |
|---|---|
| Movimiento, bloqueos, modificadores, callbacks, restauración de arena y autoridad económica | **PASS: 54 aserciones**, módulos reales sobre mocks desechables, intérprete Luau local |
| MatchmakingXVXV12: admisión XvX, slots, presencia, cancelación y cierre | **PASS: 49 aserciones aisladas** |
| Compilación | **PASS: 213 scripts src** |
| Rojo default | **PASS** `MovementSpeedV10.default.rbxlx` |
| Rojo SAFE | **PASS** `MovementSpeedV10.safe.rbxlx` |
| git diff --check | **PASS** |
| Fuentes nativas y borradores | **PASS: cinco módulos**, SHA-256 igual al repositorio |
| Persistencia observada en Edit | **Studio / InMemory / WritesToCloud=false** |
| Integridad de persistencia y sistemas protegidos | **PASS: 13 fuentes**, iguales al manifiesto CloudPersistenceV1; Config solo cambia Character |
| Jugabilidad, física y múltiples clientes reales | **NOT RUN**, corresponde al desarrollador |

Se intentó adicionalmente la suite antigua `EconomyBalanceV1.spec.luau`: **FAIL del harness**, porque su fixture actual no define `ReplicatedStorage.Shared.Progression.Model`, requerido por PlayerService desde una fase previa. No se declara aprobada esa suite ni se cambió PlayerService para adaptarlo. Log: `MovementSpeedV10.economy.txt`. La nueva suite sí ejecuta AddCoins real, comprueba idempotencia y compara todos los parámetros Economy y la recompensa de gol con la copia anterior. La integridad de PlayerService también coincide con el manifiesto previo.

### Cobertura de los 23 puntos solicitados

| Puntos | Evidencia aislada |
|---|---|
| 1–4: lobby, espera, countdown y cancelación | Base/efectiva 32 y liberación de identidad |
| 5–9: sesión y cuatro tamaños | Base 16; transición real SetSessionState invoca la integración |
| 10–11: respawn y reinicio | CharacterAdded en sesión; Restore real de ArenaRespawn; estado PointRestart y bloqueo |
| 12–14: retorno y CharacterAdded | Base actual de lobby/partida, incluso si termina la sesión durante la espera |
| 15–16: DevilSpeed y expiración | Aceleración, objetivo, máximo, balance, limpieza con base nueva y dueño distinto |
| 17–18: ragdoll/cinemática | Conservación de cero y PlatformStand; unlock pendiente; no se simuló física ni cámara |
| 19–20: conexiones y callbacks obsoletos | Tracking repetido, Start repetido, desconexión y espera de Character reemplazado |
| 21: matchmaking | Suite de regresión de 49 aserciones |
| 22: respawn | Restore real sobre mocks y conservación del bloqueo; teletransporte físico no ejecutado |
| 23: economía | Parámetros anteriores intactos, AddCoins real e idempotencia; suite legacy no aprobada |

## Sincronización Edit

Se verificaron las fuentes y los borradores iniciales frente a las copias locales antes de escribir, y de nuevo dentro de UpdateSourceAsync. Se creó solamente el ModuleScript `ServerScriptService.Services.Respawn.MovementSpeed` y se actualizaron los otros cuatro módulos. Los hashes de Source y EditorSource finales se registran en `MovementSpeedV10.studio-edit.json` y `MovementSpeedV10.source-hashes.json`.

No se sincronizó el árbol completo de Rojo, no se aplicaron assets/UI, no se guardó ni cerró el lugar. StarterPlayer, StarterCharacter, mapas, spawns, cámaras y GUI físicos no fueron modificados. El escenario y los borradores del desarrollador se conservaron.

## Validación manual — solo el desarrollador

1. Iniciar la prueba cuando quieras. Confirmar en Output **Studio / InMemory / WritesToCloud=false** antes de continuar.
2. En lobby comprobar desplazamiento a 32. Entrar en pads y esperar el countdown: debe seguir a 32. Salir de un pad antes de terminar: debe cancelarse sin teleport ni respawn y conservar 32.
3. Completar la preparación de 1v1: selección de mapa y arena con base 16; durante el countdown inicial efectiva 0; al comenzar Playing efectiva 16.
4. Probar DevilSpeed: acelera hasta 38,4 durante 5 s y vuelve a 16; cooldown 14 s. Recibir una palmada mientras está activo: conserva el ragdoll y limpia el bonus, sin levantarse antes de tiempo.
5. Probar caída/KillPart, gol, reposicionamiento y nueva ronda: base 16; countdown en cero. Verificar golpes, puntuación, recompensas y controles habituales.
6. Finalizar: no debe moverse durante EndCinematic. Volver al lobby: efectiva 32 y sin bonus de la habilidad. Repetir otra partida.
7. Repetir con 2v2, 3v3 y 4v4 cuando dispongas de los clientes y zonas necesarios. Todos los integrantes deben usar base 16 y volver a 32 individualmente al salir de resultados.
8. Comprobar respawn en lobby y durante una sesión, y salida/desconexión en preparación/partida. Ningún Character nuevo debe heredar un bonus anterior o quedar liberado durante un countdown.

Para consultar sin modificar nada, ejecutar en **Command Bar del servidor de la prueba**:

```lua
for _, player in game:GetService("Players"):GetPlayers() do
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if humanoid then
  print(player.Name, "Match", player:GetAttribute("MatchId"),
   "Base", humanoid:GetAttribute("BaseWalkSpeed"), "Effective", humanoid.WalkSpeed,
   "Locked", humanoid:GetAttribute("MovementLocked"), "PlatformStand", humanoid.PlatformStand)
 end
end
```

Si falla, informar el modo, fase de la partida, valores del comando anterior, habilidad activa y Output de servidor/cliente. **Pendiente de validación manual; no se considera jugabilidad aprobada.**
