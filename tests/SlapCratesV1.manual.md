# Validación manual — Slap Crates V1

Documento histórico V1: desde V1.2 la fixture ya está habilitada en Edit. Para la configuración y los pasos actuales usar **SlapCratesV12.manual.md**.

El agente implementó y verificó fuentes/objetos en Edit. NO ejecutó Play, Run, Start Server ni controló personajes. Las siguientes acciones las realiza el desarrollador.

## Preview sin Play

En Explorer, StarterGui.ShopHUD contiene:

- MainFrame.Tabs.CratesTab: pestaña CAJAS.
- CratePanel: título, cajas cerradas, estado, lista de probabilidades, consultar/comprar/abrir, último premio y cierre.
- CrateSpinPanel: Window.RollingStrip.RewardTemplate, Indicator, Result, Close, Tick y Reveal.
- CrateActionsTemplate: botones por tarjeta, plantilla oculta.

Para revisar el diseño en Edit, seleccionar CratePanel o CrateSpinPanel y cambiar temporalmente Visible=true en Properties. Al terminar dejar Visible=false. Las plantillas permanecen ocultas. No hace falta crear objetos ni correr un instalador. Revisar desktop/móvil y resolución pequeña: la nueva pestaña usa el layout horizontal existente, que ya tenía ancho fijo; si no entra, registrar captura antes de rediseñar esa barra.

En ReplicatedStorage inspeccionar CrateEffects (12 modelos con Body/Lid/Burst/Reveal), SlapVariationEffects (12 perfiles con Tint/Sparkles/Reveal), CrateRewardPreviews.Classic.Hand.Mesh (mesh existente de Classic, representación sin lógica ni colisiones).

## Habilitar SOLO fixture local

Las 12 cajas comerciales no tienen precios/pesos aprobados y deben quedar bloqueadas. Existe una fixture StudioTest con precio 1 Coin y pesos Basic=3, Common=1 exclusivamente ilustrativos; no configura producción. Por defecto NO está habilitada en el place.

Si aprobás probar esa fixture, en Command Bar **Edit**, antes de iniciar tu sesión:

```lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Solo Edit")
game:GetService("ServerStorage"):SetAttribute("CrateStudioTestsEnabled", true)
```

Ahora iniciá vos tu prueba. En Command Bar del **servidor** verificá antes de operar:

```lua
assert(game:GetService("RunService"):IsStudio())
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false)
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

Si falla alguna condición, detener la prueba. No modificar el Universe ID ni activar API Services/cloud.

Si necesitás saldo de prueba, DESPUÉS de esa comprobación, solo en el servidor local:

```lua
local player = assert(game:GetService("Players"):GetPlayers()[1])
require(game.ServerScriptService.Services.PlayerService):AddCoins(player, 5, "CratesInMemoryManualTest")
```

PolicyService real también se consulta en Studio. Si la API no puede resolver los jugadores sintéticos, la UI debe bloquear con PaidRandomItemsRestricted. No hay bypass local escondido: en ese caso la integración de apertura real queda BLOCKED por elegibilidad, aunque los tests aislados con política simulada pasen.

## Casos de aceptación

1. Shop > CAJAS muestra 12 definiciones pendientes y StudioTest solo si está habilitada. Ninguna caja pendiente ofrece compra real ni muestra precio 0 como gratuito.
2. En StudioTest, VER PROBABILIDADES muestra Classic:Basic 75 % y Classic:Common 25 %, scope StudioServerInMemory e Ilimitado. Son valores de fixture; otros Slaps o políticas de duplicados cambian esos porcentajes.
3. COMPRAR CAJA debita exactamente 1 Coin y aumenta cajas cerradas en 1; todavía no debe entregar un Slap.
4. ABRIR CAJA consume una caja, conserva Coins y registra una unidad. La ruleta termina centrada en el premio del servidor y habilita CERRAR al finalizar.
5. Dos observadores cercanos en lobby ven caja y preview 3D, sin HUD privado. Un jugador distante/en combate/Results no recibe esa escena como propia.
6. Cerrar tienda o desconectar durante spin no elimina premio ni cobra de nuevo. Reconectar al MISMO servidor de prueba y consultar VER ÚLTIMO PREMIO. Reiniciar todo el entorno InMemory borra legítimamente la prueba, no sirve para comprobar durabilidad productiva.
7. Clics repetidos/reintentos no duplican consumo ni premio. Desactivar red durante respuesta debe permitir reintentar con la operación pendiente conservada.
8. Shop > Slaps muestra propiedad por combinación exacta. Classic:Common no permite equipar Galaxy. Slaps no poseídos solo muestran SOLO EN CAJAS, jamás compra individual.
9. Equipar variación poseída en lobby y entrar al combate: misma Tool base/configuración, variación visible, sin herramienta/slot en lobby. Verificar ventana 0,10 / recuperación 0,15 acierto y 0,45 fallo, inmunidad de víctima 3 s y eliminación por tres golpes válidos.
10. Probar gol +50 Coins, Kill +50, Death Effects, habilidades, KillPart, ronda de 3 min, Muerte Súbita, EndCinematic, retorno y segunda partida. Estas regresiones reales siguen pendientes; no se sustituyen por inspección de código.
11. Modelos temporales desaparecen unos 2 s tras revelación, sin colisiones, movimiento del jugador ni restos en Workspace.
12. Audio vacío es pendiente de diseño. Tras asignar SoundIds propios aprobados a Sounds físicos, comprobar Tick/Reveal y volumen. Ningún SoundId comercial fue inventado.

Anuncios: todas las variaciones tienen AnnounceInChat=false por defecto. Si se aprueba probar uno, habilitar la definición correspondiente y sincronizar; comprobar mensaje único en TextChatService.RBXGeneral con OpeningId real. Si el chat usa canales personalizados, requiere elegir ese canal antes de aprobar la integración visual; no se crea un chat paralelo.

Al finalizar, detener vos la prueba y volver a Edit:

```lua
assert(not game:GetService("RunService"):IsRunning())
game:GetService("ServerStorage"):SetAttribute("CrateStudioTestsEnabled", false)
```

No aprobar venta productiva con estos resultados: falta backend durable y validación entre servidores. Para reportar fallos incluir Output del servidor/comprador/observadores, CrateId, OperationId/OpeningId, saldo, cajas antes/después y captura de probabilidades/resultado.
