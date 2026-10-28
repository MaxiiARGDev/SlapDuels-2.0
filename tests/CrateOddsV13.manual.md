# Matrices de cajas — validación manual

Vos iniciás Play y controlás jugadores. La implementación del agente solo se verificó en Edit/offline.

1. Guardá normalmente tu place. En Edit comprobá StarterGui.ShopHUD.CratePanel.OddsList con UIListLayout/RowTemplate; mismo espacio que Outcomes. No hace falta instalador. Mantené el modo de apertura que quieras probar en OpeningConfig; no se cambió StandCinematic ni Spin.
2. Iniciá vos una sesión nueva. Antes de operar, Command Bar **servidor local**:

```lua
assert(game:GetService("RunService"):IsStudio(), "Abortar: no es Studio")
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "Abortar: persistencia no aislada")
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

Si falla, no continuar ni activar API Services/cloud.

3. Shop > Cajas: verificá orden Basic→Galaxy y los precios oficiales intactos. Seleccioná cada caja y consultá VER PROBABILIDADES. Debe verse **REVISIÓN · COMPRA BLOQUEADA**, precio real, nombres de Slap/variación, colores, porcentajes efectivos y stock. No debe habilitarse Comprar ni Abrir comercial.
4. Con perfil inicial verás Classic:Basic marcado YA ADQUIRIDO y 0 %, porque todos comienzan poseyéndolo y la política es UniquePerPlayer. En Caja Basic, Common debería ser 60 % efectivo y Galaxy 0.025 % si no hay otras exclusiones; no esperes que el 60 % original de Basic siga sorteándose. Para comparar ese perfil/stock, usar CrateOddsV13.effective-quotes.csv.
5. Desplazá la lista hasta Galaxy. Revisá que porcentajes pequeños no sean 0 por redondeo y que nombres/stock no queden fuera del área, en PC y emulación móvil. Esperá más de 30 s: encabezado QUOTE VENCIDO, nueva consulta necesaria.
6. Si PolicyService no verifica el jugador de prueba, debe bloquear con elegibilidad restringida/no verificable. En ese caso marcar BLOCKED y adjuntar Output; no eludir la política.
7. **No habilites OddsApproved/Enabled para probar las comerciales.** Ya se comprobaron matemáticamente las 12 distribuciones y las compras comerciales deben seguir bloqueadas. Para la prueba real de compra/apertura usá exclusivamente StudioTest a 1 Coin.
8. Si falta saldo para StudioTest, después de pasar los asserts, en servidor:

```lua
local player = assert(game.Players:GetPlayers()[1])
require(game.ServerScriptService.Services.PlayerService):AddCoins(player, 5, "CrateOddsInMemoryManualTest")
```

9. StudioTest mantiene 75 % Basic / 25 % Common con el catálogo actual, porque utiliza AllowDuplicates. Consultá, comprá y abrí; comprobar débito 1, caja +1/−1, premio único, inventario y equipamiento exactos. Spin debe terminar en el premio del servidor; StandCinematic debe mostrar el mismo Slap+Variation. Cambios de modo se hacen en Edit y una sesión nueva, siguiendo SlapCratesV2.manual.md.
10. Tras obtener otra combinación, volvé a consultar las comerciales: esa recompensa debe aparecer como YA ADQUIRIDA y las restantes se recalculan. Si no quedan premios elegibles, no debe consumir cajas. Stock agotado/cambios de stock están cubiertos por tests aislados; no edites stock productivo para fabricar el escenario.
11. En una partida que ejecutes vos, confirmar que gol sigue +150 y Kill +30. Revisá también Shop de habilidades/Death Effects, controles y retorno al lobby; no se modificaron esas fuentes.

Devolvé PASS/FAIL/BLOCKED por caso, CrateId, modo, perfil/propiedades relevantes, captura completa del Quote (incluidas exclusiones y porcentajes pequeños), Coins/cajas antes/después y Output servidor/cliente. No enviar credenciales. Las simulaciones no sustituyen tu validación visual ni autorizan ventas productivas.
