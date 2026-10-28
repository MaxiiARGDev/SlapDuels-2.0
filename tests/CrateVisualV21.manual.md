# Validación manual V2.1

Guardá normalmente el place. No hace falta instalar modelos: se preservaron los existentes. Usá Rojo SAFE para scripts; leé CrateVisualV21.sync-recovery.md antes de sincronizar recursos completos.

Vos iniciás/detenés Play y controlás jugadores. Antes de operar en cada sesión, Command Bar **servidor local**:

```lua
assert(game:GetService("RunService"):IsStudio(), "Abortar: no es Studio")
local d = require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "Abortar: persistencia no aislada")
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

Si falla, no continuar. No activar API Services/cloud ni cambiar Universe ID. Si necesitás saldo para StudioTest, solo después de esos asserts:

```lua
local ps = require(game.ServerScriptService.Services.PlayerService)
for _, player in ipairs(game.Players:GetPlayers()) do
 ps:AddCoins(player, 5, "CrateVisualV21InMemoryManualTest")
end
```

## Stand exclusivo, configuración actual

1. Usar dos clientes y, si es posible, un tercero espectador. En lobby observar Shards, Ring, Glow y luces: animación discreta, sin partes adicionales por frame.
2. Acercarse al stand: CAJAS y subtítulo correctos; prompt abre la Shop existente. Verificar panel restilizado, acciones, OddsList y navegación de otras categorías sin cambios al CardTemplate compartido.
3. Consultar/comprar StudioTest a 1 Coin; las comerciales siguen bloqueadas. Si PolicyService no verifica el jugador sintético, marcar BLOCKED sin bypass.
4. Abrir StudioTest. Observar las nueve fases: cierre suave, cámara al stand, caja pequeña, elevación/rotación continua, crecimiento, tensión progresiva, FlashSparks y desaparición del cofre, premio y salida. Duración actual ~10,5 s.
5. En Reward: overlay entra, muestra Slap y variación reales y color correspondiente; mantiene legible el premio 3D/Billboard; sale en Outro. Comparar con VER ÚLTIMO PREMIO e inventario/equipamiento. No debe repetirse ni quedar visible.
6. B observa la escena autorizada sin overlay ni cámara del comprador. Intentar abrir durante A: bloqueo de stand sin consumo. Al terminar, el stand vuelve a CAJAS y B puede usarlo; solo A ve su cuenta regresiva personal de 5 s en ese stand.
7. Repetir dos aperturas. Verificar que no queden modelos, tweens, overlay, flash, pantalla negra, controles bloqueados ni conexiones evidenciadas por efectos duplicados.
8. Cancelación/contexto: probar muerte/Character nuevo, desconexión o entrada a sesión durante una presentación ya adjudicada. El premio permanece; cámara/sujeto/FOV adecuados y controles vuelven, sin restauración tardía sobre EndCinematic. Enviar Output si se detecta Restore failure.

## Privado y Spin

Detener tu sesión y cambiar **ExclusiveOpening=false** en OpeningConfig, manteniendo fuente local/Studio iguales. Sesión nueva + comprobar persistencia. A y B abren simultáneamente: overlays y cámaras independientes, sin EN USO global, tercero sin escenas privadas, cancelación de A no afecta B.

Para Spin, volver a Edit, cambiar **Mode="Spin"**, iniciar sesión nueva. StudioTest usa ruleta original y no muestra RewardOverlay ni cámara del stand. Probar inventario, reintentos, equipamiento y regresar a StandCinematic en otra sesión. No habilitar OddsApproved/Enabled comerciales para fabricar pruebas visuales.

Los 12 perfiles visuales están cubiertos por tests aislados y usan el catálogo real. StudioTest solo entrega Basic/Common; ver todas las rarezas requiere una fixture visual aprobada o premios legítimamente adjudicados por un flujo permitido. No enviar RewardIds ficticios por Remote ni adjudicar inventario para declarar una prueba funcional aprobada. Si no hay vía autorizada para ver una rareza, marcarla NOT RUN/BLOCKED.

## Diseño, móvil y audio

En Edit podés ajustar MainCrateStand completo y sus anchors. Probar tras moverlo/rotarlo en una sesión nueva; el encuadre debe seguir siendo relativo. Revisar PC/móvil: posición del overlay, premio visible, botones, scrolling, tipografías, brillo moderado y cuenta regresiva.

Los Sounds físicos siguen vacíos. Asigná únicamente recursos aprobados a Start/Appear/Rise/Growth/Shake/Flash/Reward/Special/Outro. Audio no está aprobado hasta escucharlo. Después de arte nuevo, exportá antes de usar el proyecto Rojo completo.

Devolvé PASS/FAIL/BLOCKED por caso con modo, exclusividad, resolución, StandId, OpeningId/RewardId si aparecen, Coins/cajas antes/después, Output servidor/clientes y captura/video. No enviar credenciales. Indicar qué rarezas se observaron realmente. No considerar aprobado el render/animación por las pruebas automatizadas.
