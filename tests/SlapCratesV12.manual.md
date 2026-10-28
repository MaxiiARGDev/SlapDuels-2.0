# Slap Crates V1.2 — prueba manual del desarrollador

La fixture StudioTest ya está habilitada en Edit. Las 12 cajas comerciales permanecen pendientes y bloqueadas. El agente no inició Play ni pruebas con jugadores.

1. Guardá normalmente tu place preservando tus cambios. Iniciá vos una sesión local de Studio. Antes de comprar, ejecutá en Command Bar **servidor**:

```lua
assert(game:GetService("RunService"):IsStudio(), "Abortar: no es Studio")
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "Abortar: persistencia no aislada")
print("PersistenceEnvironment="..d.Environment, "PersistenceProvider="..d.ProviderName, "WritesToCloud="..tostring(d.WritesToCloud))
```

Si falla, no continúes ni habilites API Services. Después de pasar esas comprobaciones, para saldo de prueba repetí los asserts y agregá en el mismo comando del servidor:

```lua
local player = assert(game:GetService("Players"):GetPlayers()[1])
print("Saldo de prueba para", player.Name)
require(game.ServerScriptService.Services.PlayerService):AddCoins(player, 5, "CratesV12InMemoryManualTest")
```

2. Abrí Shop > CAJAS. Capturá el orden: Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood, Galaxy. Después aparece StudioTest. Las comerciales muestran **Precio pendiente**, jamás 0 Coins, y no permiten compra.
3. Elegí StudioTest y VER PROBABILIDADES. Esperá la respuesta: 1 Coin, distribución numérica final y stock InMemory. Con el catálogo actual y perfil limpio: Classic:Basic 75 %, Classic:Common 25 %. No se permite comprar antes de Quote. Si aparece PaidRandomItemsRestricted/elegibilidad no verificable, registrá BLOCKED y Output; no fuerces un bypass.
4. Anotá saldo y cajas. COMPRAR: debe descontar exactamente 1 Coin y sumar una caja cerrada; saldo y cantidad se actualizan en panel/tarjeta. Aún no se entrega el premio. Clics rápidos no deben duplicar la misma operación. Si se pierde la respuesta, REINTENTAR debe resolver la misma operación sin otro descuento.
5. ABRIR: consume una caja, no descuenta Coins y registra una unidad. Compará el premio de la ruleta, el 3D y el inventario. VER ÚLTIMO PREMIO debe mostrar el mismo resultado. Shop > Slaps permite equipar solo Slap + Variation realmente adquiridos.
6. Comprá cajas hasta agotar los 5 Coins si querés verificar falta de saldo. Con 0 Coins y cajas propias, Comprar queda bloqueado y Abrir continúa permitido después de consultar Quote. No ajustes Coins ni inventario desde el cliente.
7. Esperá más de 30 s desde VER PROBABILIDADES: se bloquea la operación hasta volver a consultar. Abrir también invalida el Quote anterior. Probabilidades modificadas/stock agotado deben exigir nueva consulta o bloquear; las pruebas deterministas cubren esos escenarios sin modificar stock comercial.
8. Con un observador cercano en lobby: solo el comprador recibe el HUD privado; el observador puede ver la escena 3D existente. Comprobá que modelos temporales se limpian después de la presentación. No debe otorgarse otra recompensa al cerrar/reabrir la interfaz.
9. Revisá desktop y emulación móvil: preview, precio completo, stock, probabilidades, cantidad, botones y cierre. No se modificaron tamaños/posiciones originales; reportá cualquier recorte con resolución y captura.
10. Comprobá navegación y compra/equipamiento de habilidades y demás categorías. Las pruebas reales de combate/rounds conservan el procedimiento anterior y las ejecutás vos.

Para cada caso devolvé PASS/FAIL/BLOCKED con Output de servidor/cliente, CrateId, OperationId/OpeningId si aparece, Coins/cajas antes y después, captura de Quote y premio. No incluyas tokens de autenticación.

Al finalizar detené vos la sesión. Para ocultar la fixture en Edit sin tocar las comerciales:

```lua
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning())
game.ServerStorage:SetAttribute("CrateStudioTestsEnabled", false)
```

InMemory se pierde al reiniciar el servidor local; esto no valida durabilidad ni stock entre servidores. No publicar ni considerar aprobada la economía comercial con esta fixture.
