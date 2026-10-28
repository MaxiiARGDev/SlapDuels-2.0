# Ability System V1 — pruebas que ejecuta el desarrollador

No ejecutar tests de jugabilidad con datos cloud. El agente no ejecutó Play, Run, Start Server ni estos comandos de preparación.

## 1. Preparar y verificar el servidor

Conservar/guardar tu lugar cuando lo consideres oportuno. Si Rojo está desconectado, conectar a 127.0.0.1:34873 y confirmar **SlapDuels-2.0 Scripts Only SAFE**. No usar la conexión antigua para sincronizar recursos físicos.

Iniciar personalmente un servidor local con dos clientes; opcionalmente cuatro para dejar dos espectadores en lobby. En el Output del servidor confirmar la línea de Bootstrap con Studio / InMemory / WritesToCloud=false. Si no coincide, detener las pruebas.

Mientras todos están todavía en lobby, ejecutar personalmente en la Command Bar del **servidor de prueba**:

```lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsRunning(), "Sólo servidor local de Studio en ejecución")
local services = game.ServerScriptService.Services
local data = require(services.PlayerDataService)
local diag = data:GetPersistenceDiagnostics()
assert(diag.Environment == "Studio" and diag.ProviderName == "InMemory"
    and diag.WritesToCloud == false, "ABORTAR: proveedor no aislado")
local players = game:GetService("Players")
local ps = require(services.PlayerService)
local rounds = require(services.RoundService)
local shop = require(services.ShopService)
assert(#players:GetPlayers() >= 2, "Se necesitan dos clientes reales")
for _, player in ipairs(players:GetPlayers()) do
    assert(ps:IsShopDataReady(player), "Esperar carga de " .. player.Name)
    assert(rounds:GetSessionForPlayer(player) == nil, "Preparar todavía en lobby")
    -- Comprobar rechazo antes de conceder propiedad, sin inventar precios.
    local balance = ps:GetCoins(player)
    local success, reason = shop:PurchaseProduct(player, "StrongSlap", "Abilities")
    assert(success == false, "No debe existir una compra comercial habilitada")
    assert(ps:GetCoins(player) == balance, "El rechazo no debe descontar Coins")
    print("[AbilityManual] Compra bloqueada", player.Name, reason)
    for _, id in ipairs({"StrongSlap", "AirJumps", "DevilSpeed", "Invisible"}) do
        if not ps:HasItem(player, "Abilities", id) then
            local granted, err = ps:AddItem(player, "Abilities", id)
            assert(granted, tostring(err))
        end
    end
    print("[AbilityManual] Propiedad temporal InMemory preparada", player.Name)
end
print("[AbilityManual] Studio / InMemory / WritesToCloud=false; sin cambios de precios")
```

Este comando concede ítems de prueba mediante el inventario existente; no compra, no agrega Coins y no cambia configuración. Las concesiones desaparecen al detener ese servidor InMemory. Para observar primero los productos bloqueados, abrir Shop antes de ejecutarlo. No usarlo en producción ni publicar estas concesiones como un script.

## 2. Flujo base y selección

1. Colocar dos participantes en Red/Blue, observar reserva, countdown y voto de mapa.
2. Verificar mapa/spawns y Slap equipado/bloqueado.
3. Aparece selección durante 6 s; confirmar una card por participante. Luego comienzan los 5 s originales.
4. Sin elegir, se utiliza preferencia válida o Dash. En Playing la selección desaparece.
5. Abrir Shop y PREFERIR otra habilidad: debe cambiar sólo la preferencia; la habilidad actual continúa hasta la siguiente preparación.
6. Anotar un gol: +50 Coins del gol, nueva ventana de 6 s y luego countdown original de 3 s. Seleccionar otra habilidad.

## 3. Probar las cinco habilidades

Una única habilidad por ronda. Se pueden distribuir las cinco en las cinco salidas previas al quinto gol; no es necesario modificar tiempos, mapas ni modalidades.

| Habilidad | Acciones exactas y resultado esperado |
|---|---|
| Dash | Seleccionarla; en Playing mover adelante/atrás/lateral/diagonal y pulsar E. Estando quieto, E usa orientación. Repetir tras 11 s. Intentar antes del cooldown, contra una pared, cerca del borde y derribado. No debe cruzar obstáculos ni activarse en ragdoll; no debe alterar velocidad al volver al lobby. 24 studs son una referencia provisional, no cuatro cuadros demostrados. |
| Golpe Fuerte | Seleccionarla; E muestra PREPARADA hasta 15 s. Fallar un slap conserva recuperación normal y la carga sigue hasta un impacto válido o caducidad. Conectar contra rival: una Kill/Death y exactamente +50 Coins, un efecto equipado por víctima, un respawn y presentación vertical separada. La siguiente activación es 25 s desde E. Dejar caducar otra carga: ninguna Kill. En otra vida dar dos golpes normales, esperar recuperaciones y usar StrongSlap como siguiente impacto: una sola eliminación/recompensa. |
| Saltos de Aire | Seleccionarla; E activa 15 s. Saltar normalmente y, en el aire, volver a pedir salto con el control normal o el botón de habilidad. Esperar al menos 0,8 s entre saltos. Verificar hasta cuatro adicionales antes de suelo, ascenso limitado y techo sólido. Mantener posibilidad de recibir golpes. Cooldown de 20 s desde activación. |
| Velocidad Diabólica | E activa aceleración durante 5 s. Recorrer piso/obstáculo/borde; sigue expuesto a slaps y KillPart. Verificar vuelta a velocidad normal. Activar otra vez y recibir slap: se cancela el resto de duración; no queda velocidad extra tras recuperación, gol, respawn o lobby. Cooldown 14 s. |
| Invisible | E durante 5 s: desde ambos clientes de la sesión observar avatar, accesorios y Slap ocultos con rastro leve. Golpearlo y comprobar KillPart: sigue siendo vulnerable. Al finalizar, morir, cambiar de ronda o salir, restaurar apariencia original, incluidos objetos que ya tenían transparencia. Cooldown 35 s. |

En móvil, usar AbilityButton. Comprobar tamaño, scrolling de selección y feedback de cooldown. Ajustar su posición artísticamente en StarterGui si hace falta; el controller no la reasigna.

## 4. Observar autoridad y cooldown

En la Command Bar del servidor de prueba, después de verificar el aislamiento como en el primer bloque, se puede inspeccionar sin modificar estado:

```lua
local ps = require(game.ServerScriptService.Services.PlayerService)
local rounds = require(game.ServerScriptService.Services.RoundService)
local abilities = require(game.ServerScriptService.Services.AbilityService)
for _, player in ipairs(game.Players:GetPlayers()) do
    local session = rounds:GetSessionForPlayer(player)
    local record = session and abilities._sessions[session.Id]
    local state = record and record.Players[player]
    print("[AbilityManual]", player.Name,
        "Session", session and session.Id, "Selected", state and state.AbilityId,
        "State", state and state.State, "CooldownRemaining",
        state and math.max(0, state.CooldownUntil - os.clock()),
        "LifeId", state and state.LifeId, "Coins", ps:GetCoins(player), "Kills", ps:GetKills(player))
end
```

Capturar antes/después de E, eliminación y nueva ronda. Tras eliminación dentro de la misma ronda el deadline no debe reiniciarse; después de nueva preparación queda listo. Spamear E no debe crear varias activaciones. No sumar un gol mientras se mide el premio de Kill: gol y Kill son recompensas independientes.

## 5. Regresión, aislamiento y segunda partida

1. Dos contactos con KillPart en la misma salida: una sola eliminación/recompensa/recuperación. Caída sin atacante: cero recompensa por Kill.
2. Gol normal: exactamente +50 Coins del gol; el sistema de habilidad no paga ese premio.
3. Alcanzar 4 puntos y luego 5: aviso y final existentes; sin efectos de habilidad durante EndCinematic o lobby.
4. Observar ronda de 3 minutos, Muerte Súbita a 30 s y timeout. No hay cooldown alternativo durante Muerte Súbita.
5. Con clientes adicionales en lobby: sin HUD, invisibilidad local o espectáculo de otra partida; no pueden activar habilidades allí.
6. Probar abandono con habilidad activa y durante selección. Revisar retorno y limpieza.
7. Completar una segunda partida. Verificar que no se acumulan efectos, conexiones de presentación, velocidad ni transparencias residuales.
8. Al terminar, inspeccionar Workspace.ActiveMatches, registros de AbilityService y apariencia/equipamiento. Comprobar Shop Frost/Void y preferencias musicales.
9. Antes de detener el servidor, repetir GetPersistenceDiagnostics: debe seguir InMemory/false. Al detenerlo, los callbacks de persistencia continúan con ese proveedor; no cambiar configuración ni nombres de stores.

## 6. Evidencia para devolver

- Output completo de servidor y de ambos clientes, incluida la línea de persistencia.
- Videos/capturas de selección, cada habilidad, cooldown, premio de Kill/gol y retorno al lobby.
- Saldos/Kills antes y después; conteo de respawns/efectos para la prueba de duplicación.
- Resultado de cada fila de la matriz de AbilitySystemV1.validation.md: PASS/FAIL/BLOCKED y pasos para reproducir cualquier falla.

No se considera validada una prueba por ver únicamente el código o por aprobar las aserciones aisladas. Las compras reales y sus pruebas permanecen bloqueadas hasta recibir los cuatro precios aprobados; el audio queda pendiente de SoundIds autorizados.
