**Dash multijugador — repetición manual con diagnóstico.** El agente no ejecutó ninguno de los pasos de jugabilidad. Causa real y PASS multijugador **pendientes**.

El código mantiene Dash gratuito, duración 0,2 s, distancia configurada 24 studs y cooldown 11 s. No comprar ni conceder habilidades para esta prueba inicial. No modificar fuerzas, mapas, HUD, tiempos ni producción.

1. En el lugar de **Edit** correcto, comprobar la conexión Rojo **127.0.0.1:34873**, proyecto **SlapDuels-2.0 Scripts Only SAFE**. El servidor SAFE fue reiniciado para incluir `ReplicatedStorage.Shared.AbilityDiagnostics`: hay 98 scripts. Si la conexión anterior quedó desconectada, reconectar al mismo puerto. No importar los builds sobre tu lugar ni aceptar borrados de objetos físicos.
2. Activar la traza antes de iniciar tu prueba. Ejecutar personalmente en la Command Bar de **Edit**, sin Play:

```lua
assert(game:GetService("RunService"):IsStudio()
    and not game:GetService("RunService"):IsRunning(), "Ejecutar en Edit")
local shared = game.ReplicatedStorage.Shared
assert(shared:FindFirstChild("AbilityDiagnostics"), "Falta sincronizar el módulo de diagnóstico")
game.ReplicatedStorage:SetAttribute("AbilityDiagnosticsEnabled", true)
print("[DashCheck] Diagnóstico preparado para la próxima prueba local")
```

3. Iniciar vos **Server & Clients con dos clientes locales**, como prueba controlada del contenido de Edit. Roblox distingue este modo de Team Test y de Test/Test Here de un solo jugador; no se debe inferir que una sesión publicada ejecuta las fuentes actuales de Edit. [Modos oficiales de prueba](https://create.roblox.com/docs/studio/testing-modes).
4. Antes del matchmaking, confirmar en el Output del servidor `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false`. Buscar `[AbilityTrace]` con `Build="AbilityMultiplayerFixV1"`, `Side="Server"`, `Phase="Ready"`, `RegistryCount=5`, `RemotesReady=true`. Cada cliente debe emitir `Side="Client"`, `Phase="Ready"` y el mismo Build. Si falta el módulo, no aparece el marcador esperado, el servidor informa Blocked o IsStudio=false, detener y enviar esos logs; no habilitar cloud ni modificar Universe ID para continuar.
5. Si la bandera no llegó a la sesión pero el módulo y el entorno son correctos, se puede activar durante la prueba **sólo en la Command Bar del servidor local**. Este bloque no inicia una partida ni toca perfiles:

```lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsServer() and run:IsRunning())
local services = game.ServerScriptService.Services
local diag = require(services.PlayerDataService):GetPersistenceDiagnostics()
assert(diag.Environment == "Studio" and diag.ProviderName == "InMemory"
    and diag.WritesToCloud == false, "ABORTAR: entorno no aislado")
local tracing = require(game.ReplicatedStorage.Shared.AbilityDiagnostics)
game.ReplicatedStorage:SetAttribute(tracing.Attribute, true)
tracing.Emit("Server", "ManualReady", {
    Environment = diag.Environment, Provider = diag.ProviderName,
    WritesToCloud = diag.WritesToCloud,
    RegistryCount = #require(services.AbilityRegistry).GetPublicCatalog().Order,
})
```

Este ManualReady es una observación posterior, no evidencia de que el arranque se haya trazado. Si hay dudas, empezar de nuevo con la bandera preparada en Edit. No ejecutar el bloque en un servidor que no cumpla el guard.

6. Ingresar ambos a Red/Blue, votar y esperar spawn, Slap y countdown **5→1**. No abrir Shop ni cambiar habilidad. Al empezar Playing, ambos deben tener Impulso/AbilityId Dash. Activar en un área despejada, sin tocar al rival, paredes ni sensores. No activar durante countdown, bloqueo de movimiento o ragdoll: allí el rechazo es esperado.
7. En A, cerrar chat/textboxes y pulsar **E una sola vez**. Guardar Output del servidor y ambos clientes desde antes de pulsar hasta finalizar el cooldown. Repetir con el botón de habilidad/móvil. Esperar más de 11 s antes de repetir A. B debe poder activar independientemente mientras A tiene cooldown.
8. La secuencia esperada por intento aceptado es:

| Origen | Phase | Qué demuestra |
|---|---|---|
| Cliente | InputDetected | Llegó E o AbilityButton; informa si el input estaba procesado/foco de texto |
| Cliente | RequestSent | Se llamó a FireServer con identidad actual y TraceId |
| Servidor | Received | Entró al handler después del rate limit/tipos básicos |
| Servidor | StartBegin | Pasó validación autoritativa y resolvió el módulo |
| Servidor | Accepted | Start retornó true; empezó cooldown |
| Cliente | ServerResult | Recibió el resultado diagnóstico privado, sin alterar autoridad/HUD |
| Servidor | FirstStep | Se intentó el primer seguimiento; incluye movimiento, velocidad, dt y ownership |
| Servidor | Cancelled | Terminó/canceló; incluye motivo, tiempo activo y distancia observada antes de limpiar |
| Cliente | SnapshotChanged | Llegó estado autoritativo que utiliza el HUD |

Start prepara dirección y ownership; la velocidad se aplica en Step/Heartbeat, como ya ocurría antes. FirstStep con distancia 0 al comienzo no demuestra por sí mismo un fallo de movimiento: comparar con la distancia al cancelar. No se generan líneas por frame; hay un primer paso por activación y presupuesto de Output por usuario.

9. Si aparece Rejected, conservar su **Reason exacto** y TraceId. Casos relevantes: NoSession, AbilitySessionNotPrepared, SessionMismatch, NotPlaying, MovementLocked, RootAnchored, PlatformStand, RagdolledService, RespawnPending, LifeChangedResync, LifeIdMismatch, GenerationMismatch, RoundMismatch, SelectedAbilityMismatch, RegistryEntryUnavailable, ProfileNotReady, NotOwned, AlreadyActive, Cooldown e InvalidActivationInput. Un NoSession en lobby no es una regresión: Dash no está habilitado fuera de combate.
10. Si Start fue aceptado pero no hubo impulso, buscar FirstStep/Cancelled: OwnershipUnavailable, OwnershipCaptureFailed, OwnershipTakeFailed, LongFrame, InitialOverlap, ObstacleSweep, MissingArenaBounds, ArenaEnvelope, KillPartSweep, DistanceComplete, StepCallbackError o ExpiredOrInvalidated. Capturar también vídeo y posición aparente al activar; el agente no incrementó fuerzas para ocultar estos escenarios.
11. Provocar una salida/respawn mediante las reglas normales. En la misma ronda el cooldown no debe reiniciarse por la muerte; respetar el deadline. Anotar un gol: ventana de selección **3→1** y nueva ronda con el reset habitual. Repetir una segunda partida. Revisar que cada jugador conserva identidad/estado independiente. No asumir nada sobre las otras cuatro habilidades: probarlas después, si Dash permite continuar, con el flujo existente de propiedad/selección.
12. Si la prueba local funciona, repetir personalmente en **Team Test** sólo después de comprobar los mismos marcadores y aislamiento. Con Drafts, la prueba individual puede usar cambios locales mientras la prueba colaborativa usa la versión compartida. Revisar **Compare With Server** de forma no destructiva si falta un marcador o hay errores de módulos; no hacer Commit de drafts ni publicar dentro de esta tarea. La auditoría de Edit actual encontró Source/GetEditorSource iguales, pero eso no identifica el código de la sesión fallida anterior. [Documentación de colaboración](https://create.roblox.com/docs/projects/collaboration#drafts-mode).

Enviar estas evidencias si persiste:

- Modo exacto usado: Server & Clients local, Team Test o sesión publicada; fecha/hora y pasos del intento.
- Output completo del servidor y ambos clientes: Bootstrap/persistencia, Ready y todas las líneas `[AbilityTrace]` del mismo intento; conservar TraceId, ActivationId, SessionId, RoundId y UserId. No enviar tokens, credenciales ni listas de jugadores ajenos.
- Primer Phase que falta, o Reason de Rejected/Cancelled, y errores con stack de AbilityController, AbilityService, AbilityCallbacks, MovementGuard o dependencias.
- Captura/vídeo de HUD antes de E, inmediatamente después y al acabar; indicar si el cooldown arrancó y si hubo desplazamiento breve o ninguno.
- Build/PlaceId/GameId/PlaceVersion que imprimen las trazas; no confundir PlaceId con una aprobación de Universe ID.

Después de detener personalmente la prueba, volver a **Edit** y apagar el diagnóstico:

```lua
assert(game:GetService("RunService"):IsStudio()
    and not game:GetService("RunService"):IsRunning())
game.ReplicatedStorage:SetAttribute("AbilityDiagnosticsEnabled", nil)
```

La instalación se entregó con esta bandera apagada. No dejarla activada por defecto ni publicar para probar este diagnóstico.
