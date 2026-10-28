# V2.4 — prueba manual del desarrollador

Todo está instalado en Edit. Guardá normalmente el lugar. No hace falta ejecutar instalador ni importar snapshots. Para scripts usá SAFE; reexportá cualquier nuevo ajuste artístico antes de sincronizar recursos completos.

## Preparación segura

Iniciá vos un servidor local con dos clientes; idealmente un tercero como espectador. En **Command Bar del servidor local**, antes de operar:

```lua
assert(game:GetService("RunService"):IsStudio(), "Abortar: no es Studio")
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "Abortar: persistencia no aislada")
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

Si falla, detener la prueba. No activar API Services, cloud ni aprobaciones comerciales. Si necesitás saldo para las cajas de prueba, solo después de esos asserts:

```lua
local ps = require(game.ServerScriptService.Services.PlayerService)
for _, player in ipairs(game.Players:GetPlayers()) do
    ps:AddCoins(player, 40, "CrateBatchV24InMemoryManualTest")
end
```

Con cada comprador, acercate al stand, abrí Shop > Cajas, consultá **StudioTest** y comprá 30 unidades, una por pulsación (1 Coin cada una). No habilites cajas comerciales. Si StudioTest no aparece o PolicyService bloquea las cuentas de test, capturá Output y dejá la prueba BLOCKED sin bypass.

## Secuencia reproducible

1. En A abrí el panel de StudioTest: x1 debe estar seleccionado. Verificá x5/x10, hover en PC y selección en móvil. Comprar sigue comprando una unidad aunque selecciones x10.
2. Abrí x1 con A. Debe conservar cámara, shutters, rebote, shake, premio 3D y retorno. No RewardOverlay ni contador de cinco segundos. Las cajas idle deben conservar su orientación.
3. Abrí x5 con A. Verificá resta exacta de cinco cajas, una sola caja cinematográfica y cinco premios, escalonados, con nombre, variación y color. En landscape deben formar una fila. Deben corresponder al recibo/inventario, incluso si StudioTest adjudica duplicados permitidos.
4. Con A iniciá x10. Mientras su cámara esté activa, **B** debe poder entrar al mismo stand, consultar y abrir x10. A y B ven solo su propia presentación. El tercero ve el stand normal, sin cámara forzada, personajes ocultos ni premios ajenos.
5. En ambos x10 verificá diez premios, dos filas de cinco en landscape y adaptación en portrait. No deben cortarse ni duplicarse títulos. Anotá inventario antes/después: exactamente diez cajas menos y diez unidades adjudicadas. Coins no cambian al abrir.
6. Al terminar A, volvé a interactuar y abrí x1 inmediatamente, aunque B siga en su secuencia. No debe aparecer espera personal ni EN USO global; el rate limit de solicitudes sigue siendo una protección normal.
7. Repetí x10 en A o B con inventario suficiente. No debe haber premios, pantallas negras, prompt oculto, música suspendida ni cámara/personajes bloqueados de la apertura anterior.
8. Con inventario menor de cinco/diez, verificá botones deshabilitados, faltante mostrado y ABRIR sin ejecutar. No debe convertir x10 en un lote parcial. Si después de las pruebas A conserva tres cajas, x5 debe indicar que faltan dos y x10 que faltan siete.
9. Verificá VER ÚLTIMO PREMIO/recibo: un lote muestra cantidad y estado. Si aparece una operación sin confirmación, **REINTENTAR xN** debe conservar el mismo lote; no crear otra operación ni comprar cajas como sustituto.
10. Probá interrupción/cancelación y desconexión mediante mecanismos existentes. Cancelar después de adjudicar conserva los premios; solo limpia la escena. La cámara, controles, personajes y prompt deben volver. Una limpieza tardía no debe cerrar la apertura siguiente ni la de B.
11. Revisá resolución PC y móvil, legibilidad de textos, VFX y sonido. Los Source/assets de variaciones y SoundIds existentes se conservaron. StudioTest solo sirve para sus resultados autorizados; no inventes RewardIds ni habilites aprobaciones para probar rarezas.
12. Spin conserva x1. Probalo solo mediante un cambio de modo explícitamente autorizado en una sesión separada; si no está disponible, dejalo NOT RUN. x5/x10 deben estar deshabilitados en Spin.

No fabriques errores de stock o persistencia modificando scripts de producción para la prueba. Esos escenarios ya tienen inyección aislada; pruebas con proveedor real requieren otro encargo. No simules aprobaciones comerciales.

Si algo falla, enviá Output con hora, cliente A/B/espectador, caja, cantidad, inventario previo/posterior y fase. Para problemas visuales, captura o video de ambos clientes y resolución. Para un reintento, incluí OperationId/BatchId si aparece en los diagnósticos, sin perfiles completos ni secretos.

Estado inicial: automatización aislada PASS; aceptación visual/multicliente **PENDING**. El agente no ejecutó Play.
