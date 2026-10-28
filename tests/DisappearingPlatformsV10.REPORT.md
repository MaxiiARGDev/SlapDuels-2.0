# Disappearing Platforms V1.0

Implementado y sincronizado en **Studio Edit**. No se inició Play, Run, Team Test ni Start Server, no se controlaron personajes y no se ejecutaron partidas. La jugabilidad y la replicación entre clientes reales quedan **NOT RUN / pendientes del desarrollador**.

## Auditoría de mapas y sesiones

`RoundService:_runSession` selecciona el mapa y llama a `MatchInstanceService:CreateInstance(session, selectedMap)` durante MapLoading. Este valida la plantilla en `ServerStorage.Maps`, reserva el ArenaSlot, clona el Model, ejecuta PivotTo y lo inserta en:

```text
Workspace.ActiveMatches.Match_<sessionId>.<nombre del mapa>
```

`instanceInfo.InstanceModel`, `.Container` y `.Geometry` contienen las referencias reales. Después de preparar satisfactoriamente EndCinematic y antes de devolver instanceInfo, se registra ese clon con el nuevo servicio. RoundService asigna entonces `session.InstanceInfo`. La detección solo ocurre posteriormente en Playing y comprueba esa identidad exacta.

La creación repetida de una instancia devuelve la misma instancia existente sin registrar ni reiniciar plataformas. Las partidas posteriores clonan nuevamente la plantilla; la reutilización del ArenaSlot no reutiliza el mapa.

`DestroyInstance` ahora desvincula el controlador **antes** de destruir el contenedor, incluido el camino de limpieza idempotente/orfandad. Las salidas normales y las cancelaciones de RoundService ya utilizan este método. RoundService no fue modificado en esta tarea.

### Inspección física en Edit

La carpeta Maps estaba inicialmente vacía. El desarrollador volvió a colocar sus dos mapas; el agente no movió ni recreó mapas. Se tomó la referencia de integridad después de esa reposición:

| Plantilla | Geometry | White_Part | No colisionables | CanQuery=false | Rotadas |
|---|---|---:|---:|---:|---:|
| ServerStorage.Maps.Circulos | Folder | 10 | 0 | 0 | 0 |
| ServerStorage.Maps.Levels | Folder | 14 | 0 | 0 | 0 |

Las 24 plataformas inspeccionadas son Part. No se agregó ningún Script a ellas y no se cambiaron propiedades físicas, colores, materiales, tamaños, nombres ni spawns.

## Servicio y configuración

Componentes nuevos:

- `ReplicatedStorage.Shared.DisappearingPlatformsConfig` — configuración global editable.
- `ServerScriptService.Services.DisappearingPlatformsService` — controlador autoritativo con registros independientes por mapa.
- `ServerScriptService.Services.Platforms.PlatformPolicy` — validación de configuración, altura del rig y geometría de apoyo.

Valores iniciales:

```lua
Enabled = true
TargetPartName = "White_Part"
GeometryFolderName = "Geometry"
FadeDelay = 0
FadeDuration = 2
DetectionInterval = 0.1
DisableCollisionOnFadeComplete = true
ResetDuringMatch = false
SupportTolerance = 0.25
SurfaceTolerance = 0.05
TopNormalDot = 0.98
MaxSupportNormalSpeed = 4
```

FadeDuration debe ser mayor que cero y no superar 60 s; FadeDelay admite 0–60 s; DetectionInterval admite 0,02–5 s. Se rechazan NaN, infinitos, tipos incorrectos, nombres vacíos y tolerancias fuera de rango. V1 exige ResetDuringMatch=false y DisableCollisionOnFadeComplete=true. Una configuración inválida deshabilita la función con un warning de servidor; no aplica tiempos inventados ni impide iniciar las demás funciones de la partida.

## Descubrimiento y autorización

Se obtiene Geometry directamente del clon y se recorre **una vez** con GetDescendants. Se registran exclusivamente sus descendientes BasePart con nombre exacto White_Part, incluidos Models y Folders anidados. Se ignoran otros nombres y cualquier White_Part fuera de Geometry.

BindMap rechaza plantillas en ServerStorage, mapas fuera de Workspace y referencias que no correspondan al registro de MatchInstanceService y RoundService. No se escanea indiscriminadamente Workspace ni se procesa el mapa de exposición del lobby.

## Pisada real

Un raycast vertical descendente desde HumanoidRootPart busca el primer apoyo físico, con longitud limitada por la altura real del rig más 0,25 studs. Para R6 se incluye el tamaño de la pierna; para R15 se usa HipHeight y media altura de la raíz. No se depende de FloorMaterial replicado ni de accesorios/Touched.

El servidor exige simultáneamente:

1. Un Player conectado, su Character actual en Workspace, Humanoid vivo y raíz válida.
2. MatchId, sesión autoritativa y registro de participante coincidentes; se excluyen Left/Released.
3. Sesión Playing, ronda abierta y ausencia de cierre, resultado, congelación de gameplay o PointInProgress.
4. Humanoid en Running, RunningNoPhysics o Landed; no sentado, en PlatformStand, ragdoll ni retiro de arena.
5. Primer resultado del raycast sobre una plataforma registrada de **ese mapa**, con CanCollide activo.
6. Normal correspondiente a la cara superior local, punto dentro de sus límites y raíz por encima del plano superior.
7. Distancia de apoyo acorde a la altura del rig; un raycast largo no puede activar plataformas lejanas bajo un salto.
8. Velocidad relativa a la plataforma sobre la normal de apoyo limitada. Caminar tangencialmente por una pendiente no se confunde con volar verticalmente.

La consulta excluye el Character y respeta colisión y su grupo corporal. Un accesorio, Slap u objeto no jugador no solicita activaciones; si un objeto colisionable bloquea el rayo, no se atraviesa para activar una plataforma que no es el primer apoyo.

Las comprobaciones de cara superior usan CFrame:PointToObjectSpace y UpVector; no dependen solo de Y mundial. Se probaron matemáticamente Parts inclinadas. Los dos mapas reales actuales tienen Parts sin inclinación. La precisión de detección con animaciones reales, rigs personalizados, pendientes y red requiere la validación manual indicada abajo; no se declara observada por probar las matemáticas.

## Estados, animación y colisión

`Idle → Triggered → Fading → Disappeared`.

Triggered se reserva de forma síncrona antes del delay/tween. Dos jugadores sobre la misma plataforma no reinician el tiempo ni crean animaciones adicionales. Se usa TweenService de servidor, interpolación lineal de Transparency desde su valor actual hasta 1 durante FadeDuration.

**CanCollide se conserva durante Triggered y Fading.** Solo un Completed con `Enum.PlaybackState.Completed`, y con mapa/sesión/registro aún vigentes, ejecuta en ese orden:

```lua
part.Transparency = 1
part.CanCollide = false
```

No se destruye la plataforma, no se cambia su posición y no se desactiva CanTouch/CanQuery ni se altera KillPart. Una cancelación no ejecuta esa transición final. Las plataformas inicialmente invisibles o no colisionables se registran, pero no se fuerzan a ser visibles/colisionables ni se activan como un apoyo válido.

La presentación usa las propiedades del objeto compartido del servidor; no hay copias ni estados privados por cliente. La observación de la replicación real en dos clientes sigue pendiente.

## Duración del estado y limpieza

No hay restauración por gol, reinicio de jugada, respawn, Muerte Súbita ni cambio de ronda. Los fades ya iniciados pueden continuar entre jugadas mientras la sesión siga válida; no se inician nuevas pisadas fuera de Playing. Cuando la sesión termina se cancelan sus trabajos y se conserva el estado parcial hasta que el flujo existente destruya el clon.

Se valida la identidad del registro en cada callback. Un cierre detectado en el siguiente intervalo (0,1 s por defecto) detiene su monitor; los callbacks también comprueban el cierre antes de escribir, sin esperar al próximo intervalo. DestroyInstance, Destroying del Model y la salida del mapa de su contenedor también desvinculan el registro.

La limpieza primero invalida el registro y luego cancela delays, desconecta Completed, cancela/destruye tweens, desconecta los dos eventos del mapa y vacía referencias. Un callback retenido de un mapa anterior no puede escribir en su Part ni en uno de otra instancia. El único Heartbeat se desconecta cuando no quedan mapas registrados.

## Rendimiento y sistemas preservados

No hay loops, Scripts ni Touched por plataforma. Se hace un descubrimiento O(n) por clon y consultas O(participantes) cada DetectionInterval, con búsqueda de plataforma por diccionario. En un 4v4 son como máximo unos 80 raycasts/s con el intervalo predeterminado, sin contar participantes excluidos antes de consultar. No se recorren cientos de plataformas por jugador ni se acumulan ráfagas de consultas después de un frame lento.

No se cambiaron concurrencia, modalidades, movimiento, SlapService, RagdollService, KillPart, atribución de eliminaciones, respawn, goles, Coins, habilidades, Muerte Súbita ni EndCinematic. Una caída usa el circuito existente de KillPart/VoidBoundary. No hay nuevas recompensas ni RemoteEvents.

## Archivos

Lógica y mapeo:

- Nuevos: `src/shared/DisappearingPlatformsConfig.luau`, `src/server/Services/DisappearingPlatformsService.luau`, `src/server/Services/Platforms/PlatformPolicy.luau`.
- Modificados: `src/server/Bootstrap.server.luau` (orden de servicio), `src/server/Services/MatchInstanceService.luau` (registro/limpieza), `studio-safe.project.json` (mapeo explícito). El proyecto normal incluye las carpetas automáticamente.
- Pruebas: `tests/DisappearingPlatformsV10.spec.luau`, `tests/tools/run_disappearing_platforms_v10.py`, `tests/tools/validate_disappearing_platforms_v10.py` y evidencias DisappearingPlatformsV10.

Copias previas de Bootstrap, MatchInstanceService y SAFE en `tests/assets/backups/DisappearingPlatformsV10/`. El respaldo integral anterior no se modificó.

## Verificaciones ejecutadas

| Verificación | Resultado |
|---|---|
| Plataformas, geometría, configuración, tweens, sesiones, limpieza y entradas existentes de KillPart/VoidBoundary | **PASS: 82 aserciones aisladas**, módulos reales y mocks deterministas en Luau local |
| MatchmakingXVXV12 | **PASS: 49 aserciones aisladas** |
| MovementSpeedV10, incluido respawn y autoridad económica básica | **PASS: 54 aserciones aisladas** |
| Compilación de src | **PASS: 216 scripts Luau** |
| Rojo default | **PASS**, `DisappearingPlatformsV10.default.rbxlx` |
| Rojo SAFE | **PASS**, `DisappearingPlatformsV10.safe.rbxlx` |
| git diff --check | **PASS** |
| Código/recursos anteriores no autorizados para modificación | **PASS: 288 archivos idénticos**, comparación SHA-256 binaria contra inventario tomado antes de editar |
| Sync código Edit | **PASS: cinco fuentes y sus EditorSource coinciden** |
| Mapas y GUI físicos | **PASS**, fingerprint de jerarquías y propiedades seleccionadas antes/después |
| Persistencia en Edit | **Studio / InMemory / WritesToCloud=false** |
| Física, interacción real, replicación y partidas | **NOT RUN**, pruebas del desarrollador |

### Cobertura de los 37 casos solicitados

| Casos | Cobertura y límites |
|---|---|
| 1–6 | Geometry, nombres exactos, Models/Folders anidados y exclusión fuera del árbol |
| 7–9 | Validación de configuración, duración distinta y delay distinto |
| 10–16 | Apoyo válido, cara lateral/inferior, objeto no jugador, resultado no registrado, jugador ajeno/desconectado, salto/freefall, separación excesiva y velocidad de vuelo |
| 17–22 | Dos participantes, única reserva/tween, interpolación de midpoint simulada, colisión hasta Completed e imposibilidad de reactivación |
| 23–26 | Se mantiene estado entre jugadas/PointRestart, nueva ronda, Muerte Súbita y Character nuevo; no hay hook de restauración |
| 27–28 | Mapa nuevo intacto, rechazo de plantillas y CreateInstance real sobre modelos mock; además integridad de mapas reales en Edit |
| 29–31 | Cancelación de delay/tween, desconexión de listeners/Heartbeat, Destroying durante fade y callbacks tardíos forzados |
| 32–35 | Registros de los cuatro tamaños de equipo; consultas de participantes propios |
| 36 | Regresión aislada de matchmaking/RoundService, hook real CreateInstance y DestroyInstance |
| 37 | Entradas reales de HandleKillPartTouch/HandleVoidBoundaryTouch sobre contactos mock y rechazo de contacto lejano; fuentes de eliminación intactas |

Una animación de TweenService o una caída física real **no** se declara PASS por simular un tween/contacto. Tampoco se ha probado la precisión del apoyo del avatar real a velocidad 16/32 ni la atribución de una Kill real tras caer. Esas verificaciones están pendientes.

## Evidencia de Studio Edit

Instancia: `db8d0a29-ee57-450f-9328-c301cdde90e0`, PlaceId `107328891970677`, Universe `10769217377`.

Se hizo preflight de Source y EditorSource antes de escribir y se revalidaron dentro de UpdateSourceAsync. Solo se crearon tres ModuleScripts y la carpeta Services.Platforms, y se editaron Bootstrap y MatchInstanceService. No se aplicó una sincronización completa del árbol ni se importaron assets o GUI. No se guardó, cerró ni publicó el lugar.

Los fingerprints antes/después coinciden para ServerStorage.Maps (280 descendientes), StarterGui (2887) y StarterCharacter (37). Incluyen nombres/clases y propiedades seleccionadas de piezas/GUI: CFrame, Size, Color, Material, Transparency, colisiones y propiedades de layout, entre otras. Son verificaciones de preservación física, no un respaldo completo de cada propiedad del DataModel.

Evidencias: `DisappearingPlatformsV10.studio-before.json`, `.studio-edit.json`, `.source-hashes.json`, `.before-files.json`, `.protected.json`, `.results.txt`, `.matchmaking.txt`, `.compile.txt`, `.default.build.txt`, `.safe.build.txt`, `.diff.txt`. La regresión de movimiento está en `MovementSpeedV10.results.txt`.

## Pruebas manuales — las ejecuta el desarrollador

1. Iniciar tu prueba en Studio cuando quieras. Confirmar en Output **Studio / InMemory / WritesToCloud=false**. Al crear la arena debe aparecer `[DisappearingPlatforms] Bound Match=... Map=... Platforms=10` para Circulos o `Platforms=14` para Levels.
2. Completar matchmaking y entrar en Playing. Antes de Playing no deben activarse plataformas. Pisar una White_Part desde arriba: debe desvanecerse durante **2 s**, manteniendo apoyo hasta quedar invisible; recién entonces se cae.
3. Saltar sobre otra sin aterrizar, rozarla de lado con cuerpo/Slap y pasar por debajo: no debe activarse. Después aterrizar o caminar sobre ella: sí debe activarse. Probar especialmente desplazamiento continuo y aterrizaje del R6 actual.
4. Con dos clientes, pisar la misma plataforma simultáneamente: ambos deben ver un único fade, sin reinicios del tiempo. Otro jugador que llegue cuando ya desapareció debe atravesar el espacio.
5. Verificar que la caída conserva KillPart/VoidBoundary, ragdoll, atribución de Kill y recompensas actuales. No se agregan Coins por desaparecer una plataforma.
6. Anotar un gol, respawnear y llegar a Muerte Súbita: las plataformas desaparecidas siguen así. Las piezas con otros nombres no deben alterarse.
7. Terminar la partida y volver al lobby. Iniciar otra y seleccionar el mismo mapa: sus plataformas vuelven al aspecto original. Repetir con el otro mapa y con 2v2/3v3/4v4 cuando dispongas de participantes.
8. Cerrar/cancelar una sesión durante un fade: no deben quedar errores, tweens activos o callbacks de esa sesión actuando en el siguiente mapa. Comprobar EndCinematic y retorno normal al lobby con velocidad 32; en partida la base sigue en 16.

Para inspeccionar sin cambiar nada, desde **Command Bar del servidor de tu prueba**:

```lua
local rounds = require(game.ServerScriptService.Services.RoundService)
for _, session in rounds:GetActiveSessions() do
 local info = session.InstanceInfo
 local geometry = info and info.InstanceModel:FindFirstChild("Geometry")
 if geometry then
  local total, invisible, noncollidable = 0, 0, 0
  for _, part in geometry:GetDescendants() do
   if part:IsA("BasePart") and part.Name == "White_Part" then
    total += 1
    if part.Transparency >= 1 then invisible += 1 end
    if not part.CanCollide then noncollidable += 1 end
   end
  end
  print(session.Id, session.State, "WhiteParts", total, "Invisible", invisible, "NoCollision", noncollidable)
 end
end
```

Si falla, capturar Output del servidor y clientes, mapa/modalidad, fase de la sesión, si fue pisada/salto/ragdoll y los valores Transparency/CanCollide del clon afectado. No editar la plantilla para fabricar un resultado. **Implementación lista para validación manual; jugabilidad aún no aprobada.**

## Referencias técnicas

Se contrastaron las APIs con documentación oficial: [WorldRoot.Raycast](https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast), [Humanoid.FloorMaterial](https://create.roblox.com/docs/reference/engine/classes/Humanoid#FloorMaterial), [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams) y [TweenBase.Completed](https://create.roblox.com/docs/reference/engine/classes/TweenBase#Completed). La distinción Completed/cancelación se valida explícitamente antes de retirar colisión.
