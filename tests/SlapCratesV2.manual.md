# Slap Crates V2 — validación del desarrollador

Vos iniciás/detenés Play y controlás los jugadores. El agente implementó y verificó Edit/offline únicamente.

## Preparar Edit

1. Guardá tu place normalmente, sin publicar. En Explorer ubicá Workspace.CrateStands.MainCrateStand. Está provisionalmente junto al spawn de lobby. Mové/rotá el **modelo completo** y ajustá CameraPoint, SpawnPoint y RewardPoint artísticamente. No hace falta modificar coordenadas en scripts.
2. Revisá PreviewAnchors, BillboardAnchor y PresentationTemplate.Effects.FXAnchor. Los SoundIds están vacíos; asigná solo tus recursos aprobados si vas a probar audio. PresentationTemplate permanece como plantilla invisible, sin ejecutar scripts.
3. Configuración actual en src/shared/SlapCrates/OpeningConfig.luau y su ModuleScript ReplicatedStorage.Shared.SlapCrates.OpeningConfig: Mode="StandCinematic", ExclusiveOpening=true, ReopenCooldown=5. Cambios de modo requieren volver a Edit y una **sesión nueva**. Mantené iguales fuente local/Studio usando Rojo SAFE para scripts; no sincronices el recurso completo sobre tu diseño del stand.

## Antes de cada prueba

Iniciá vos servidor local con dos clientes; un tercero sirve como observador. Command Bar **servidor**, antes de comprar:

```lua
assert(game:GetService("RunService"):IsStudio(), "Abortar: no es Studio")
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "Abortar: persistencia no aislada")
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

Si falla, no continuar. No habilitar cloud ni cambiar Universe ID. Después de pasar esos asserts, si falta saldo, en servidor:

```lua
local service = require(game.ServerScriptService.Services.PlayerService)
for _, player in ipairs(game.Players:GetPlayers()) do
 service:AddCoins(player, 5, "CrateStandInMemoryManualTest")
end
```

StudioTest sigue a 1 Coin. Las comerciales muestran precios oficiales y probabilidades pendientes, sin compra. Si PolicyService no verifica jugadores sintéticos, marcar compra BLOCKED y enviar Output; no bypass.

## StandCinematic exclusivo

1. Acercate al stand; E o botón móvil debe abrir **la Shop existente en CAJAS**. Verificá decoración flotante y Billboards de precio/estado.
2. Seleccioná StudioTest, consultá probabilidades y comprá dos cajas. Anotá Coins y cantidad. Debe descontar 1 por compra; abrir no cobra otra vez.
3. Pulsá ABRIR desde el stand. Debe cerrar Shop, cubrir pantalla, cambiar cámara local, mostrar aparición/elevación/giro/crecimiento/temblor/flash y revelar el Slap+Variation adjudicado.
4. Verificá texto del premio, ruleta clásica ausente, cámara/FOV/controles restaurados y overlay/modelos temporales limpios. Shop > Slaps y VER ÚLTIMO PREMIO deben coincidir con el premio visto.
5. Mientras abre A, B cerca observa la misma caja/premio sin cámara ni HUD privado. B puede consultar Shop pero su intento de abrir debe decir stand en uso, sin consumir caja. Probá que un observador se acerque a mitad de secuencia.
6. Al terminar A, B debe poder abrir inmediatamente. A debe esperar 5 segundos desde la liberación; reabrir Shop, cambiar Tool o reenviar la misma operación no elude la espera.
7. Intentá desde lejos o durante combate/Results: no debe iniciar ni consumir por autorización rechazada. Doble clic/reintento no da otro premio por el mismo OperationId.
8. Probá muerte/Character nuevo o desconexión durante una apertura ya adjudicada. El premio permanece; escena/controles se limpian y el stand se libera por contexto/timeout. No deben trasladarse flags al respawn.
9. Iniciá después otra partida normalmente: cámara de combate/EndCinematic conserva prioridad y no recibe una restauración tardía del stand.

## StandCinematic privado

Detené vos la sesión, volvé a Edit y cambiá **ExclusiveOpening=false** en OpeningConfig (fuente y Studio). Iniciá sesión nueva y verificá nuevamente aislamiento.

1. A y B compran StudioTest y consultan Quote.
2. Ambos abren en el mismo stand casi a la vez. Cada uno debe ver su propio premio/cámara, con OpeningId distinto.
3. Un tercero no debe ver las escenas privadas ni recibir su HUD. El stand común sigue disponible, sin EN USO de un único comprador.
4. Cancelación/timeout de A no afecta B. Inventarios y consumo son independientes y no se mezclan resultados.

## Spin original

Detené vos la sesión y cambiá **Mode="Spin"** en Edit, manteniendo igual fuente y Studio. Iniciá sesión nueva y verificá aislamiento.

Abrí Shop > Cajas normalmente, comprá/abrí StudioTest. Debe usar la ruleta horizontal y presentación 3D original, sin cámara del stand ni transición nueva. Verificá inventario/equipamiento, premio y reintentos. El ProximityPrompt del stand queda deshabilitado. Después podés volver a StandCinematic en otra sesión nueva.

## Otro stand, diseño y dispositivos

En Edit cloná MainCrateStand completo dentro de CrateStands y asigná atributo StandId="Secondary" (único). Movelo como modelo. En modo exclusivo probá A en Main y B en Secondary: locks independientes, sin reescribir servicios. Dos modelos con el mismo StandId deben quedar bloqueados hasta corregirlo.

Revisá PC/móvil: prompt, Shop existente, transiciones, encuadre sin cortar modelo, premio legible, regreso de controles y cambios de resolución. Ajustá solo anchors/recursos artísticos. Ningún sonido vacío puede considerarse probado.

## Evidencia a devolver

PASS/FAIL/BLOCKED por caso, modo y exclusividad usados; Output servidor/compradores/espectador, StandId, CrateId, OpeningId/OperationId si aparece, Coins/cajas antes/después, capturas/video de cámara y premio, duración y restos en Workspace. Indicá si cambió Character o se inició EndCinematic. No enviar credenciales. La aprobación funcional depende de estos resultados, no de los tests aislados.
