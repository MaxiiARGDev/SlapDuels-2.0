# Validación manual — economía 150/30 y cajas V1.3

Guardá tus cambios de Studio normalmente. El agente dejó los cinco módulos sincronizados en Edit; vos iniciás la sesión y controlás los jugadores.

Antes de operar, Command Bar del **servidor local**:

```lua
assert(game:GetService("RunService"):IsStudio(), "Abortar: no es Studio")
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "Abortar: persistencia no aislada")
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

Si falla, detener la prueba. No activar cloud/API Services ni cambiar Universe ID.

| Caso | Esperado |
|---|---|
| Gol válido | Saldo del anotador +150; aviso +150 Coins y animación hacia CoinTarget; marcador +1 |
| Permanecer/múltiples partes en RedWin/BlueWin | Una sola recompensa y un solo aviso por gol |
| Anotador cae sobre KillPart durante retorno | Sin otra recompensa/operación por esa caída protegida |
| Tercera palmada válida | Atacante +30, Kills +1, víctima Deaths según reglas actuales; aviso +30 solo al atacante |
| Golpe Fuerte válido | Misma recompensa +30, sin doble premio |
| Caída con atacante acreditado | Atacante +30 una sola vez |
| Caída sin atacante | 0 Coins por Kill; sin aviso de recompensa |
| Doble contacto con KillPart | Una sola Kill/recompensa por eliminación |
| Muerte Súbita, caída sin anotador personal | Punto colectivo para rival, sin inventar receptor +150; si hubo Kill acreditada conserva su +30 independiente |
| Jugador tercero en lobby | No recibe recibos/animaciones ajenos |
| Shop > Cajas | Orden Basic…Galaxy y precios de la tabla inferior, sin Precio pendiente ni 0 Coins |
| Caja comercial seleccionada | Probabilidades pendientes y compra bloqueada, incluso con saldo suficiente |
| StudioTest | 1 Coin; compra descuenta 1, caja cerrada +1; abrir no cobra Coins y entrega premio autoritativo |
| Reintentos de StudioTest | Sin doble débito ni premio por la misma operación |
| Otras categorías | Precios de habilidades y Death Effects intactos |

Precios: Basic 500; Common 1000; Uncommon 1750; Rare 3000; Gold 4500; Arcoiris 7000; Emote 10000; Wings 13500; Epic 19000; Legendary 27500; Blood 37500; Galaxy 50000.

Si necesitás saldo local para probar StudioTest, después de verificar aislamiento ejecutá en servidor:

```lua
local player = assert(game.Players:GetPlayers()[1])
print("Saldo de prueba para", player.Name)
require(game.ServerScriptService.Services.PlayerService):AddCoins(player, 5, "EconomyV1InMemoryManualTest")
```

Las cajas comerciales siguen bloqueadas por probabilidades no aprobadas. Si PolicyService no verifica a los participantes sintéticos, StudioTest debe bloquearse: registrar BLOCKED sin eludir elegibilidad.

Usá dos clientes para los casos de combate y un tercero si querés comprobar aislamiento de feedback. Anotá Coins antes/después, atacante/víctima, causa, Goal/EliminationId o transacción mostrada en Output, estado de marcador y capturas del HUD. Revisá PC/móvil, sonido y llegada al CoinTarget existente. Devolvé PASS/FAIL/BLOCKED por caso con Output de servidor y clientes. No enviar credenciales.

InMemory se pierde al cerrar todo el servidor de prueba; no valida durabilidad productiva. La implementación permanece pendiente de tu aceptación funcional.
