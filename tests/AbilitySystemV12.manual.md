**Ability System V1.2 — validación de jugabilidad a cargo del desarrollador.**

Todos los casos de esta guía están **NOT RUN**. El agente instaló y verificó código en Edit; no inició Play/Run/Start Server ni controló jugadores. Esta guía reemplaza los pasos de selección de V1: no existe una ventana adicional de seis segundos.

1. Conservar el lugar abierto con tus cambios. Si Rojo está desconectado, conectar a **127.0.0.1:34873**, proyecto **SlapDuels-2.0 Scripts Only SAFE**. Está servido el perfil actualizado de 97 scripts, que conserva instancias físicas desconocidas. No aceptar una propuesta de borrado de recursos usando otro perfil.
2. Iniciar personalmente un servidor local con dos clientes; opcionalmente dejar un tercero en lobby. Antes de entrar a matchmaking, confirmar en Output `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false`. Si no coincide, detener la prueba. Revisar que no aparezcan diagnósticos `[AbilityRegistry]` ni errores de Bootstrap.
3. Ejecutar personalmente este bloque en la Command Bar del **servidor local de prueba**, con los participantes todavía en lobby. Verifica el catálogo y la compra bloqueada; concede propiedad temporal mediante el inventario existente, exclusivamente en memoria:

```lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsServer() and run:IsRunning(), "Sólo servidor local de Studio")
local services = game.ServerScriptService.Services
local data = require(services.PlayerDataService)
local diag = data:GetPersistenceDiagnostics()
assert(diag.Environment == "Studio" and diag.ProviderName == "InMemory"
    and diag.WritesToCloud == false, "ABORTAR: persistencia no aislada")
local registry = require(services.AbilityRegistry)
local catalog = registry.GetPublicCatalog()
assert(catalog and #catalog.Order == 5 and #registry.GetDiagnostics() == 0, "Revisar registro")
local ps = require(services.PlayerService)
local rounds = require(services.RoundService)
local shop = require(services.ShopService)
local players = game:GetService("Players"):GetPlayers()
assert(#players >= 2, "Esperar ambos clientes")
for _, player in ipairs(players) do
    assert(ps:IsShopDataReady(player), "Esperar perfil de " .. player.Name)
    assert(rounds:GetSessionForPlayer(player) == nil, "Preparar todavía en lobby")
    local coins = ps:GetCoins(player)
    local bought, reason = shop:PurchaseProduct(player, "StrongSlap", "Abilities")
    assert(bought == false and ps:GetCoins(player) == coins, "Compra debe seguir bloqueada")
    print("[AbilityV12Manual] Compra rechazada", player.Name, reason)
    for _, id in ipairs(catalog.Order) do
        if not ps:HasItem(player, "Abilities", id) then
            local granted, err = ps:AddItem(player, "Abilities", id)
            assert(granted, tostring(err))
        end
        print("[AbilityV12Manual]", player.Name, id,
            "Duration", catalog.Items[id].Duration, "Cooldown", catalog.Items[id].Cooldown)
    end
end
print("[AbilityV12Manual] Cinco habilidades; propiedad temporal InMemory; precios intactos")
```

El bloque no fue ejecutado por el agente. Las concesiones desaparecen al detener el servidor. Abrir Shop antes de concederlas si se desea observar primero el estado de bloqueo; si ya eran propiedad del jugador, la compra puede rechazarse con AlreadyOwned. No convertir el bloque en un script publicado.

4. Abrir Shop: cinco cards, nombres/iconos existentes, inventario único. Preferir una habilidad adquirida. Entrar con ambos jugadores a Red/Blue, votar y esperar mapa/spawn/Slap equipado. En el countdown inicial **5→1**, verificar botón Cambiar habilidad y HUD actual. El menú debe seguir cerrado hasta pulsar el botón; abrir sólo en A y confirmar una card. B debe conservar su menú cerrado y elección individual. Dejar otra vez el menú abierto hasta el plazo: se cierra solo. El combate comienza sin espera extra y con reloj 3:00.
5. Distribuir las habilidades entre participantes y rondas; usar también el botón táctil/AbilityButton además de E. Medir los siguientes resultados desde cada activación aceptada:

| Caso | Acción y resultado esperado |
|---|---|
| Dash | Probar adelante/atrás/lateral/diagonal y quieto con E; quieto usa orientación. CD 11 s; impulso 0,2 s y parámetro de distancia 24 studs. Repetir contra pared, borde y derribado: sin atravesar obstáculos ni activar durante bloqueo/ragdoll. |
| Golpe Fuerte | E arma durante 15 s, HUD PREPARADA y CD 25 s desde E. Un fallo conserva carga hasta caducar. Un impacto válido consume una sola vez: una eliminación, una Kill/Death, exactamente +50 Coins por Kill y efecto de la víctima; espectáculo vertical de 25 studs en prop separado. Repetir tras dos golpes normales para cubrir coincidencia con el tercer golpe. No anotar un gol al medir la recompensa de Kill. |
| Saltos de Aire | E abre 15 s, CD 20 s. Saltar normalmente y pedir saltos extra con control de salto y botón/E activo; intervalo ≥0,8 s, hasta cuatro antes de suelo, fuerza 32 y velocidad vertical máxima 38. Verificar techo y límite de ascenso 24 studs; tocar suelo repone cuenta. El rival sigue pudiendo golpear. |
| Velocidad Diabólica | E acelera durante 5 s, CD 14 s; multiplicador 2,4, máximo 48, aceleración 100. Verificar restauración al terminar y cancelación por slap, respawn, gol y lobby. Un bloqueo de movimiento posterior debe prevalecer. |
| Invisible | E dura 5 s, CD 35 s. Ambos clientes de la sesión ven avatar, accesorios y Slap ocultos con traza tenue. Sigue siendo vulnerable a golpes y KillPart. Verificar restauración al terminar, eliminarse, cambiar de ronda, desconectarse o regresar al lobby, incluidas transparencias preexistentes. |

6. Anotar un gol: el premio por gol sigue siendo +50 Coins. En el countdown de reinicio **3→1** aparece Cambiar habilidad sin abrir el menú. Sin tocarlo se conserva la elección previa; al elegir otra adquirida y recibir confirmación cambia el HUD. El plazo termina con el countdown y no se extiende al abrir/cerrar. No se permite seleccionar en Playing. La preferencia del Shop y la selección de ronda permanecen separadas.
7. Durante una habilidad activa, provocar una salida/KillPart o abandono. Intentar E repetidamente; no deben aparecer cargas duplicadas, callbacks de una vida anterior, boosts residuales ni errores `[AbilityService]`. Dos contactos de salida deben producir una sola eliminación/recompensa/respawn. Una caída sin atacante no otorga Coins por Kill.
8. Dejar una ronda llegar a 0:30 para observar Muerte Súbita y su caída/punto conforme a las reglas existentes. Dejar llegar al timeout en otra ronda si hace falta. No editar tiempos ni modalidades. Llegar al quinto gol y observar la celebración, EndCinematic, estadísticas y retorno al lobby. Revisar que no quede invisibilidad/velocidad, HUD de partida ni sesión/mapa activo.
9. Repetir una segunda partida. Con un tercer cliente en lobby, comprobar ausencia de HUD, cues e invisibilidad de la partida ajena y rechazo de activación allí. No habilitar XvX ni concurrencia para esta regresión.

Para capturar estado autoritativo, este bloque es de lectura y lo ejecuta el desarrollador en la Command Bar del servidor ya verificado como InMemory:

```lua
local services = game.ServerScriptService.Services
local diag = require(services.PlayerDataService):GetPersistenceDiagnostics()
assert(game:GetService("RunService"):IsStudio()
    and diag.ProviderName == "InMemory" and diag.WritesToCloud == false)
local ps = require(services.PlayerService)
local rounds = require(services.RoundService)
local abilities = require(services.AbilityService)
for _, player in ipairs(game.Players:GetPlayers()) do
    local session = rounds:GetSessionForPlayer(player)
    local record = session and abilities._sessions[session.Id]
    local state = record and record.Players[player]
    local active = state and state.Active
    print("[AbilityV12Manual]", player.Name, "Session", session and session.Id,
        "Ability", state and state.AbilityId, "State", state and state.State,
        "Activation", active and active.ActivationId, "Life", state and state.LifeId,
        "Cooldown", state and math.max(0, state.CooldownUntil - os.clock()),
        "Coins", ps:GetCoins(player), "Kills", ps:GetKills(player))
end
print("[AbilityV12Manual] ActiveMatches", #workspace.ActiveMatches:GetChildren())
```

Capturar Output del servidor y ambos clientes, video/HUD, valores antes/después de activación, Kill, gol y cierre, más el resultado de la segunda partida. Informar por caso PASS/FAIL/BLOCKED con diferencias observadas. Esta entrega no adjudica PASS funcional a ninguno de estos pasos.
