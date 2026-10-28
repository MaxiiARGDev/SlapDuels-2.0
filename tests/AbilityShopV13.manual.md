**Ability Shop V1.3 — pruebas manuales del desarrollador.** Todos los casos de esta guía están **NOT RUN** hasta recibir tu evidencia. El agente no ejecutó Play, Run, Start Server ni controló jugadores.

Esta guía sustituye los comandos de V1/V1.2 que esperaban compras bloqueadas o concedían habilidades con AddItem. Para validar V1.3 hay que **comprarlas**, sin conceder propiedad directamente.

1. Conservar el lugar abierto y tus cambios locales. Conectar Rojo a **127.0.0.1:34873**, proyecto **SlapDuels-2.0 Scripts Only SAFE**, si estuviera desconectado. No importar los builds de verificación sobre tu escenario ni usar un perfil que proponga borrar objetos físicos. El código actual ya está instalado en Edit; no hay instalador manual pendiente.
2. Iniciar personalmente un **servidor local nuevo con dos clientes**. Confirmar en Output `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false`; si no coincide, detener la prueba. Esperar carga de perfiles y ausencia de diagnósticos AbilityRegistry/errores de Bootstrap.
3. Con ambos jugadores todavía en lobby, ejecutar personalmente este bloque una vez en la Command Bar del **servidor de prueba**. Financia al primer jugador por nombre con 10.000 Coins en memoria y conserva al segundo sin saldo suficiente. No concede habilidades ni habilita persistencia real:

```lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsServer() and run:IsRunning(), "Sólo servidor local de Studio")
local services = game.ServerScriptService.Services
local data = require(services.PlayerDataService)
local diag = data:GetPersistenceDiagnostics()
assert(diag.Environment == "Studio" and diag.ProviderName == "InMemory"
    and diag.WritesToCloud == false, "ABORTAR: persistencia no aislada")
local ps = require(services.PlayerService)
local rounds = require(services.RoundService)
local registry = require(services.AbilityRegistry)
assert(#registry.GetPublicCatalog().Order == 5 and #registry.GetDiagnostics() == 0, "Revisar registro")
local players = game:GetService("Players"):GetPlayers()
table.sort(players, function(a, b) return a.Name < b.Name end)
assert(#players >= 2, "Esperar dos clientes")
local buyer, poor = players[1], players[2]
for _, player in ipairs({buyer, poor}) do
    assert(ps:IsShopDataReady(player), "Esperar perfil: " .. player.Name)
    assert(rounds:GetSessionForPlayer(player) == nil, "Preparar todavía en lobby")
end
assert(ps:GetCoins(poor) < 750, "Usar servidor nuevo para el caso sin saldo")
local missing = 10000 - ps:GetCoins(buyer)
if missing > 0 then
    ps:AddCoins(buyer, missing, "AbilityShopV13Manual", "AbilityShopV13:ManualFunding")
end
assert(ps:GetCoins(buyer) >= 10000, "Financiación ya consumida: reiniciar sesión de prueba")
print("[AbilityShopV13Manual] A con saldo:", buyer.Name, ps:GetCoins(buyer))
print("[AbilityShopV13Manual] B sin saldo:", poor.Name, ps:GetCoins(poor))
```

El agente no ejecutó este bloque. Usa la economía existente y el guardado InMemory; el identificador evita volver a acreditar la misma financiación. No publicarlo como script ni usarlo fuera de Studio. Las compras y fondos de esta sesión no demuestran persistencia entre servidores o reinicios.

4. En ambos clientes, abrir Shop → ABILITIES. Verificar esta tabla, sin PRÓXIMAMENTE/Precio pendiente en las cuatro habilidades de pago:

| AbilityId | Nombre | Precio |
|---|---|---:|
| Dash | Impulso | 0 Coins; propiedad inicial |
| AirJumps | Saltos de Aire | 750 Coins |
| DevilSpeed | Velocidad Diabólica | 1.500 Coins |
| Invisible | Invisible | 2.250 Coins |
| StrongSlap | Golpe Fuerte | 3.000 Coins |

5. En B, seleccionar AirJumps sin comprarla: precio 750, estado Coins insuficientes y COMPRAR deshabilitado. Verificar saldo/propiedad sin cambios. Dash ya debe ser propia y equipable gratis; si es la preferida, debe mostrar PREFERIDA sin una acción de recompra.
6. En A, comprar AirJumps. Desde 10.000 debe quedar **9.250**, propiedad TUYO y botón EQUIPAR. La preferencia todavía debe ser Dash. Pulsar EQUIPAR: PREFERIDA, sin otro descuento. Repetir el intento de equipar: ninguna nueva transacción. Preferir Dash otra vez: gratis.
7. Comprar DevilSpeed, Invisible y StrongSlap. Si no hubo otras transacciones, los saldos sucesivos son **7.750 → 5.500 → 2.500**. Cada propiedad aparece una vez y la compra no cambia automáticamente la preferencia. Verificar que las cards y el saldo visible se refrescan desde el servidor.
8. Cubrir doble clic y cierre de Shop con una habilidad todavía no adquirida, usando una sesión nueva si A ya compró todo. Hacer doble clic rápido, cerrar y reabrir la tienda: como máximo un descuento y una propiedad. Si la respuesta es tan rápida que no se observa la compra pendiente, marcar ese escenario como no observado; no introducir retrasos en scripts de producción para fabricarlo. Esperar al menos 0,3 s entre operaciones deliberadas distintas; RateLimited es un rechazo esperado al enviar spam.
9. Entrar ambos a Red/Blue, votar, comprobar mapa/spawn/Slap y countdown inicial **5→1**. El menú no debe abrirse solo. A pulsa Cambiar habilidad: adquiridas seleccionables, no adquiridas bloqueadas en B, Dash seleccionable para ambos. Confirmar una adquirida dentro del plazo: se actualiza el HUD y cierra el selector. Dejar vencer otra ventana: se cierra y rechaza cambios tardíos.
10. Para comprobar compra durante Playing, comenzar otra sesión de prueba financiada dejando una habilidad sin comprar. Activar Dash u otra habilidad y registrar selección/cooldown. Comprar y equipar la habilidad pendiente desde Shop durante Playing: cambia Owned/Preferred, pero **no** la habilidad competitiva ni su deadline de cooldown. No debe aparecer el selector ni activarse el poder nuevo fuera de una ventana autorizada.
11. Anotar un gol: +50 Coins independiente de compras. En el reinicio **3→1**, abrir Cambiar habilidad y elegir la recién comprada. Sin una nueva selección se conserva la elección competitiva anterior; una preferencia distinta del Shop no la sustituye por sí sola. En una partida nueva se usa la preferencia válida como elección inicial. Los countdowns no restan tiempo a los 3 minutos jugables.
12. Probar las cinco mecánicas: Dash CD11; StrongSlap ventana15/CD25 con una sola Kill y +50 Coins por Kill; AirJumps duración15/CD20 y límites anteriores; DevilSpeed5/CD14 con restauración; Invisible5/CD35 con restauración del avatar/Slap/accesorios. Hacer una compra y después un respawn: la propiedad y la preferencia permanecen en el perfil de la sesión. Sin atacante no hay recompensa por Kill.
13. Revisar Shop de Point Effects y Kill Effects: precios, compra, equipamiento y preferencias propias de cada categoría. Una compra de habilidad no modifica los efectos equipados ni los ajustes existentes. Completar una partida, Muerte Súbita/timeout cuando corresponda, Zero-Death, EndCinematic y retorno al lobby; repetir una segunda partida para observar limpieza.

Captura de lectura para ejecutar personalmente en la Command Bar del servidor ya aislado:

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
    local inventory = ps:GetInventory(player)
    print("[AbilityShopV13Manual]", player.Name, "Coins", ps:GetCoins(player),
        "Preferred", ps:GetEquippedItem(player, "Abilities"),
        "RoundSelected", state and state.AbilityId,
        "CooldownDeadline", state and state.CooldownUntil,
        "Session", session and session.Id)
    for id, owned in pairs(inventory.Owned.Abilities) do
        print("[AbilityShopV13Manual] Owned", player.Name, id, owned)
    end
end
print("[AbilityShopV13Manual] ActiveMatches", #workspace.ActiveMatches:GetChildren())
```

Devolver Output servidor/clientes, capturas de estados de Shop y saldo antes/después, y video de selector/cooldown durante compra y equipamiento. Anotar PASS/FAIL/BLOCKED o no observado para cada caso. No afirmar persistencia de producción ni entre servidores con estos resultados.
