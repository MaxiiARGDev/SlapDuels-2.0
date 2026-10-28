# Slap Crates V2.5 — Implementado; validación visual pendiente

V2.4 fue la base preservada. Esta entrega añade presentación local; no aprueba funcionalmente V2.5 sin las pruebas del desarrollador. No inicié Play, Run, servidores ni partidas. Cuando Studio pasó a Play, suspendí el acceso hasta su retorno a Edit.

## Implementación

- x1 StandCinematic: cinco modelos reales reciclados, obtenidos exclusivamente de los IDs elegibles enviados por el servidor. No hay clones por frame ni otro sorteo. El objeto ganador es el modelo correspondiente al RewardId adjudicado. Los recibos antiguos sin elegibilidad conservan revelación directa.
- Desplazamiento horizontal determinista: velocidad constante seguida de caída cúbica de velocidad; posición y velocidad continuas y velocidad final cero. El ganador queda centrado, crece a su escala final, flota y gira; Billboard y VFX aparecen al detenerse.
- Caja: Highlight local sobre el clon, paleta del catálogo elegible durante Appear/Rise/Growth, transición al color real durante el primer 65 % de Shake y bloqueo hasta Flash. En batch se utiliza el premio de menor porcentaje efectivo como énfasis final.
- Premios: Highlight independiente, color tomado del catálogo y pulso limitado. x5/x10 conservan la galería; nunca ejecutan cinco/diez spins individuales.
- VFX modulares: partículas reutilizadas, halo nativo, rayos y luz limitada. Los efectos no aplican daño ni alteran los originales. Solo el premio de menor porcentaje fiable genera reacción global de cámara; los demás mantienen sus efectos locales. Empates: primer resultado.
- CameraLease, ocultamiento local, cancelación, restauración y limpieza existentes se mantienen. Modelos del pool, sonido Tick, Highlights y efectos quedan bajo objetos que la limpieza del run destruye, incluso si algunos están sin Parent.
- Spin clásico: controlador y reglas intactos. Su timeline no recibe la extensión exclusiva de StandCinematic.

## Configuración y duración

`src/shared/SlapCrates/OpeningConfig.luau`, tabla `RewardSpin`:

| Parámetro | Valor |
|---|---:|
| SpinDuration | 3,6 s |
| InitialSpeed | 16 posiciones/s |
| DecelerationDuration | 2,6 s |
| VisiblePreviewCount | 5; límite de ejecución 3–7, impar |
| ItemSpacing | 2,5 studs |
| WinningItemScale | 1,1 |
| FinalPauseDuration | 2,4 s |
| MaxPreviewExtent | 1,8 studs |

En formato vertical se muestran tres posiciones. La cámara calcula distancia según FOV/aspecto y se acerca suavemente al terminar. La reacción excepcional máxima es 0,1 studs / 0,35°, disminuida en móvil y combinada con los límites de cámara existentes.

Reward x1 reserva 6 s: spin 3,6 + pausa 2,4. Timeline total x1: **13,5 s**. x5: **11,5 s**; x10: **12,5 s**. MaxSequenceDuration continúa en 25 s. Prueba con el ledger real aislado: el antiguo deadline de 10,5 s no interrumpe la secuencia; la lease termina a los 13,5 s.

## Probabilidad y autoridad

Antes no llegaba al cliente la probabilidad efectiva por RewardId. `RewardVisualMetadata.Read` copia el porcentaje y los IDs con Probability > 0 del mismo conjunto `rows` usado por `Odds.Roll`, inmediatamente después del sorteo existente y antes del consumo. No hace llamadas RNG. En batch se registra el porcentaje de cada sorteo, cuya elegibilidad puede cambiar por posesión/reservas. No se utiliza un Quote posterior.

Metadatos añadidos: `EffectivePercent` por recompensa y `PreviewRewardIds` en el recibo/presentación. No se cambian Odds, pesos, precios, RNG, consumo, reservas, stock, inventario adjudicado ni compras. Los campos visuales acompañan el recibo autoritativo; cancelar/repetir la presentación no concede premios.

Umbrales editables en `src/client/CrateOpening/RewardRevealConfig.luau`:

| Porcentaje efectivo | Perfil |
|---|---|
| 5 < p ≤ 100 | Normal |
| 1 ≤ p ≤ 5 | Destacado |
| 0,1 ≤ p < 1 | Raro |
| 0,01 ≤ p < 0,1 | Ultra raro |
| 0 < p < 0,01 | Jackpot |

Sin porcentaje finito válido en (0,100], se usa el VisualProfile existente de la variación, sin inventar porcentaje. Las categorías son visuales, no comerciales.

Presupuesto nuevo: máximo 64 partículas PC / 24 móvil, distribuido por cantidad; móvil además multiplica el burst por 0,4. Máximo dos grupos halo/rayos por apertura PC / uno móvil, reservando uno para el premio principal. Beams/luz finalizan según perfil, máximo 1,3 s. Se mantiene el presupuesto separado de partículas originales de la galería: 40 PC / 12 móvil; el emisor nuevo no se vuelve a emitir desde ese camino. Los efectos originales de la caja siguen sus límites previos.

## Archivos y recursos

Seis módulos nuevos:

- `src/server/Services/Crates/RewardVisualMetadata.luau`
- `src/client/CrateOpening/RewardRevealConfig.luau`
- `src/client/CrateOpening/RewardRevealProfile.luau`
- `src/client/CrateOpening/RewardSpinMotion.luau`
- `src/client/CrateOpening/RewardSpin3D.luau`
- `src/client/CrateOpening/RewardVFX.luau`

Siete fuentes anteriores modificadas:

- `src/client/Controllers/CrateStandCinematicController.luau`
- `src/client/CrateOpening/RewardGallery.luau`
- `src/server/Services/Crates/CrateEngine.luau`
- `src/server/Services/Crates/CrateBatchEngine.luau`
- `src/server/Services/Crates/StandOpeningService.luau`
- `src/shared/SlapCrates/OpeningConfig.luau`
- `src/shared/SlapCrates/OpeningTimeline.luau`

También: mapa `default.project.json`, mapa SAFE regenerado, recursos `src/assets/CrateRevealV25/`, pruebas nuevas `tests/CrateRevealV25.spec.luau`, fixtures de regresión y herramientas/resultados en `tests/`. El validador compara hashes contra el inicio de esta tarea: otros **170 archivos previos de src intactos**. No se confunden los muchos cambios locales anteriores con cambios de V2.5.

Creado físicamente en Edit: **ReplicatedStorage.UIAssets.CrateRevealV25**, 44 descendientes:

- `ChestHighlight`, `RewardHighlight`: templates desactivados, Occluded.
- `RewardEffects.Anchor`: Part invisible, Anchored, sin colisión/touch/query.
- En Anchor: `RewardGlowParticles`, `RareSparkles`, `RewardStreaks`, `JackpotBurst`, todos Rate=0 y desactivados; texturas existentes.
- 12 segmentos de halo y cuatro rayos con attachments; PointLight desactivado.
- `RewardEffects.Anchor.JackpotReveal` y `SpinTick`: SoundId vacío, pendientes de elección humana. No se inventaron IDs. Los sonidos ya existentes se conservan.

El snapshot nativo y manifiesto SHA-256 están en `src/assets/CrateRevealV25/`. SAFE sigue mapeando exclusivamente scripts y conserva instancias desconocidas; no sincroniza ni elimina arte físico.

Durante la tarea se detectaron ajustes ajenos a esta implementación en ShopHUD: nueve descendientes adicionales y cambios de estilo. No se sobrescribieron. Se capturó el estado actual de 200 descendientes en `src/assets/CrateRevealV25/ShopHUD.rbxm` y el build ahora usa ese snapshot. Comparación detallada en `tests/assets/backups/CrateRevealV25/ShopHUD.delta.json`. No eliminé UIEffects ni los estilos agregados.

Verificación final por serialización nativa idéntica al snapshot: MainCrateStand 154; CrateOpeningHUD 26; CrateBatchRewardSlot 18; ShopHUD actual 200; recurso nuevo 44. Los tres primeros son idénticos al respaldo inicial; ShopHUD coincide con la captura actual preservada. No modifiqué VisualDecor, cámaras físicas ni PresentationTemplate. No guardé/sobrescribí el lugar ni publiqué.

Respaldo previo de fuentes, estado Git y cuatro recursos físicos: `tests/assets/backups/CrateRevealV25/`. Respaldos V2.1 y posteriores preservados.

## Evidencia y pruebas

- **141 scripts Luau compilados**, más specs; PASS.
- **6.869 aserciones aisladas**: V2.5 2.956; batch/motor/servicio 1.375; galería legacy 88; cinemática/ciclo de vida 1.931; economía 30; combate 150; habilidades 164; registry 89; Shop 86. La cifra suma suites de regresión con fixtures compartidos, no casos funcionales independientes.
- Rojo normal + SAFE: PASS. Verificados jerarquía, conteos y ausencia de nombres duplicados en recursos.
- `git diff --check`: PASS.
- 13 ModuleScripts sincronizados con guardas de fuente/editor y coincidencia SHA-256 final. No se reemplazaron borradores divergentes.
- En Edit se ejecutó solamente `PersistenceEnvironment.Resolve()`: **Environment=Studio, ProviderName=InMemory, WritesToCloud=false**. No se inicializaron perfiles ni se accedió a DataStoreService. Eso no sustituye comprobar los diagnósticos del servidor cuando el desarrollador pruebe.
- Evidencias: `tests/CrateRevealV25.checks.json`, `tests/CrateRevealV25.studio-edit.json`, `tests/CrateRevealV25.*-results.txt` y logs/builds del mismo prefijo.

En la matriz, **PASS aislado** verifica código real con fixtures fuera de Roblox; **PASS Edit** es inspección/serialización real, no jugabilidad. Toda aceptación visual/multicliente sigue NOT RUN por este agente.

| # | Comprobación solicitada | Resultado y alcance |
|---:|---|---|
| 1 | Spin solamente x1 cinematográfico | PASS aislado: contrato y timeline; inspección de integración |
| 2 | Ganador final autoritativo | PASS aislado: modelo real final centrado |
| 3 | Previews elegibles | PASS aislado: excluye IDs imposibles/duplicados |
| 4 | Desaceleración | PASS aislado: monotónica, continuidad y final exacto |
| 5 | Highlight de caja | PASS aislado: Adornee; template PASS Edit |
| 6 | Ciclo cromático | PASS aislado: interpolación cambia color |
| 7 | Color final real | PASS aislado: Shake y Flash |
| 8 | Highlight del ganador | PASS aislado: instancia independiente y habilitación |
| 9 | Perfil por probabilidad efectiva | PASS aislado: recibos reales del motor con fixtures |
| 10 | Fronteras | PASS aislado: 5; 1; 0,1; 0,01 y valores vecinos |
| 11 | Fallback | PASS aislado: VisualProfile real, sin porcentaje inventado |
| 12 | Jackpot VFX | PASS aislado; templates PASS Edit; apariencia NOT RUN |
| 13 | x5 cinco Highlights | PASS aislado: Gallery + RewardVFX reales |
| 14 | x10 diez Highlights | PASS aislado: Gallery + RewardVFX reales |
| 15 | Colores independientes | PASS aislado por resultado |
| 16 | Varios especiales | PASS aislado: selección primaria y presupuestos |
| 17 | No duplicar efectos | PASS aislado: Reveal idempotente y frames repetidos |
| 18 | CameraLease | PASS aislado: regresión de propiedad/restauración |
| 19 | Cancelación | PASS aislado: cierre local y contrato de lease |
| 20 | Restauración | PASS aislado: regresión cámara/visibilidad; real NOT RUN |
| 21 | Consecutivas | PASS aislado: fixtures nuevos y reapertura; real NOT RUN |
| 22 | Simultáneas privadas | PASS aislado: servicio dos compradores; real NOT RUN |
| 23 | Rendimiento x10 | PASS aislado: presupuestos y objetos acotados; FPS real NOT RUN |
| 24 | Spin clásico | Fuentes intactas por hash; timeline aislado PASS; visual NOT RUN |
| 25 | Probabilidades | Resolver intacto por hash; regresión PASS; metadata no sortea |
| 26 | Inventario | PASS aislado: adjudicación, consumo, replay y rollback |
| 27 | Stock | PASS aislado: reservas, límites, fallo y recuperación |
| 28 | Economía | PASS aislado; precios/config fuera de alcance intactos |
| 29 | Limpieza | PASS aislado: objetos registrados/destruidos y ciclo de vida; real NOT RUN |
| 30 | Recursos permanentes | PASS Edit: snapshots finales preservados y comparados |

## Prueba manual del desarrollador

1. Guardá tu lugar con tu procedimiento habitual. Esta entrega dejó los recursos en Edit; no publica. Usá la conexión **Scripts Only SAFE**; no apliques un mapa anterior de recursos sobre tu diseño actual.
2. Iniciá vos la prueba en Studio. En Command Bar **Server**, comprobá antes de comprar:

```lua
assert(game:GetService("RunService"):IsStudio())
local data = require(game.ServerScriptService.Services.PlayerDataService)
local d = data:GetPersistenceDiagnostics()
assert(d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false, "ABORTAR: persistencia no aislada")
print(d.Environment, d.ProviderName, d.WritesToCloud)
```

3. Si necesitás saldo, únicamente después de esa comprobación, Server Command Bar, cambiá `Player1` por el nombre real:

```lua
local p = assert(game.Players:FindFirstChild("Player1"), "Jugador no encontrado")
local data = require(game.ServerScriptService.Services.PlayerDataService)
local d = data:GetPersistenceDiagnostics()
assert(game:GetService("RunService"):IsStudio() and d.Environment == "Studio" and d.ProviderName == "InMemory" and d.WritesToCloud == false)
require(game.ServerScriptService.Services.PlayerService):AddCoins(p, 40, "StudioCrateV25Manual")
```

4. Comprá cajas **PRUEBA LOCAL — Caja / StudioTest** por el Shop existente. Hacé x1: observar Highlight cambiante, estabilización antes del Flash, carrusel rápido → lento → ganador, Billboard solo al detenerse, pausa final y restauración. Compará con la variación recibida en inventario. Repetí.
5. Hacé x5 y x10: cinco/diez modelos, Billboards y Highlights independientes, sin diez spins; encuadre completo en vertical y horizontal. Inventario consume exactamente 5/10 cajas y acredita exactamente 5/10 unidades.
6. Dos clientes: iniciar aperturas simultáneas en el mismo stand; cada uno ve solamente su presentación y recupera su cámara/visibilidad/prompt. Repetir inmediatamente tras terminar.
7. Cancelación/interrupción: probar con respawn o transición normal a partida, sin forzar premios/remotes. La presentación debe limpiarse y la recompensa ya entregada permanecer. Después abrir otra vez; comprobar que no quedan `CratePresentation_*` locales, Highlights/Beams nuevos activos ni cámara Scriptable al terminar.
8. Capturar Output Server+Client, video de x1/x10, resolución del viewport y dispositivo. Registrar por separado lo observado de lo pendiente. Si falla: indicar caja, cantidad, RewardId/variación, momento de cancelación y error completo.

**Límite de la caja local actual:** StudioTest solo da Basic/Common, 75 % / 25 %, ambos perfil Normal. No es una vía para validar manualmente Jackpot real. Los perfiles excepcionales y sus fronteras pasaron pruebas aisladas; su integración visual con adjudicaciones excepcionales queda **BLOCKED por catálogo comercial no aprobado**, hasta contar con una fixture de prueba explícitamente autorizada. No habilité cajas comerciales ni cambié sus Odds para fabricar un Jackpot.

Audio pendiente: elegir IDs permitidos para `ReplicatedStorage.UIAssets.CrateRevealV25.SpinTick` y `ReplicatedStorage.UIAssets.CrateRevealV25.RewardEffects.Anchor.JackpotReveal`. Mientras estén vacíos no reproducen audio nuevo; el resto del audio existente permanece.

Recomendación: lista la implementación para validar x1/x5/x10 manualmente. No declarar aprobación funcional, rendimiento móvil ni multicliente hasta esa validación. Detener nuevas implementaciones hasta recibir el resultado del desarrollador.
